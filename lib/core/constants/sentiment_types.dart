import 'package:flutter/material.dart';

enum SentimentType {
  terrible(1, 'Péssima', '😡', Colors.red),
  bad(2, 'Ruim', '😞', Colors.orange),
  neutral(3, 'Neutra', '😐', Colors.grey),
  good(4, 'Boa', '🙂', Colors.lightGreen),
  excellent(5, 'Ótima', '😄', Colors.green);

  final int value;
  final String label;
  final String emoji;
  final Color color;

  const SentimentType(this.value, this.label, this.emoji, this.color);

  static SentimentType? fromInt(int? val) {
    if (val == null) return null;
    return SentimentType.values.firstWhere(
      (s) => s.value == val,
      orElse: () => SentimentType.neutral,
    );
  }

  static SentimentType? fromString(String? val) {
    if (val == null) return null;
    return SentimentType.values.firstWhere(
      (s) => s.name == val,
      orElse: () => SentimentType.neutral,
    );
  }
}
