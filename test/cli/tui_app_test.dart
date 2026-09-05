import 'package:bestfin/cli/tui/context.dart';
import 'package:bestfin/cli/tui/screens/accounts_screen.dart';
import 'package:bestfin/cli/tui/screens/budgets_screen.dart';
import 'package:bestfin/cli/tui/screens/goals_screen.dart';
import 'package:bestfin/cli/tui/screens/settings_screen.dart';
import 'package:bestfin/cli/tui/screens/transactions_screen.dart';
import 'package:bestfin/cli/tui/tui_app.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

TuiContext _context(AppDatabase db) => TuiContext(db, dbPath: ':memory:');

void main() {
  group('menu principal', () {
    test('cobre todas as áreas do app, sem rótulos repetidos', () {
      final labels = TuiApp.entries.map((e) => e.label).toList();
      expect(labels.toSet().length, labels.length);

      // As áreas que a GUI expõe precisam ter contraparte na TUI.
      for (final expected in const [
        'Painel',
        'Transações',
        'Contas',
        'Categorias',
        'Cartões de crédito',
        'Orçamentos',
        'Metas',
        'Parcelamentos',
        'Recorrências',
        'Financiamentos',
        'Investimentos',
        'Relatórios',
        'Projeção de caixa',
        'Conquistas e insights',
        'Importar PDF',
        'Backup e dados',
        'Sincronização',
        'Grupos familiares',
        'Configurações',
      ]) {
        expect(labels, contains(expected));
      }
    });

    test('toda entrada constrói uma tela com título', () {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ctx = _context(db);

      for (final entry in TuiApp.entries) {
        final screen = entry.build(ctx);
        expect(screen.title, isNotEmpty, reason: entry.label);
      }
    });
  });

  group('resolveArea', () {
    late AppDatabase db;
    late TuiContext ctx;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      ctx = _context(db);
    });
    tearDown(() => db.close());

    test('casa o nome exato, ignorando acento e caixa', () {
      expect(TuiApp.resolveArea(ctx, 'Metas'), isA<GoalsScreen>());
      expect(TuiApp.resolveArea(ctx, 'transacoes'), isA<TransactionsScreen>());
      expect(TuiApp.resolveArea(ctx, 'ORÇAMENTOS'), isA<BudgetsScreen>());
    });

    test('casa por prefixo quando não é ambíguo', () {
      expect(TuiApp.resolveArea(ctx, 'orc'), isA<BudgetsScreen>());
      expect(TuiApp.resolveArea(ctx, 'config'), isA<SettingsScreen>());
    });

    test('devolve null para nome desconhecido, vazio ou ambíguo', () {
      expect(TuiApp.resolveArea(ctx, 'inexistente'), isNull);
      expect(TuiApp.resolveArea(ctx, ''), isNull);
      // "c" casa Categorias, Cartões, Conquistas e Configurações.
      expect(TuiApp.resolveArea(ctx, 'c'), isNull);
    });
  });

  group('TuiContext', () {
    late AppDatabase db;
    late TuiContext ctx;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      ctx = _context(db);
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc_tui',
              name: 'Conta TUI',
              type: 'checking',
            ),
          );
    });
    tearDown(() => db.close());

    test('expõe os mesmos repositórios que a GUI usa', () async {
      final accounts = await ctx.accounts.watchAllAccounts().first;
      expect(accounts.map((a) => a.name), contains('Conta TUI'));
    });

    test('rawAccounts esconde contas arquivadas por padrão', () async {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc_old',
              name: 'Arquivada',
              type: 'wallet',
              isArchived: const Value(true),
            ),
          );

      final visible = await ctx.rawAccounts();
      expect(visible.map((a) => a.id), isNot(contains('acc_old')));

      final all = await ctx.rawAccounts(includeArchived: true);
      expect(all.map((a) => a.id), contains('acc_old'));
    });

    test('rawCategories filtra por tipo', () async {
      final expenses = await ctx.rawCategories(type: 'expense');
      expect(expenses, isNotEmpty); // categorias padrão são semeadas
      expect(expenses.every((c) => c.type == 'expense'), isTrue);
    });

    test('requestExit registra o motivo para a TUI encerrar', () {
      expect(ctx.exitReason, isNull);
      ctx.requestExit('banco restaurado');
      expect(ctx.exitReason, 'banco restaurado');
    });
  });

  group('escrita pela TUI passa pelo caminho do app', () {
    test('criar conta pela TUI enfileira sync e calcula saldo', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ctx = _context(db);

      final id = await ctx.accounts.createWithInitialBalance(
        name: 'Poupança TUI',
        type: 'savings',
        icon: null,
        color: null,
        initialBalance: 25000,
      );

      final balance = await ctx.accounts.getAccountBalance(id);
      expect(balance, 25000);

      await Future<void>.delayed(const Duration(milliseconds: 200));
      final queued = await db.select(db.syncQueue).get();
      expect(
        queued.where((q) => q.entityId == id && q.operation == 'insert'),
        isNotEmpty,
        reason: 'conta criada na TUI deve entrar na fila de sync',
      );
    });

    test('telas leem os dados sem exigir terminal', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ctx = _context(db);

      // Construir as telas e ler seus dados não deve tocar em stdin.
      expect(AccountsScreen(ctx).title, 'Contas');
      expect(TransactionsScreen(ctx).title, 'Transações');
      final accounts = await ctx.accounts.watchAllAccounts().first;
      expect(accounts, isEmpty);
    });
  });
}
