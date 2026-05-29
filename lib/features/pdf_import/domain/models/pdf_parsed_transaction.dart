class PdfParsedTransaction {
  final DateTime date;
  final String description;
  final int amountCents;
  final String type; // 'income' | 'expense'
  final String accountName;
  final String institution;
  bool selected;

  PdfParsedTransaction({
    required this.date,
    required this.description,
    required this.amountCents,
    required this.type,
    required this.accountName,
    required this.institution,
    this.selected = true,
  });

  PdfParsedTransaction copyWith({
    DateTime? date,
    String? description,
    int? amountCents,
    String? type,
    String? accountName,
    String? institution,
    bool? selected,
  }) {
    return PdfParsedTransaction(
      date: date ?? this.date,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      type: type ?? this.type,
      accountName: accountName ?? this.accountName,
      institution: institution ?? this.institution,
      selected: selected ?? this.selected,
    );
  }
}
