import 'package:bestfin/features/pdf_import/data/parsers/pdf_bank_parser.dart';
import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';

class BBComprovanteParser extends PdfBankParser {
  @override
  bool canHandle(String fullText) {
    final upper = fullText.toUpperCase();
    return upper.contains('BANCO DO BRASIL') && upper.contains('COMPROVANTE');
  }

  @override
  List<PdfParsedTransaction> parse(String fullText) {
    // Try "VALOR R$ XX,XX" first, then generic R$ pattern
    final amountMatch =
        RegExp(r'VALOR\s*R\$\s*([\d.,]+)', caseSensitive: false)
            .firstMatch(fullText) ??
        RegExp(r'R\$\s*([\d.,]+)').firstMatch(fullText);

    final dateMatch = RegExp(r'(\d{2}/\d{2}/\d{4})').firstMatch(fullText);

    if (amountMatch == null || dateMatch == null) return [];

    final amountCents = PdfBankParser.parseAmountCents(amountMatch.group(1)!);
    if (amountCents == null || amountCents <= 0) return [];

    final dateParts = dateMatch.group(1)!.split('/');
    final date = DateTime(
      int.parse(dateParts[2]),
      int.parse(dateParts[1]),
      int.parse(dateParts[0]),
    );

    return [
      PdfParsedTransaction(
        date: date,
        description: 'Comprovante BB',
        amountCents: amountCents,
        type: 'expense',
        accountName: 'Conta BB',
        institution: 'Banco do Brasil',
      ),
    ];
  }
}
