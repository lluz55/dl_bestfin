import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HomeWidgetId {
  freeToSpend,
  incomeExpenseBar,
  spendingDonut,
  goalsProgress,
  upcomingBills,
  streaks,
  insightCard,
  monthlyBarChart,
  netWorthLineChart,
  categoryRanking,
  cashFlowLineChart,
}

extension HomeWidgetIdLabel on HomeWidgetId {
  String get label => switch (this) {
    HomeWidgetId.freeToSpend => 'Livre para gastar',
    HomeWidgetId.incomeExpenseBar => 'Receitas vs Despesas',
    HomeWidgetId.spendingDonut => 'Gastos por categoria',
    HomeWidgetId.goalsProgress => 'Progresso de metas',
    HomeWidgetId.upcomingBills => 'Próximas contas',
    HomeWidgetId.streaks => 'Sequência',
    HomeWidgetId.insightCard => 'Insight IA',
    HomeWidgetId.monthlyBarChart => 'Receitas vs Despesas (Mensal)',
    HomeWidgetId.netWorthLineChart => 'Evolução Patrimonial',
    HomeWidgetId.categoryRanking => 'Ranking de Categorias',
    HomeWidgetId.cashFlowLineChart => 'Fluxo de Caixa',
  };
}

const _defaultOrder = HomeWidgetId.values;

class HomeWidgetsNotifier extends Notifier<List<HomeWidgetId>> {
  static const _key = 'home_widgets_order';
  static const _hiddenKey = 'home_widgets_hidden';

  @override
  List<HomeWidgetId> build() {
    _load();
    return List.of(_defaultOrder);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final orderIds = prefs.getStringList(_key);
    final hiddenIds = prefs.getStringList(_hiddenKey) ?? [];

    if (orderIds == null) return;

    final ordered = orderIds
        .map((id) {
          try {
            return HomeWidgetId.values.firstWhere((e) => e.name == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<HomeWidgetId>()
        .where((id) => !hiddenIds.contains(id.name))
        .toList();

    // Add any new widgets not yet in prefs at the end
    for (final id in HomeWidgetId.values) {
      if (!orderIds.contains(id.name) && !hiddenIds.contains(id.name)) {
        ordered.add(id);
      }
    }

    state = ordered;
  }

  Future<void> save(
    List<HomeWidgetId> visible,
    List<HomeWidgetId> hidden,
  ) async {
    state = visible;
    final prefs = await SharedPreferences.getInstance();
    final allOrder = [...visible, ...hidden];
    await prefs.setStringList(_key, allOrder.map((e) => e.name).toList());
    await prefs.setStringList(_hiddenKey, hidden.map((e) => e.name).toList());
  }

  Future<void> resetToDefault() async {
    state = List.of(_defaultOrder);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_hiddenKey);
  }
}

final homeWidgetsProvider =
    NotifierProvider<HomeWidgetsNotifier, List<HomeWidgetId>>(
      HomeWidgetsNotifier.new,
    );
