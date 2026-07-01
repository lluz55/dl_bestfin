class CashFlowProjectionPoint {
  final DateTime date;
  final int cumulativeBalance;
  final int dailyNet;

  const CashFlowProjectionPoint({
    required this.date,
    required this.cumulativeBalance,
    required this.dailyNet,
  });
}

class CashFlowProjection {
  final int currentBalance;
  final List<CashFlowProjectionPoint> points;
  final int projectedBalance30d;
  final int projectedBalance60d;
  final int projectedBalance90d;

  const CashFlowProjection({
    required this.currentBalance,
    required this.points,
    required this.projectedBalance30d,
    required this.projectedBalance60d,
    required this.projectedBalance90d,
  });
}
