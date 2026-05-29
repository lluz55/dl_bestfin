import 'package:bestfin/features/pdf_import/data/parsers/pdf_bank_parser.dart';
import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';

class NubankFaturaParser extends PdfBankParser {
  static const _ptMonths = {
    'jan': 1, 'fev': 2, 'mar': 3, 'abr': 4,
    'mai': 5, 'jun': 6, 'jul': 7, 'ago': 8,
    'set': 9, 'out': 10, 'nov': 11, 'dez': 12,
  };

  @override
  bool canHandle(String fullText) {
    final upper = fullText.toUpperCase();
    return upper.contains('NUBANK') && upper.contains('FATURA');
  }

  @override
  List<PdfParsedTransaction> parse(String fullText) {
    final transactions = <PdfParsedTransaction>[];

    // Try to detect the billing year from lines like "Janeiro 2025" or "jan/2025"
    final now = DateTime.now();
    int billingYear = now.year;
    final yearMatch = RegExp(r'(\d{4})').firstMatch(fullText);
    if (yearMatch != null) {
      billingYear = int.parse(yearMatch.group(1)!);
    }

    // Pattern: "15 jan  Descrição da compra  45,90"
    // Also handles installments: "15 jan  Descrição - Parcela 1/12  45,90"
    final lineRegex = RegExp(
      r'^(\d{2})\s+(\w{3})\s+(.+?)\s+([\d]+[.,]\d{2})\s*$',
      multiLine: true,
    );

    for (final match in lineRegex.allMatches(fullText)) {
      final day = int.tryParse(match.group(1)!);
      final monthStr = match.group(2)!.toLowerCase();
      final description = match.group(3)!.trim();
      final amountStr = match.group(4)!;

      if (day == null) continue;
      final month = _ptMonths[monthStr];
      if (month == null) continue;

      // Skip header/summary lines
      if (description.toUpperCase().contains('TOTAL') ||
          description.toUpperCase().contains('PAGAMENTO') ||
          description.toUpperCase().contains('LIMITE')) {
        continue;
      }

      final amountCents = PdfBankParser.parseAmountCents(amountStr);
      if (amountCents == null || amountCents <= 0) continue;

      // Guard against invalid dates (e.g., day 31 in a 30-day month)
      DateTime date;
      try {
        date = DateTime(billingYear, month, day);
      } catch (_) {
        continue;
      }

      transactions.add(PdfParsedTransaction(
        date: date,
        description: description,
        amountCents: amountCents,
        type: 'expense',
        accountName: 'Cartão Nubank',
        institution: 'Nubank',
      ));
    }

    return transactions;
  }
}
