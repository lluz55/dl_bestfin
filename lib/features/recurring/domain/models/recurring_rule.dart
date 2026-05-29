import 'package:bestfin/core/database/app_database.dart' as db;

/// Frequências suportadas pela regra de recorrência.
enum RecurringFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  yearly;

  static RecurringFrequency fromString(String value) {
    return RecurringFrequency.values.firstWhere(
      (f) => f.name == value,
      orElse: () => RecurringFrequency.monthly,
    );
  }

  String get label {
    switch (this) {
      case RecurringFrequency.daily:
        return 'Diária';
      case RecurringFrequency.weekly:
        return 'Semanal';
      case RecurringFrequency.biweekly:
        return 'Quinzenal';
      case RecurringFrequency.monthly:
        return 'Mensal';
      case RecurringFrequency.yearly:
        return 'Anual';
    }
  }

  String get shortLabel {
    switch (this) {
      case RecurringFrequency.daily:
        return '/dia';
      case RecurringFrequency.weekly:
        return '/sem';
      case RecurringFrequency.biweekly:
        return '/quin';
      case RecurringFrequency.monthly:
        return '/mês';
      case RecurringFrequency.yearly:
        return '/ano';
    }
  }
}

/// Status da regra de recorrência.
enum RecurringStatus {
  active,
  paused,
  finished;

  static RecurringStatus fromString(String value) {
    return RecurringStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => RecurringStatus.active,
    );
  }

  String get label {
    switch (this) {
      case RecurringStatus.active:
        return 'Ativa';
      case RecurringStatus.paused:
        return 'Pausada';
      case RecurringStatus.finished:
        return 'Finalizada';
    }
  }
}

/// Modelo de domínio de uma regra de recorrência.
class RecurringRuleModel {
  final String id;
  final String baseTransactionId;
  final RecurringFrequency frequency;
  final int interval;
  final DateTime nextDate;
  final DateTime? endDate;
  final RecurringStatus status;
  final bool autoConfirm;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Dados carregados da transação-base
  final String? description;
  final String? type;
  final int? amountInCents;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  final String? accountId;

  const RecurringRuleModel({
    required this.id,
    required this.baseTransactionId,
    required this.frequency,
    required this.interval,
    required this.nextDate,
    this.endDate,
    required this.status,
    required this.autoConfirm,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.type,
    this.amountInCents,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    this.accountId,
  });

  factory RecurringRuleModel.fromDb(
    db.RecurringRule rule, {
    String? description,
    String? type,
    int? amountInCents,
    String? categoryId,
    String? categoryName,
    String? categoryColor,
    String? categoryIcon,
    String? accountId,
  }) {
    return RecurringRuleModel(
      id: rule.id,
      baseTransactionId: rule.baseTransactionId,
      frequency: RecurringFrequency.fromString(rule.frequency),
      interval: rule.interval,
      nextDate: rule.nextDate,
      endDate: rule.endDate,
      status: RecurringStatus.fromString(rule.status),
      autoConfirm: rule.autoConfirm,
      createdAt: rule.createdAt,
      updatedAt: rule.updatedAt,
      description: description,
      type: type,
      amountInCents: amountInCents,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryColor: categoryColor,
      categoryIcon: categoryIcon,
      accountId: accountId,
    );
  }

  /// Valor mensal equivalente (para o hub de assinaturas).
  double get monthlyEquivalentInCents {
    if (amountInCents == null) return 0;
    switch (frequency) {
      case RecurringFrequency.daily:
        return amountInCents! * 30.0 / interval;
      case RecurringFrequency.weekly:
        return amountInCents! * 4.33 / interval;
      case RecurringFrequency.biweekly:
        return amountInCents! * 2.17 / interval;
      case RecurringFrequency.monthly:
        return amountInCents! / interval;
      case RecurringFrequency.yearly:
        return amountInCents! / (12.0 * interval);
    }
  }
}
