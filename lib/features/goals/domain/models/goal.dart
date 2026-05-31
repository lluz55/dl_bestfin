import 'package:bestfin/core/database/app_database.dart' as db;

enum GoalStatus {
  active('active', 'Ativo'),
  completed('completed', 'Concluído'),
  archived('archived', 'Arquivado');

  const GoalStatus(this.value, this.label);
  final String value;
  final String label;

  static GoalStatus fromString(String value) {
    return GoalStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => GoalStatus.active,
    );
  }
}

enum GoalType {
  saving('saving', 'Economia'),
  spending('spending', 'Orçamento/Gasto');

  const GoalType(this.value, this.label);
  final String value;
  final String label;

  static GoalType fromString(String value) {
    return GoalType.values.firstWhere(
      (s) => s.value == value,
      orElse: () => GoalType.saving,
    );
  }
}

enum GoalRecurrenceFrequency {
  monthly('monthly', 'Mensal'),
  quarterly('quarterly', 'Trimestral'),
  yearly('yearly', 'Anual');

  const GoalRecurrenceFrequency(this.value, this.label);
  final String value;
  final String label;

  static GoalRecurrenceFrequency? fromString(String? value) {
    if (value == null) return null;
    return GoalRecurrenceFrequency.values.firstWhere(
      (f) => f.value == value,
      orElse: () => GoalRecurrenceFrequency.monthly,
    );
  }
}

class GoalModel {
  final String id;
  final String name;
  final String? description;
  final int targetAmountInCents;
  final int currentAmountInCents;
  final DateTime? targetDate;
  final String? accountId;
  final String? color;
  final String? icon;
  final GoalType type;
  final GoalStatus status;
  final bool isRecurring;
  final GoalRecurrenceFrequency? recurrenceFrequency;
  final DateTime? periodStartDate;
  final List<String> categoryIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GoalModel({
    required this.id,
    required this.name,
    this.description,
    required this.targetAmountInCents,
    required this.currentAmountInCents,
    this.targetDate,
    this.accountId,
    this.color,
    this.icon,
    this.type = GoalType.saving,
    required this.status,
    this.isRecurring = false,
    this.recurrenceFrequency,
    this.periodStartDate,
    this.categoryIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Computed ────────────────────────────────────────────────────────────────

  double get progressFraction {
    if (targetAmountInCents <= 0) return 0;
    return currentAmountInCents / targetAmountInCents;
  }

  double get progressPercent => progressFraction * 100;

  int get remainingInCents => targetAmountInCents - currentAmountInCents;

  bool get isCompleted =>
      status == GoalStatus.completed ||
      currentAmountInCents >= targetAmountInCents;

  int? get monthsRemaining {
    if (targetDate == null) return null;
    final now = DateTime.now();
    if (targetDate!.isBefore(now)) return 0;
    return (targetDate!.year - now.year) * 12 + (targetDate!.month - now.month);
  }

  int? get monthlyTargetInCents {
    final months = monthsRemaining;
    if (months == null || months <= 0) return null;
    final remaining = remainingInCents;
    if (remaining <= 0) return 0;
    return (remaining / months).ceil();
  }

  /// Verifica se o período recorrente atual expirou e precisa resetar.
  bool get isPeriodExpired {
    if (!isRecurring ||
        recurrenceFrequency == null ||
        periodStartDate == null) {
      return false;
    }
    final now = DateTime.now();
    final start = periodStartDate!;
    final end = switch (recurrenceFrequency!) {
      GoalRecurrenceFrequency.monthly => DateTime(
        start.year,
        start.month + 1,
        start.day,
      ),
      GoalRecurrenceFrequency.quarterly => DateTime(
        start.year,
        start.month + 3,
        start.day,
      ),
      GoalRecurrenceFrequency.yearly => DateTime(
        start.year + 1,
        start.month,
        start.day,
      ),
    };
    return now.isAfter(end);
  }

  /// Calcula o início do próximo período com base no atual.
  DateTime? get nextPeriodStart {
    if (!isRecurring ||
        recurrenceFrequency == null ||
        periodStartDate == null) {
      return null;
    }
    final start = periodStartDate!;
    return switch (recurrenceFrequency!) {
      GoalRecurrenceFrequency.monthly => DateTime(
        start.year,
        start.month + 1,
        start.day,
      ),
      GoalRecurrenceFrequency.quarterly => DateTime(
        start.year,
        start.month + 3,
        start.day,
      ),
      GoalRecurrenceFrequency.yearly => DateTime(
        start.year + 1,
        start.month,
        start.day,
      ),
    };
  }

  // ── Factory ─────────────────────────────────────────────────────────────────

  factory GoalModel.fromDb(db.Goal g, {List<String> categoryIds = const []}) {
    return GoalModel(
      id: g.id,
      name: g.name,
      description: g.description,
      targetAmountInCents: g.targetAmount,
      currentAmountInCents: g.currentAmount,
      targetDate: g.targetDate,
      accountId: g.accountId,
      color: g.color,
      icon: g.icon,
      type: GoalType.fromString(g.type),
      status: GoalStatus.fromString(g.status),
      isRecurring: g.isRecurring,
      recurrenceFrequency: GoalRecurrenceFrequency.fromString(
        g.recurrenceFrequency,
      ),
      periodStartDate: g.periodStartDate,
      categoryIds: categoryIds,
      createdAt: g.createdAt,
      updatedAt: g.updatedAt,
    );
  }

  GoalModel copyWith({
    String? id,
    String? name,
    String? description,
    int? targetAmountInCents,
    int? currentAmountInCents,
    DateTime? targetDate,
    String? accountId,
    String? color,
    String? icon,
    GoalType? type,
    GoalStatus? status,
    bool? isRecurring,
    GoalRecurrenceFrequency? recurrenceFrequency,
    DateTime? periodStartDate,
    List<String>? categoryIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmountInCents: targetAmountInCents ?? this.targetAmountInCents,
      currentAmountInCents: currentAmountInCents ?? this.currentAmountInCents,
      targetDate: targetDate ?? this.targetDate,
      accountId: accountId ?? this.accountId,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      status: status ?? this.status,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceFrequency: recurrenceFrequency ?? this.recurrenceFrequency,
      periodStartDate: periodStartDate ?? this.periodStartDate,
      categoryIds: categoryIds ?? this.categoryIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MonthlySimulation {
  final int optimisticInCents;
  final int idealInCents;
  final int pessimisticInCents;
  final int months;

  const MonthlySimulation({
    required this.optimisticInCents,
    required this.idealInCents,
    required this.pessimisticInCents,
    required this.months,
  });
}
