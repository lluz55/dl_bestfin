class SplitEntry {
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final int amount; // centavos
  final String? description;

  const SplitEntry({
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    required this.amount,
    this.description,
  });

  SplitEntry copyWith({
    String? categoryId,
    String? categoryName,
    String? categoryColor,
    String? categoryIcon,
    int? amount,
    String? description,
    bool clearCategory = false,
    bool clearDescription = false,
  }) {
    return SplitEntry(
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      categoryName: clearCategory ? null : (categoryName ?? this.categoryName),
      categoryColor: clearCategory
          ? null
          : (categoryColor ?? this.categoryColor),
      categoryIcon: clearCategory ? null : (categoryIcon ?? this.categoryIcon),
      amount: amount ?? this.amount,
      description: clearDescription ? null : (description ?? this.description),
    );
  }
}
