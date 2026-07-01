import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/cashflow/domain/models/cashflow_projection.dart';
import 'package:bestfin/features/cashflow/domain/use_cases/calculate_cashflow_projection.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

final cashFlowProjectionProvider =
    FutureProvider.autoDispose<CashFlowProjection>((ref) async {
      final db = ref.watch(databaseProvider);
      final txRepo = ref.watch(transactionRepositoryProvider);
      final useCase = CalculateCashFlowProjection(
        db: db,
        transactionRepository: txRepo,
      );
      return useCase.call(days: 90);
    });
