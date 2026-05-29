class TransactionSuggestion {
  final String packageName;
  final String rawTitle;
  final String rawContent;
  final int amountInCents;
  final String? merchant;
  final DateTime capturedAt;

  const TransactionSuggestion({
    required this.packageName,
    required this.rawTitle,
    required this.rawContent,
    required this.amountInCents,
    this.merchant,
    required this.capturedAt,
  });
}
