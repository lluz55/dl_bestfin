import 'package:flutter/material.dart';

enum TransactionStatus {
  completed('Concluída', Icons.check_circle_rounded),
  pending('Pendente', Icons.schedule_rounded);

  final String label;
  final IconData icon;

  const TransactionStatus(this.label, this.icon);

  static TransactionStatus fromFlags({required bool isCompleted}) =>
      isCompleted ? TransactionStatus.completed : TransactionStatus.pending;
}
