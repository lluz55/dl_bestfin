import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';

abstract class PdfBankParser {
  bool canHandle(String fullText);
  List<PdfParsedTransaction> parse(String fullText);

  // Handles "1.234,56" → 123456 and "1234.56" → 123456
  static int? parseAmountCents(String raw) {
    String normalized = raw.trim();
    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (normalized.contains(',')) {
      normalized = normalized.replaceAll(',', '.');
    }
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * 100).round();
  }
}
