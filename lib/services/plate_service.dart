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
  static OcrSelectionResult selectOcrCandidates(List<String> rawLines) {
    if (rawLines.isEmpty) {
      return const OcrSelectionResult(
        suggestion: '',
        alternativeChips: [],
        message: 'No plate text found. Retake or type the number.',
      );
    }

    final candidates = <String>[];
    final seen = <String>{};

    void addCandidate(String norm) {
      if (norm.length >= AppConstants.minPlateLength &&
          norm.length <= AppConstants.maxPlateLength &&
          !seen.contains(norm)) {
        seen.add(norm);
        candidates.add(norm);
      }
    }

    // 1. Each line normalized
    for (final line in rawLines) {
      final norm = normalize(line);
      addCandidate(norm);
    }

    // 2. All lines joined and normalized (covers two-line plates)
    final allJoined = normalize(rawLines.join(''));
    addCandidate(allJoined);

    if (candidates.isEmpty) {
      return const OcrSelectionResult(
        suggestion: '',
        alternativeChips: [],
        message: 'No plate text found. Retake or type the number.',
      );
    }

    // 3. Search each candidate with non-anchored standard and Bharat patterns
    String? bestSuggestion;
    for (final c in candidates) {
      final stdMatch = _nonAnchoredStandardRegex.firstMatch(c);
      if (stdMatch != null) {
        bestSuggestion = stdMatch.group(0)!;
        break;
      }
      final bhMatch = _nonAnchoredBharatRegex.firstMatch(c);
      if (bhMatch != null) {
        bestSuggestion = bhMatch.group(0)!;
        break;
      }
    }

    // 4. If no pattern hit, use the longest remaining candidate containing at least one letter and one digit
    if (bestSuggestion == null) {
      final alphanumericCandidates = candidates.where((c) {
        return _letterRegex.hasMatch(c) && _digitRegex.hasMatch(c);
      }).toList();

      if (alphanumericCandidates.isNotEmpty) {
        alphanumericCandidates.sort((a, b) => b.length.compareTo(a.length));
        bestSuggestion = alphanumericCandidates.first;
      }
    }

    // 5. If still nothing remains
    if (bestSuggestion == null) {
      return const OcrSelectionResult(
        suggestion: '',
        alternativeChips: [],
        message: 'No plate text found. Retake or type the number.',
      );
    }

    // List up to 4 other candidates as tappable chips
    final otherCandidates = candidates
        .where((c) => c != bestSuggestion)
        .take(4)
        .toList();

    return OcrSelectionResult(
      suggestion: bestSuggestion,
      alternativeChips: otherCandidates,
      message: null,
    );
  }
}
