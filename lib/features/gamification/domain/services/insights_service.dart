import '../../../transactions/data/repositories/transaction_repository.dart';
import '../../../transactions/domain/models/transaction.dart';
import 'package:bestfin/core/constants/transaction_types.dart';

class InsightModel {
  final String text;
  final String icon; // Emoji or IconData string
  final String? actionLabel;
  final String? actionRoute;

  const InsightModel({
    required this.text,
    required this.icon,
    this.actionLabel,
    this.actionRoute,
  });
}

class InsightsService {
  final TransactionRepository _transactionRepository;

  InsightsService(this._transactionRepository);

  Future<List<InsightModel>> generateInsights() async {
    final txs = await _transactionRepository.watchAllTransactions().first;
    if (txs.isEmpty) {
      return [
        const InsightModel(
          text: 'Comece a registrar suas transações para ver insights aqui!',
          icon: '💡',
        ),
      ];
    }

    final insights = <InsightModel>[];

    // 1. Check for negative sentiment
    final badSentiments = txs.where((t) => t.sentiment?.name == 'sad' || t.sentiment?.name == 'angry');
    if (badSentiments.isNotEmpty) {
      final totalBad = badSentiments.fold(0, (sum, t) => sum + t.amount);
      if (totalBad > 0) {
        insights.add(InsightModel(
          text: 'Você gastou R\$ ${(totalBad / 100).toStringAsFixed(2)} em compras que te deixaram triste. Considere eliminá-las!',
          icon: '😞',
        ));
      }
    }

    // 2. Positive balance insight
    final now = DateTime.now();
    final thisMonth = txs.where((t) => t.date.month == now.month && t.date.year == now.year);
    final income = thisMonth.where((t) => t.type == TransactionType.income).fold(0, (sum, t) => sum + t.amount);
    final expense = thisMonth.where((t) => t.type == TransactionType.expense).fold(0, (sum, t) => sum + t.amount);
    
    if (income > expense && income > 0) {
      insights.add(const InsightModel(
        text: 'Parabéns! Você está gastando menos do que ganha este mês. Continue assim! 🎉',
        icon: '📈',
      ));
    }

    // 3. No Lazer expenses (example)
    final hasLazer = thisMonth.any((t) => t.category?.name.toLowerCase().contains('lazer') ?? false);
    if (!hasLazer && thisMonth.isNotEmpty) {
       insights.add(const InsightModel(
        text: 'Nenhum gasto em Lazer este mês. Lembre-se de reservar um tempo para você!',
        icon: '🏖️',
      ));
    }

    // Default insight if none generated
    if (insights.isEmpty) {
      insights.add(const InsightModel(
        text: 'Mantenha seus registros em dia para receber dicas personalizadas.',
        icon: '💡',
      ));
    }

    return insights;
  }
}
