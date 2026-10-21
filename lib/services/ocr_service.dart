import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/exceptions.dart';
import 'plate_service.dart';

class OcrService {
  /// Processes the image file at [imagePath] with ML Kit Text Recognition (Latin script).
  /// Always closes the recognizer in a finally block (Section 22).
  Future<OcrSelectionResult> recognizePlate(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return const OcrSelectionResult(
        suggestion: '',
        alternativeChips: [],
        message: 'Captured image file could not be accessed. Please retake.',
      );
    }

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      final rawLines = <String>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final trimmed = line.text.trim();
          if (trimmed.isNotEmpty) {
            rawLines.add(trimmed);
          }
        }
      }

      // If line breakdown was empty but block text exists, fallback to text lines
      if (rawLines.isEmpty && recognizedText.text.trim().isNotEmpty) {
        rawLines.addAll(
          recognizedText.text
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }

      return PlateService.selectOcrCandidates(rawLines);
    } catch (e, stack) {
      debugPrint('OCR Recognition Error: $e\n$stack');
      throw OcrException('OCR processing failed: ${e.toString()}');
    } finally {
      await textRecognizer.close();
    }
  }
}
