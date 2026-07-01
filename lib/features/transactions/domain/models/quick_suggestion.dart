import 'package:bestfin/core/constants/transaction_types.dart';

/// Um lançamento sugerido pelo recomendador de "Lançamento Rápido".
///
/// Representa um agrupamento do histórico (mesmo tipo + categoria/entidade ou
/// par origem→destino) já resolvido para os campos necessários à criação de uma
/// nova transação em 1 toque. É apenas uma sugestão: a criação real continua
/// passando por `CreateTransaction`, que valida a partida dobrada.
class QuickSuggestion {
  final TransactionType type;
  final String description;
  final int amount;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? entityId;

  /// Pontuação de relevância (frequência ponderada por recência). Maior = mais provável.
  final double score;

  const QuickSuggestion({
    required this.type,
    required this.description,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.entityId,
    required this.score,
  });
}
