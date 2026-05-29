import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';
import 'package:bestfin/features/pdf_import/data/parsers/pdf_bank_parser.dart';
import 'package:bestfin/features/pdf_import/data/parsers/nubank_fatura_parser.dart';
import 'package:bestfin/features/pdf_import/data/parsers/nubank_comprovante_parser.dart';
import 'package:bestfin/features/pdf_import/data/parsers/bb_comprovante_parser.dart';
import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';

class ImportPdfUseCase {
  static final List<PdfBankParser> _parsers = [
    NubankFaturaParser(),
    NubankComprovanteParser(),
    BBComprovanteParser(),
  ];

  Future<List<PdfParsedTransaction>> call(Uint8List pdfBytes) async {
    final doc = await PdfDocument.openData(pdfBytes);
    final buffer = StringBuffer();

    for (int i = 0; i < doc.pages.length; i++) {
      final page = doc.pages[i];
      final text = await page.loadText();
      buffer.writeln(text.fullText);
    }

    await doc.dispose();

    final fullText = buffer.toString();

    for (final parser in _parsers) {
      if (parser.canHandle(fullText)) {
        final result = parser.parse(fullText);
        if (result.isNotEmpty) return result;
      }
    }

    throw const FormatException(
      'Formato de PDF não reconhecido. Suportados: Nubank Fatura, Nubank Comprovante/Pix, Banco do Brasil Comprovante.',
    );
  }
}
