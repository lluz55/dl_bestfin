import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';

/// Leva o usuário à aba de Transações já filtrada por [categoryId], a partir de
/// um toque num componente de categoria da Home (donut de distribuição, ranking
/// de categorias). Substitui os filtros ativos por apenas o de categoria para
/// um recorte limpo daquela categoria.
void goToTransactionsForCategory(
  BuildContext context,
  WidgetRef ref,
  String categoryId,
) {
  ref.read(transactionFiltersProvider.notifier).state = TransactionFilters(
    categoryId: categoryId,
  );
  context.go('/transactions');
}
