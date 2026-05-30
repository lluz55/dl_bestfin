import 'package:flutter/material.dart';

@immutable
class ExpressiveShapes extends ThemeExtension<ExpressiveShapes> {
  const ExpressiveShapes({
    required this.card,
    required this.button,
    required this.chip,
    required this.chipSelected,
    required this.dialog,
    required this.bottomSheet,
    required this.balanceCard,
    required this.transactionTile,
    required this.fabDefault,
    required this.fabExpanded,
    required this.navigationBar,
  });

  final BorderRadius card;
  final BorderRadius button;
  final BorderRadius chip;
  final BorderRadius chipSelected;
  final BorderRadius dialog;
  final BorderRadius bottomSheet;
  final BorderRadius balanceCard;
  final BorderRadius transactionTile;
  final BorderRadius fabDefault;
  final BorderRadius fabExpanded;
  final BorderRadius navigationBar;

  @override
  ExpressiveShapes copyWith({
    BorderRadius? card,
    BorderRadius? button,
    BorderRadius? chip,
    BorderRadius? chipSelected,
    BorderRadius? dialog,
    BorderRadius? bottomSheet,
    BorderRadius? balanceCard,
    BorderRadius? transactionTile,
    BorderRadius? fabDefault,
    BorderRadius? fabExpanded,
    BorderRadius? navigationBar,
  }) {
    return ExpressiveShapes(
      card: card ?? this.card,
      button: button ?? this.button,
      chip: chip ?? this.chip,
      chipSelected: chipSelected ?? this.chipSelected,
      dialog: dialog ?? this.dialog,
      bottomSheet: bottomSheet ?? this.bottomSheet,
      balanceCard: balanceCard ?? this.balanceCard,
      transactionTile: transactionTile ?? this.transactionTile,
      fabDefault: fabDefault ?? this.fabDefault,
      fabExpanded: fabExpanded ?? this.fabExpanded,
      navigationBar: navigationBar ?? this.navigationBar,
    );
  }

  @override
  ExpressiveShapes lerp(ThemeExtension<ExpressiveShapes>? other, double t) {
    if (other is! ExpressiveShapes) {
      return this;
    }
    return ExpressiveShapes(
      card: BorderRadius.lerp(card, other.card, t)!,
      button: BorderRadius.lerp(button, other.button, t)!,
      chip: BorderRadius.lerp(chip, other.chip, t)!,
      chipSelected: BorderRadius.lerp(chipSelected, other.chipSelected, t)!,
      dialog: BorderRadius.lerp(dialog, other.dialog, t)!,
      bottomSheet: BorderRadius.lerp(bottomSheet, other.bottomSheet, t)!,
      balanceCard: BorderRadius.lerp(balanceCard, other.balanceCard, t)!,
      transactionTile: BorderRadius.lerp(
        transactionTile,
        other.transactionTile,
        t,
      )!,
      fabDefault: BorderRadius.lerp(fabDefault, other.fabDefault, t)!,
      fabExpanded: BorderRadius.lerp(fabExpanded, other.fabExpanded, t)!,
      navigationBar: BorderRadius.lerp(navigationBar, other.navigationBar, t)!,
    );
  }

  static const defaultShapes = ExpressiveShapes(
    card: BorderRadius.only(
      topLeft: Radius.circular(28),
      topRight: Radius.circular(8),
      bottomLeft: Radius.circular(8),
      bottomRight: Radius.circular(28),
    ),
    button: BorderRadius.all(Radius.circular(16)),
    chip: BorderRadius.all(Radius.circular(8)),
    chipSelected: BorderRadius.all(Radius.circular(20)),
    dialog: BorderRadius.all(Radius.circular(28)),
    bottomSheet: BorderRadius.only(
      topLeft: Radius.circular(32),
      topRight: Radius.circular(32),
    ),
    balanceCard: BorderRadius.only(
      topLeft: Radius.circular(32),
      topRight: Radius.circular(8),
      bottomLeft: Radius.circular(8),
      bottomRight: Radius.circular(32),
    ),
    transactionTile: BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
      bottomLeft: Radius.circular(4),
      bottomRight: Radius.circular(4),
    ),
    fabDefault: BorderRadius.all(Radius.circular(16)),
    fabExpanded: BorderRadius.all(Radius.circular(28)),
    navigationBar: BorderRadius.all(Radius.circular(20)),
  );
}
