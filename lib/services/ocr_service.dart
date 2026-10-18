import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/exceptions.dart';
import 'plate_service.dart';

class OcrService {
  /// Processes the image file at [imagePath] with ML Kit Text Recognition (Latin script).
  /// Always closes the recognizer in a finally block (Section 22).
  Future<OcrSelectionResult> recognizePlate(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      final rawLines = <String>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          rawLines.add(line.text);
        }
      }

      return PlateService.selectOcrCandidates(rawLines);
    } catch (e) {
      throw OcrException('OCR processing failed: ${e.toString()}');
    } finally {
      await textRecognizer.close();
    }
  }
}
