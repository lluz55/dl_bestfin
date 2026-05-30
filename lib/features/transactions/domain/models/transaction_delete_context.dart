enum TransactionDeleteCase {
  regular,
  installment,
  recurringBase,
  recurringClone,
}

class TransactionDeleteContext {
  final TransactionDeleteCase deleteCase;
  final String? installmentPlanId;
  final int? installmentNumber;
  final int? totalInstallments;
  final String? recurringRuleId;

  const TransactionDeleteContext({
    required this.deleteCase,
    this.installmentPlanId,
    this.installmentNumber,
    this.totalInstallments,
    this.recurringRuleId,
  });
}
