import 'package:bestfin/core/constants/transaction_types.dart';

enum FieldConfidence { high, medium, low }

class ParsedTransaction {
  ParsedTransaction({
    required this.type,
    this.amountCents,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.description,
    required this.confidences,
    this.rawPhrase,
  });

  final TransactionType type;
  final int? amountCents;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? description;
  final Map<String, FieldConfidence> confidences;
  final String? rawPhrase;

  FieldConfidence confidenceFor(String field) =>
      confidences[field] ?? FieldConfidence.low;

  bool get isComplete =>
      amountCents != null &&
      amountCents! > 0 &&
      description != null &&
      description!.trim().isNotEmpty &&
      accountId != null &&
      (type != TransactionType.transfer || toAccountId != null);

  List<String> get lowConfidenceFields => confidences.entries
      .where((e) => e.value == FieldConfidence.low)
      .map((e) => e.key)
      .toList();
}
