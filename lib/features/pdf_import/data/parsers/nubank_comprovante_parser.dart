import 'package:bestfin/features/pdf_import/data/parsers/pdf_bank_parser.dart';
import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';

class NubankComprovanteParser extends PdfBankParser {
  @override
  bool canHandle(String fullText) {
    final upper = fullText.toUpperCase();
    return upper.contains('NUBANK') &&
        (upper.contains('COMPROVANTE') || upper.contains('PIX')) &&
        !upper.contains('FATURA');
  }

  @override
  List<PdfParsedTransaction> parse(String fullText) {
    final upper = fullText.toUpperCase();

    final amountMatch = RegExp(r'R\$\s*([\d.,]+)').firstMatch(fullText);
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

    final isIncome =
        upper.contains('RECEBIDO') || upper.contains('RECEBIMENTO');
    final type = isIncome ? 'income' : 'expense';
    final description = isIncome ? 'Pix Recebido' : 'Pix Enviado';

    return [
      PdfParsedTransaction(
        date: date,
        description: description,
        amountCents: amountCents,
        type: type,
        accountName: 'Conta Nubank',
        institution: 'Nubank',
      ),
    ];
  }
}
