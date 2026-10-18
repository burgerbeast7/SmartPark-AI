import 'package:flutter_test/flutter_test.dart';
import 'package:smartpark_ai/services/plate_service.dart';

void main() {
  group('PlateService - Normalization (Section 17.2)', () {
    test('hp 01 ab 1234 -> HP01AB1234', () {
      expect(PlateService.normalize('hp 01 ab 1234'), 'HP01AB1234');
    });

    test('HP-01-AB-1234 -> HP01AB1234', () {
      expect(PlateService.normalize('HP-01-AB-1234'), 'HP01AB1234');
    });

    test('MH12.DE.1432 -> MH12DE1432', () {
      expect(PlateService.normalize('MH12.DE.1432'), 'MH12DE1432');
    });

    test('empty -> empty', () {
      expect(PlateService.normalize(''), '');
    });
  });

  group('PlateService - Validation (Section 17.2)', () {
    test('HP01AB1234 matches standard pattern with no warning', () {
      final res = PlateService.validate('HP01AB1234');
      expect(res.isValidLength, isTrue);
      expect(res.matchesPattern, isTrue);
      expect(res.warningMessage, isNull);
    });

    test('DL8CAB1234 matches standard pattern with no warning', () {
      final res = PlateService.validate('DL8CAB1234');
      expect(res.isValidLength, isTrue);
      expect(res.matchesPattern, isTrue);
      expect(res.warningMessage, isNull);
    });

    test('22BH1234AA matches Bharat series pattern with no warning', () {
      final res = PlateService.validate('22BH1234AA');
      expect(res.isValidLength, isTrue);
      expect(res.matchesPattern, isTrue);
      expect(res.warningMessage, isNull);
    });

    test('ABC fails hard rule (length < 4)', () {
      final res = PlateService.validate('ABC');
      expect(res.isValidLength, isFalse);
      expect(res.matchesPattern, isFalse);
      expect(res.warningMessage, isNotNull);
    });

    test('KA01 passes hard rule (length 4) with soft warning', () {
      final res = PlateService.validate('KA01');
      expect(res.isValidLength, isTrue);
      expect(res.matchesPattern, isFalse);
      expect(res.warningMessage, 'Unusual format, please verify');
    });
  });

  group('PlateService - OCR Candidate Selection (Section 17.3)', () {
    test('Two-line plate joined and recognized', () {
      final rawLines = ['DL 01', 'AB 1234'];
      final res = PlateService.selectOcrCandidates(rawLines);
      expect(res.suggestion, 'DL01AB1234');
      expect(res.message, isNull);
    });

    test('Bharat series recognized from candidate lines', () {
      final rawLines = ['PARKING RECEIPT', '22 BH 1234 AA', 'VISITOR'];
      final res = PlateService.selectOcrCandidates(rawLines);
      expect(res.suggestion, '22BH1234AA');
      expect(res.message, isNull);
    });

    test('Fallback to longest alphanumeric candidate when no pattern matches', () {
      final rawLines = ['ENTRY GATE', 'TEMP9999X', 'NOTICE'];
      final res = PlateService.selectOcrCandidates(rawLines);
      expect(res.suggestion, 'TEMP9999X');
      expect(res.message, isNull);
    });

    test('No usable text returns friendly failure message', () {
      final rawLines = ['***', '---', '???'];
      final res = PlateService.selectOcrCandidates(rawLines);
      expect(res.suggestion, '');
      expect(res.message, 'No plate text found. Retake or type the number.');
    });

    test('Empty list returns friendly failure message', () {
      final res = PlateService.selectOcrCandidates([]);
      expect(res.suggestion, '');
      expect(res.message, 'No plate text found. Retake or type the number.');
    });
  });
}
