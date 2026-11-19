import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfExtractionResult {
  final String fullText;
  final int pageCount;
  final bool success;
  final String? errorMessage;

  PdfExtractionResult({
    required this.fullText,
    required this.pageCount,
    required this.success,
    this.errorMessage,
  });
}

class PdfExtractorService {
  static Future<PdfExtractionResult> extractTextFromBytes(Uint8List bytes) async {
    try {
      if (bytes.isEmpty) {
        return PdfExtractionResult(
          fullText: '',
          pageCount: 0,
          success: false,
          errorMessage: 'The selected PDF file is empty.',
        );
      }

      final PdfDocument document = PdfDocument(inputBytes: bytes);
      final int pageCount = document.pages.count;

      if (pageCount == 0) {
        document.dispose();
        return PdfExtractionResult(
          fullText: '',
          pageCount: 0,
          success: false,
          errorMessage: 'PDF contains no pages.',
        );
      }

      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String extractedText = extractor.extractText();
      document.dispose();

      if (extractedText.trim().isEmpty) {
        return PdfExtractionResult(
          fullText: '',
          pageCount: pageCount,
          success: false,
          errorMessage: 'No selectable text could be found in this PDF (it might be a scanned image).',
        );
      }

      return PdfExtractionResult(
        fullText: extractedText,
        pageCount: pageCount,
        success: true,
      );
    } catch (e) {
      debugPrint('PDF extraction error: $e');
      return PdfExtractionResult(
        fullText: '',
        pageCount: 0,
        success: false,
        errorMessage: 'Could not read PDF: $e',
      );
    }
  }
}
