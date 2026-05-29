import 'package:bestfin/core/database/app_database.dart' as db;

/// Status de um objetivo financeiro.
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

/// Tipo de objetivo financeiro.
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

/// Modelo de domínio de um Objetivo Financeiro.
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
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Computed ────────────────────────────────────────────────────────────────

  /// Progresso de 0.0 a 1.0 (pode ultrapassar 1.0 se overshoot).
  double get progressFraction {
    if (targetAmountInCents <= 0) return 0;
    return currentAmountInCents / targetAmountInCents;
  }

  /// Progresso em percentual (0 – 100+).
  double get progressPercent => progressFraction * 100;

  /// Valor restante para atingir a meta (pode ser negativo se já superou).
  int get remainingInCents => targetAmountInCents - currentAmountInCents;

  /// Objetivo está concluído (current >= target).
  bool get isCompleted =>
      status == GoalStatus.completed ||
      currentAmountInCents >= targetAmountInCents;

  /// Meses restantes até [targetDate]. Retorna `null` se sem prazo.
  int? get monthsRemaining {
    if (targetDate == null) return null;
    final now = DateTime.now();
    if (targetDate!.isBefore(now)) return 0;
    return (targetDate!.year - now.year) * 12 + (targetDate!.month - now.month);
  }

  /// Valor mensal ideal para atingir a meta no prazo.
  int? get monthlyTargetInCents {
    final months = monthsRemaining;
    if (months == null || months <= 0) return null;
    final remaining = remainingInCents;
    if (remaining <= 0) return 0;
    return (remaining / months).ceil();
  }

  // ── Factory ─────────────────────────────────────────────────────────────────

  factory GoalModel.fromDb(db.Goal g) {
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Resultado do simulador mensal com 3 cenários.
class MonthlySimulation {
  /// Valor mensal otimista (20% a menos que o ideal).
  final int optimisticInCents;

  /// Valor mensal ideal (exato para atingir no prazo).
  final int idealInCents;

  /// Valor mensal pessimista (20% a mais que o ideal).
  final int pessimisticInCents;

  /// Meses usados no cálculo.
  final int months;

  const MonthlySimulation({
    required this.optimisticInCents,
    required this.idealInCents,
    required this.pessimisticInCents,
    required this.months,
  });
}
