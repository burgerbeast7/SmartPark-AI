import '../core/constants.dart';

class PlateValidationResult {
  final bool isValidLength;
  final bool matchesPattern;
  final String? warningMessage;

  const PlateValidationResult({
    required this.isValidLength,
    required this.matchesPattern,
    this.warningMessage,
  });
}

class OcrSelectionResult {
  final String suggestion;
  final List<String> alternativeChips;
  final String? message;

  const OcrSelectionResult({
    required this.suggestion,
    required this.alternativeChips,
    this.message,
  });
}

class PlateService {
  // Anchored Regex patterns for strict validation (Section 17.2)
  static final RegExp _standardPlateRegex =
      RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}$');
  static final RegExp _bharatSeriesRegex =
      RegExp(r'^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$');

  // Non-anchored Regex patterns for OCR candidate extraction (Section 17.3)
  static final RegExp _nonAnchoredStandardRegex =
      RegExp(r'[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}');
  static final RegExp _nonAnchoredBharatRegex =
      RegExp(r'[0-9]{2}BH[0-9]{4}[A-Z]{1,2}');

  static final RegExp _letterRegex = RegExp(r'[A-Z]');
  static final RegExp _digitRegex = RegExp(r'[0-9]');

  /// Normalizes plate string: uppercase, removing all characters except A-Z and 0-9.
  static String normalize(String raw) {
    if (raw.isEmpty) return '';
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Validates normalized plate according to Section 17.2.
  /// Hard rule (blocks saving): length 4 to 12.
  /// Soft warning (does not block): unusual format if it doesn't match standard or Bharat series.
  static PlateValidationResult validate(String normalizedPlate) {
    final length = normalizedPlate.length;
    final isValidLength =
        length >= AppConstants.minPlateLength && length <= AppConstants.maxPlateLength;

    if (!isValidLength) {
      return const PlateValidationResult(
        isValidLength: false,
        matchesPattern: false,
        warningMessage: 'Plate number must be 4 to 12 characters.',
      );
    }

    final matchesStandard = _standardPlateRegex.hasMatch(normalizedPlate);
    final matchesBharat = _bharatSeriesRegex.hasMatch(normalizedPlate);
    final matchesPattern = matchesStandard || matchesBharat;

    return PlateValidationResult(
      isValidLength: true,
      matchesPattern: matchesPattern,
      warningMessage: matchesPattern ? null : 'Unusual format, please verify',
    );
  }

  /// Selects the best OCR candidate from raw extracted text lines (Section 17.3).
  /// Resilient against extra text (e.g. "IND", brand names, frame text), multi-line plates,
  /// and common OCR letter/digit confusions.
  static OcrSelectionResult selectOcrCandidates(List<String> rawLines) {
    if (rawLines.isEmpty) {
      return const OcrSelectionResult(
        suggestion: '',
        alternativeChips: [],
        message: 'No plate text found. Retake or type the number.',
      );
    }

    final patternMatches = <String>[];
    final patternSeen = <String>{};

    void addPatternMatch(String? match) {
      if (match == null || match.isEmpty) return;
      if (match.length >= AppConstants.minPlateLength &&
          match.length <= AppConstants.maxPlateLength &&
          !patternSeen.contains(match)) {
        patternSeen.add(match);
        patternMatches.add(match);
      }
    }

    // 1. Build prioritized search groups:
    // Group A (Highest priority): Single lines, cleaned lines (no IND), space tokens, adjacent pairs (2-line plates)
    final highPrioritySegments = <String>[];
    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isNotEmpty) {
        highPrioritySegments.add(line);

        // Strip leading IND if attached or spaced (HSRP badge)
        final upper = line.toUpperCase();
        if (upper.startsWith('IND') && upper.length > 5) {
          highPrioritySegments.add(line.substring(3).trim());
        }

        // Space-separated tokens (e.g. "DL01AB1234" inside a noisy line)
        final tokens = line.split(RegExp(r'\s+'));
        if (tokens.length > 1) {
          for (final t in tokens) {
            final tt = t.trim();
            if (tt.length >= 4 && tt.length <= 12) {
              highPrioritySegments.add(tt);
            }
          }
        }
      }

      // Adjacent 2-line plate combination (e.g. line 1: "DL 01", line 2: "AB 1234")
      if (i + 1 < rawLines.length) {
        highPrioritySegments.add('${rawLines[i]} ${rawLines[i + 1]}');
        highPrioritySegments.add('${rawLines[i]}${rawLines[i + 1]}');
      }
    }

    // Group B (Broader fallback): 3-line combination and all lines joined
    final broaderSegments = <String>[];
    for (var i = 0; i + 2 < rawLines.length; i++) {
      broaderSegments.add('${rawLines[i]} ${rawLines[i + 1]} ${rawLines[i + 2]}');
    }
    broaderSegments.add(rawLines.join(' '));
    broaderSegments.add(rawLines.join(''));

    // Tier 1: Check for EXACT (anchored) plate matches in high-priority segments
    for (final seg in highPrioritySegments) {
      final norm = normalize(seg);
      if (norm.isEmpty) continue;
      if (_standardPlateRegex.hasMatch(norm) || _bharatSeriesRegex.hasMatch(norm)) {
        addPatternMatch(norm);
      }
    }

    // Tier 2: Search non-anchored Bharat & Standard regex in high-priority segments
    if (patternMatches.isEmpty) {
      for (final seg in highPrioritySegments) {
        final norm = normalize(seg);
        if (norm.isEmpty) continue;

        final bhMatch = _nonAnchoredBharatRegex.firstMatch(norm);
        if (bhMatch != null) {
          addPatternMatch(bhMatch.group(0)!);
        }

        final stdMatch = _nonAnchoredStandardRegex.firstMatch(norm);
        if (stdMatch != null) {
          addPatternMatch(stdMatch.group(0)!);
        }
      }
    }

    // Tier 3: Search non-anchored patterns across broader / all-joined segments
    if (patternMatches.isEmpty) {
      for (final seg in broaderSegments) {
        final norm = normalize(seg);
        if (norm.isEmpty) continue;

        final bhMatch = _nonAnchoredBharatRegex.firstMatch(norm);
        if (bhMatch != null) {
          addPatternMatch(bhMatch.group(0)!);
        }

        final stdMatch = _nonAnchoredStandardRegex.firstMatch(norm);
        if (stdMatch != null) {
          addPatternMatch(stdMatch.group(0)!);
        }
      }
    }

    // Tier 4: Attempt OCR character disambiguation on segments (correcting O/0, I/1, B/8, etc.)
    if (patternMatches.isEmpty) {
      for (final seg in [...highPrioritySegments, ...broaderSegments]) {
        final norm = normalize(seg);
        if (norm.length >= 7 && norm.length <= 11) {
          final disambiguated = _attemptOcrDisambiguation(norm);
          if (disambiguated != null) {
            addPatternMatch(disambiguated);
          }
        }
      }
    }

    // Tier 5: Collect general alphanumeric candidates (length 4..12) as fallback or chips
    final generalCandidates = <String>[];
    final generalSeen = <String>{};

    void addGeneralCandidate(String raw) {
      final norm = normalize(raw);
      if (norm.length >= AppConstants.minPlateLength &&
          norm.length <= AppConstants.maxPlateLength &&
          !generalSeen.contains(norm) &&
          !patternSeen.contains(norm)) {
        generalSeen.add(norm);
        generalCandidates.add(norm);
      }
    }

    for (final seg in [...highPrioritySegments, ...broaderSegments]) {
      addGeneralCandidate(seg);
    }

    // Filter general candidates for at least one letter and one digit
    final alphanumericCandidates = generalCandidates.where((c) {
      return _letterRegex.hasMatch(c) && _digitRegex.hasMatch(c);
    }).toList();
    alphanumericCandidates.sort((a, b) => b.length.compareTo(a.length));

    // Determine best suggestion
    String? bestSuggestion;
    if (patternMatches.isNotEmpty) {
      bestSuggestion = patternMatches.first;
    } else if (alphanumericCandidates.isNotEmpty) {
      bestSuggestion = alphanumericCandidates.first;
    }

    if (bestSuggestion == null) {
      return const OcrSelectionResult(
        suggestion: '',
        alternativeChips: [],
        message: 'No plate text found. Retake or type the number.',
      );
    }

    // Build alternative chips (up to 4)
    final alternativeChips = <String>[];
    for (final p in patternMatches) {
      if (p != bestSuggestion && !alternativeChips.contains(p)) {
        alternativeChips.add(p);
      }
      if (alternativeChips.length >= 4) break;
    }
    if (alternativeChips.length < 4) {
      for (final a in alphanumericCandidates) {
        if (a != bestSuggestion && !alternativeChips.contains(a)) {
          alternativeChips.add(a);
        }
        if (alternativeChips.length >= 4) break;
      }
    }

    return OcrSelectionResult(
      suggestion: bestSuggestion,
      alternativeChips: alternativeChips,
      message: null,
    );
  }

  /// Attempts common OCR substitutions (O/0, I/1, B/8, S/5, Z/2) to recover plates
  /// that failed due to single-character recognition confusions.
  static String? _attemptOcrDisambiguation(String candidate) {
    if (candidate.length < 7 || candidate.length > 11) return null;

    if (_standardPlateRegex.hasMatch(candidate) || _bharatSeriesRegex.hasMatch(candidate)) {
      return candidate;
    }

    // 1. Try correcting Bharat series: [2 digits]BH[4 digits][1-2 letters]
    if (candidate.contains('BH') || candidate.contains('8H')) {
      final bhCandidate = candidate.replaceAll('8H', 'BH');
      final chars = bhCandidate.split('');
      if (chars.length >= 9 && chars.length <= 10) {
        chars[0] = _toDigit(chars[0]);
        chars[1] = _toDigit(chars[1]);
        chars[2] = 'B';
        chars[3] = 'H';
        for (var i = 4; i < 8; i++) {
          chars[i] = _toDigit(chars[i]);
        }
        for (var i = 8; i < chars.length; i++) {
          chars[i] = _toLetter(chars[i]);
        }
        final corrected = chars.join('');
        if (_bharatSeriesRegex.hasMatch(corrected)) {
          return corrected;
        }
      }
    }

    // 2. Try correcting Standard plate: [2 letters][1-2 digits][0-3 letters][4 digits]
    final len = candidate.length;
    final chars = candidate.split('');
    chars[0] = _toLetter(chars[0]);
    chars[1] = _toLetter(chars[1]);
    for (var i = len - 4; i < len; i++) {
      chars[i] = _toDigit(chars[i]);
    }

    if (len == 10) {
      // e.g. DL01AB1234
      final v = List<String>.from(chars);
      v[2] = _toDigit(v[2]);
      v[3] = _toDigit(v[3]);
      v[4] = _toLetter(v[4]);
      v[5] = _toLetter(v[5]);
      final res = v.join('');
      if (_standardPlateRegex.hasMatch(res)) return res;
    } else if (len == 9) {
      // Case A: [2 letters][2 digits][1 letter][4 digits] e.g. DL01A1234
      final v1 = List<String>.from(chars);
      v1[2] = _toDigit(v1[2]);
      v1[3] = _toDigit(v1[3]);
      v1[4] = _toLetter(v1[4]);
      final r1 = v1.join('');
      if (_standardPlateRegex.hasMatch(r1)) return r1;

      // Case B: [2 letters][1 digit][2 letters][4 digits] e.g. DL1AB1234
      final v2 = List<String>.from(chars);
      v2[2] = _toDigit(v2[2]);
      v2[3] = _toLetter(v2[3]);
      v2[4] = _toLetter(v2[4]);
      final r2 = v2.join('');
      if (_standardPlateRegex.hasMatch(r2)) return r2;
    } else if (len == 8) {
      // Case A: [2 letters][1 digit][1 letter][4 digits] e.g. DL1A1234
      final v1 = List<String>.from(chars);
      v1[2] = _toDigit(v1[2]);
      v1[3] = _toLetter(v1[3]);
      final r1 = v1.join('');
      if (_standardPlateRegex.hasMatch(r1)) return r1;

      // Case B: [2 letters][2 digits][0 letters][4 digits] e.g. DL011234
      final v2 = List<String>.from(chars);
      v2[2] = _toDigit(v2[2]);
      v2[3] = _toDigit(v2[3]);
      final r2 = v2.join('');
      if (_standardPlateRegex.hasMatch(r2)) return r2;
    }

    return null;
  }

  static String _toDigit(String ch) {
    switch (ch) {
      case 'O':
      case 'o':
      case 'Q':
      case 'D':
        return '0';
      case 'I':
      case 'i':
      case 'L':
      case 'l':
        return '1';
      case 'Z':
      case 'z':
        return '2';
      case 'S':
      case 's':
        return '5';
      case 'B':
        return '8';
      default:
        return ch;
    }
  }

  static String _toLetter(String ch) {
    switch (ch) {
      case '0':
        return 'O';
      case '1':
        return 'I';
      case '2':
        return 'Z';
      case '5':
        return 'S';
      case '8':
        return 'B';
      default:
        return ch;
    }
  }
}
