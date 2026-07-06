import 'package:flutter/material.dart';

enum TransactionStatus {
  completed('Concluída', Icons.check_circle_rounded),
  scheduled('Agendado', Icons.event_available_rounded),
  pending('Pendente', Icons.schedule_rounded);

  final String label;
  final IconData icon;

  const TransactionStatus(this.label, this.icon);

  static TransactionStatus fromFlags({
    required bool isCompleted,
    required DateTime date,
  }) {
    if (isCompleted) return TransactionStatus.completed;
    return isFutureDate(date)
        ? TransactionStatus.scheduled
        : TransactionStatus.pending;
  }

  static bool isFutureDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    return d.isAfter(today);
  }
}
