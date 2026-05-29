import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/installments/data/repositories/installment_repository.dart';
import 'package:bestfin/features/installments/domain/models/installment_plan.dart';

final installmentRepositoryProvider = Provider<InstallmentRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return InstallmentRepositoryImpl(database);
});

final installmentPlansProvider = StreamProvider<List<InstallmentPlanModel>>((
  ref,
) {
  final repository = ref.watch(installmentRepositoryProvider);
  return repository.watchInstallmentPlans();
});
