import 'package:drift/drift.dart' show OrderingTerm;

import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';
import 'package:bestfin/features/budgets/data/repositories/budget_repository.dart';
import 'package:bestfin/features/categories/data/repositories/category_repository.dart';
import 'package:bestfin/features/credit_cards/data/repositories/credit_card_repository.dart';
import 'package:bestfin/features/credit_cards/data/repositories/invoice_repository.dart';
import 'package:bestfin/features/financing/data/repositories/financing_repository.dart';
import 'package:bestfin/features/gamification/data/repositories/streak_repository_impl.dart';
import 'package:bestfin/features/goals/data/repositories/goal_repository.dart';
import 'package:bestfin/features/installments/data/repositories/installment_repository.dart';
import 'package:bestfin/features/investments/data/repositories/investment_repository.dart';
import 'package:bestfin/features/recurring/data/repositories/recurring_repository.dart';
import 'package:bestfin/features/sync/data/repositories/household_repository.dart';
import 'package:bestfin/features/sync/data/services/nostr_sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/cli/tui/sync_engine.dart';

/// Container de dependências da TUI.
///
/// Instancia os mesmos repositórios usados pela GUI diretamente sobre a
/// [AppDatabase] — sem Riverpod, sem `WidgetsFlutterBinding`. Assim toda
/// escrita feita pela TUI passa pelo mesmo caminho de código do app
/// (partida dobrada, saldos derivados e enfileiramento em `sync_queue`).
class TuiContext {
  TuiContext(this.db, {required this.dbPath});

  final AppDatabase db;
  final String dbPath;

  /// Preenchido quando uma tela precisa encerrar a TUI (ex.: o arquivo do
  /// banco foi substituído por uma restauração e a conexão atual ficou inválida).
  String? exitReason;

  void requestExit(String reason) => exitReason = reason;

  late final AccountRepositoryImpl accounts = AccountRepositoryImpl(db);
  late final BudgetRepositoryImpl budgets = BudgetRepositoryImpl(db);
  late final CategoryRepositoryImpl categories = CategoryRepositoryImpl(db);
  late final CreditCardRepositoryImpl creditCards = CreditCardRepositoryImpl(
    db,
  );
  late final InvoiceRepositoryImpl invoices = InvoiceRepositoryImpl(db);
  late final FinancingRepositoryImpl financings = FinancingRepositoryImpl(db);
  late final GoalRepositoryImpl goals = GoalRepositoryImpl(db);
  late final InstallmentRepositoryImpl installments = InstallmentRepositoryImpl(
    db,
  );
  late final InvestmentRepositoryImpl investments = InvestmentRepositoryImpl(
    db,
  );
  late final RecurringRepositoryImpl recurring = RecurringRepositoryImpl(db);
  late final HouseholdRepositoryImpl households = HouseholdRepositoryImpl(db);
  late final TransactionRepositoryImpl transactions = TransactionRepositoryImpl(
    db,
  );
  late final StreakRepositoryImpl streaks = StreakRepositoryImpl(db.streaksDao);

  // ── Sync residente (task 57) ────────────────────────────────────────
  // Criados sob demanda: sem tocar em sync, nada de transporte Nostr é
  // instanciado. O engine vive enquanto a TUI estiver aberta.

  NostrSyncService? _nostr;
  TuiSyncEngine? _syncEngine;

  /// Transporte Nostr da sessão (criado no primeiro uso).
  NostrSyncService get nostr => _nostr ??= NostrSyncService(db);

  /// Engine de sincronização residente: live subscription + push com
  /// debounce + poll periódico, ativo enquanto a TUI estiver aberta.
  TuiSyncEngine get sync => _syncEngine ??= TuiSyncEngine(
    db,
    nostr,
    syncService: SyncService(db, nostr),
    startLiveSync: nostr.startLiveSync,
    liveEvents: nostr.liveEvents,
  );

  bool get hasSyncEngine => _syncEngine != null;

  // ── Histórico para sugestões (task 58) ──────────────────────────────

  /// Histórico recente de lançamentos (janela de 180 dias, mesmo recorte do
  /// recomendador estatístico da GUI) — alimenta sugestões e autocomplete.
  Future<List<TransactionModel>> recentHistory({int days = 180}) async {
    final all = await transactions.watchAllTransactions().first;
    final since = DateTime.now().subtract(Duration(days: days));
    return all.where((t) => !t.date.isBefore(since)).toList();
  }

  /// Contas ativas (linhas cruas do banco) — usado nos seletores.
  Future<List<Account>> rawAccounts({bool includeArchived = false}) {
    final q = db.select(db.accounts);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    q.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return q.get();
  }

  /// Categorias ativas (linhas cruas do banco).
  Future<List<Category>> rawCategories({
    String? type,
    bool includeArchived = false,
  }) {
    final q = db.select(db.categories);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    if (type != null) q.where((t) => t.type.equals(type));
    q.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return q.get();
  }

  Future<void> close() async {
    try {
      await _syncEngine?.dispose();
    } catch (_) {}
    try {
      await _nostr?.dispose();
    } catch (_) {}
    await db.close();
  }
}
