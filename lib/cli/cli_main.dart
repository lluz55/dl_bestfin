import 'dart:async';
import 'dart:io';

import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/nostr_sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/features/transactions/data/repositories/transaction_repository.dart';
import 'package:bestfin/features/transactions/domain/usecases/get_quick_suggestions.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/usecases/predict_category.dart';
import 'package:bestfin/features/transactions/domain/usecases/create_transaction.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'package:bestfin/cli/db_path_resolver.dart';
import 'package:bestfin/cli/llm_bridge.dart';
import 'package:bestfin/cli/nl_parser.dart';
import 'package:bestfin/cli/parse_result.dart';
import 'package:bestfin/cli/tui/context.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/cli/tui/tui_app.dart';
import 'package:bestfin/cli/tui/tui_runner.dart';

/// Entrypoint do modo CLI/TUI — chamado por `main()` antes do `runApp`.
///
/// Retorna exit code (0 = sucesso).
Future<int> runCli(List<String> args) async {
  // Parsing simples de args: `bestfin add "frase" [--db PATH]` ou `bestfin tui`
  if (args.isEmpty) {
    _printHelp();
    return 0;
  }

  // Normaliza: primeiro arg é subcomando
  final cmd = args.first.toLowerCase();

  // --help global
  if (cmd == '--help' || cmd == '-h' || cmd == 'help') {
    _printHelp();
    return 0;
  }

  // Extrai --db flag (pode estar em qualquer posição)
  String? dbOverride;
  final filtered = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--db' && i + 1 < args.length) {
      dbOverride = args[i + 1];
      i++;
    } else if (args[i].startsWith('--db=')) {
      dbOverride = args[i].substring(5);
    } else {
      filtered.add(args[i]);
    }
  }

  if (filtered.isEmpty) {
    _printHelp();
    return 0;
  }

  final sub = filtered.first.toLowerCase();
  final phraseParts = filtered.length > 1 ? filtered.sublist(1) : <String>[];
  final phrase = phraseParts.join(' ').trim();

  // add --help
  if (phrase == '--help' || phrase == '-h') {
    _printAddHelp();
    return 0;
  }

  switch (sub) {
    case 'add':
      if (phrase.isEmpty) {
        return _runTuiWizard(dbOverride: dbOverride);
      } else {
        return _runAddPhrase(phrase, dbOverride: dbOverride);
      }
    case 'tui':
      return _runFullTui(dbOverride: dbOverride, area: phrase);
    case 'sync':
      return _runSyncOnce(dbOverride: dbOverride, extra: phraseParts);
    default:
      stderr.writeln('Comando desconhecido: $sub');
      _printHelp();
      return 2;
  }
}

/// Abre a TUI completa — todas as áreas do app pelo terminal.
///
/// [area] opcional pula direto para uma tela (`bestfin tui metas`).
Future<int> _runFullTui({String? dbOverride, String area = ''}) async {
  final dbPath = resolveBestfinDbPath(override: dbOverride);
  if (!File(dbPath).existsSync()) {
    stderr.writeln(
      'Banco não encontrado em: $dbPath\n'
      'Execute o app gráfico uma vez para criá-lo, ou use --db <path>.',
    );
    return 1;
  }

  AppDatabase? db;
  try {
    db = _openDb(dbPath);
    final ctx = TuiContext(db, dbPath: dbPath);
    final app = TuiApp(ctx);
    // Encerramento limpo: restaura o terminal e fecha transport/fila.
    final sigtermSub = Platform.isWindows
        ? null
        : ProcessSignal.sigterm.watch().listen((_) {
            Term.restore();
            exit(0);
          });
    try {
      final code = await _runFullTuiInner(ctx, app, area: area);
      return code;
    } finally {
      await sigtermSub?.cancel();
      await ctx.close();
    }
  } on SqliteException catch (e) {
    Term.restore();
    final msg = e.message.toLowerCase();
    if (msg.contains('locked') || msg.contains('busy')) {
      stderr.writeln(
        'Banco está em uso por outro processo (app gráfico aberto?).\n'
        'Feche o app e tente novamente.',
      );
    } else {
      stderr.writeln('Erro no banco: ${e.message}');
    }
    try {
      await db?.close();
    } catch (_) {}
    return 1;
  } catch (e) {
    Term.restore();
    stderr.writeln('Erro: $e');
    try {
      await db?.close();
    } catch (_) {}
    return 1;
  }
}

/// Loop da TUI — direto numa área ou no menu completo.
Future<int> _runFullTuiInner(
  TuiContext ctx,
  TuiApp app, {
  String area = '',
}) async {
  if (area.trim().isNotEmpty) {
    final screen = TuiApp.resolveArea(ctx, area.trim());
    if (screen == null) {
      stderr.writeln(
        'Área desconhecida: "$area"\n'
        'Disponíveis: ${TuiApp.entries.map((e) => e.label.toLowerCase()).join(', ')}',
      );
      return 2;
    }
    if (!Term.isInteractive) {
      stderr.writeln(const TuiNotInteractive().toString());
      return 1;
    }
    Term.enterAlt();
    Term.enterRaw();
    // Telas diretas também rodam com o sync residente ativo.
    try {
      await ctx.sync.start();
    } catch (_) {}
    try {
      await screen.run();
    } finally {
      Term.restore();
    }
    return 0;
  }
  return app.run();
}

/// Histórico de 180 dias para o recomendador — mesma janela da GUI.
Future<List<TransactionModel>> _recentHistory(AppDatabase db) async {
  final all = await TransactionRepositoryImpl(db).watchAllTransactions().first;
  final since = DateTime.now().subtract(const Duration(days: 180));
  return all.where((t) => !t.date.isBefore(since)).toList();
}

/// `bestfin sync` — sincroniza uma vez e sai, sem TUI nem terminal.
/// Para scripts e cron. Exit codes: 0 ok, 1 sem identidade/erro, 2 uso.
Future<int> _runSyncOnce({
  String? dbOverride,
  List<String> extra = const [],
}) async {
  if (extra.isNotEmpty) {
    stderr.writeln('`bestfin sync` não aceita argumentos (use --db <path>).');
    return 2;
  }
  final dbPath = resolveBestfinDbPath(override: dbOverride);
  final file = File(dbPath);
  if (!file.existsSync()) {
    stderr.writeln(
      'Banco não encontrado em: $dbPath\n'
      'Execute o app gráfico uma vez para criá-lo, ou use --db <path>.',
    );
    return 1;
  }

  AppDatabase? db;
  try {
    db = _openDb(dbPath);
    final transport = NostrSyncService(db);
    final identity = await transport.loadIdentity();
    if (identity == null) {
      stderr.writeln(
        'Nenhuma identidade de sincronização configurada. '
        'Configure pelo app gráfico (Sincronização → Identidade).',
      );
      await transport.dispose();
      await db.close();
      return 1;
    }
    final service = SyncService(db, transport);
    final result = await service.syncNow();
    await transport.dispose();
    if (result.success) {
      stdout.writeln(
        'sync ok — enviados ${result.pushed}, recebidos ${result.pulled}, '
        'falhas ${result.failed}'
        '${result.deferred > 0 ? ', adiados ${result.deferred} (atualize o app)' : ''}',
      );
      await db.close();
      return 0;
    }
    stderr.writeln(result.errorMessage ?? 'Falha ao sincronizar.');
    await db.close();
    return 1;
  } on SqliteException catch (e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('locked') || msg.contains('busy')) {
      stderr.writeln('Banco em uso por outro processo (app gráfico aberto?).');
    } else {
      stderr.writeln('Erro no banco: ${e.message}');
    }
    try {
      await db?.close();
    } catch (_) {}
    return 1;
  } catch (e) {
    stderr.writeln('Erro: $e');
    try {
      await db?.close();
    } catch (_) {}
    return 1;
  }
}

void _printHelp() {
  stdout.writeln('''
BestFin — interface de terminal

Uso:
  bestfin tui [--db <caminho>]              Abre o app completo no terminal
  bestfin tui <área> [--db <caminho>]       Abre direto em uma área
  bestfin add "<frase>" [--db <caminho>]   Cria transação por linguagem natural
  bestfin add [--db <caminho>]              Assistente rápido de lançamento
  bestfin sync [--db <caminho>]             Sincroniza uma vez e sai (scripts)
  bestfin --help                            Mostra esta ajuda

Áreas disponíveis em "bestfin tui <área>":
${TuiApp.entries.map((e) => '  ${e.label.toLowerCase().padRight(22)}${e.hint}').join('\n')}

Exemplos:
  bestfin tui
  bestfin tui relatorios
  bestfin tui metas
  bestfin add "mercado 50 no cartão"
  bestfin add "recebi 3000 de salário na conta corrente"
  bestfin add --db /tmp/test.sqlite "teste 10"
  bestfin sync  # em cron: */5 * * * * bestfin sync

Sync residente: com `bestfin tui` aberto, o sincronismo é contínuo —
mudanças de outros dispositivos aparecem em segundos e tudo que você
grava é publicado automaticamente (sem "Sincronizar agora").

Opções:
  --db <path>   Caminho do bestfin.sqlite (padrão: ~/Documentos/bestfin.sqlite)

Navegação na TUI:
  ↑↓ / j k   navegar          ↵   abrir / confirmar
  1-9        seleção direta    q   voltar / sair
  Os atalhos de cada tela aparecem no rodapé.
''');
}

void _printAddHelp() {
  stdout.writeln('''
bestfin add — cria transação por linguagem natural

Uso:
  bestfin add "<frase em linguagem natural>" [--db <path>]
  bestfin add  (sem frase abre o assistente TUI)

A frase é analisada por um parser heurístico local (valor, tipo, conta, categoria).
Se o LLM on-device estiver pronto (llama-server em :8087), ele refina a extração.
Campos de baixa confiança são confirmados na TUI antes de salvar.

Exemplos:
  bestfin add "mercado 50 no cartão"
  bestfin add "recebi 2500 salário"
  bestfin add "transferência 200 da carteira para banco do brasil"
''');
}

// ── Helpers de banco ─────────────────────────────────────────────────

/// Segunda passada do `add` (task 58): consulta o recomendador estatístico
/// da GUI ([rankQuickSuggestions]/[predictCategory]) quando o parser
/// heurístico deixou conta/categoria em aberto ou de baixa confiança.
Future<ParsedTransaction> _applySuggestions(
  ParsedTransaction p,
  AppDatabase db,
) async {
  final needsCategory =
      p.type != TransactionType.transfer &&
      (p.categoryId == null ||
          p.confidences['category'] == FieldConfidence.low);
  final needsAccount =
      p.accountId == null || p.confidences['account'] == FieldConfidence.low;
  if (!needsCategory && !needsAccount) return p;

  final repo = TransactionRepositoryImpl(db);
  final history = (await repo.watchAllTransactions().first)
      .where(
        (t) =>
            t.date.isAfter(DateTime.now().subtract(const Duration(days: 180))),
      )
      .toList();
  if (history.isEmpty) return p;

  final now = DateTime.now();
  String? category;
  if (needsCategory) {
    category = predictCategory(
      history,
      type: p.type,
      description: p.description,
      now: now,
    );
  }

  String? account = p.accountId;
  if (needsAccount &&
      p.description != null &&
      p.description!.trim().isNotEmpty) {
    final needle = p.description!.trim().toLowerCase();
    for (final s in rankQuickSuggestions(
      history,
      now: now,
      typeFilter: p.type,
    )) {
      if (s.description.trim().toLowerCase() == needle) {
        account ??= s.accountId;
        category ??= s.categoryId;
        break;
      }
    }
  }

  if (category == null && account == p.accountId) return p;

  final confidences = Map<String, FieldConfidence>.of(p.confidences);
  if (category != null && confidences['category'] != FieldConfidence.high) {
    confidences['category'] = FieldConfidence.medium;
  }
  if (account != null && account != p.accountId) {
    confidences['account'] = FieldConfidence.medium;
  }

  return ParsedTransaction(
    type: p.type,
    amountCents: p.amountCents,
    accountId: account ?? p.accountId,
    toAccountId: p.toAccountId,
    categoryId: category ?? p.categoryId,
    description: p.description,
    confidences: confidences,
    rawPhrase: p.rawPhrase,
  );
}

AppDatabase _openDb(String dbPath) {
  final file = File(dbPath);
  // Garante diretório existe
  final dir = Directory(p.dirname(dbPath));
  if (!dir.existsSync()) dir.createSync(recursive: true);

  // No Linux, banco é em texto claro — não usa DbEncryption.
  // Usa busy_timeout para não travar se a GUI estiver aberta.
  final executor = NativeDatabase.createInBackground(
    file,
    setup: (db) {
      db.execute('PRAGMA journal_mode = WAL;');
      db.execute('PRAGMA busy_timeout = 2000;');
    },
  );
  return AppDatabase.forTesting(executor);
}

Future<(List<Account>, List<Category>)> _loadAccountsAndCategories(
  AppDatabase db,
) async {
  final accounts = await (db.select(
    db.accounts,
  )..where((t) => t.isArchived.equals(false))).get();
  final categories = await (db.select(
    db.categories,
  )..where((t) => t.isArchived.equals(false))).get();
  return (accounts, categories);
}

// ── Fluxos ───────────────────────────────────────────────────────────

Future<int> _runAddPhrase(String phrase, {String? dbOverride}) async {
  final dbPath = resolveBestfinDbPath(override: dbOverride);
  final file = File(dbPath);
  if (!file.existsSync()) {
    stderr.writeln(
      'Banco não encontrado em: $dbPath\n'
      'Execute o app gráfico uma vez para criá-lo, ou use --db <path>.',
    );
    return 1;
  }

  AppDatabase? db;
  try {
    db = _openDb(dbPath);
    final (accounts, categories) = await _loadAccountsAndCategories(db);

    if (accounts.isEmpty) {
      stderr.writeln(
        'Nenhuma conta cadastrada. Crie uma conta no app gráfico primeiro.',
      );
      await db.close();
      return 1;
    }

    // Parser heurístico
    final parser = NlParser(accounts: accounts, categories: categories);
    var parsed = parser.parse(phrase);

    // Refinamento opcional via LLM (só se ready)
    final llm = LlmBridge();
    final refined = await llm.refine(
      parsed,
      phrase,
      accountNames: accounts.map((a) => a.name).toList(),
      categoryNames: categories.map((c) => c.name).toList(),
    );
    if (refined != null) parsed = refined;

    // Segunda passada: recomendador estatístico (task 58) quando o parser
    // deixou conta/categoria nulas ou de baixa confiança.
    parsed = await _applySuggestions(parsed, db);

    // Validação mínima antes da TUI
    if (parsed.amountCents == null || parsed.amountCents! <= 0) {
      stderr.writeln('Não foi possível extrair o valor da frase: "$phrase"');
      stderr.writeln(
        'Tente incluir o valor (ex: "mercado 50"). Abrindo assistente...',
      );
      final wizardResult = await _runTuiWizardWithParsed(
        parsed,
        db,
        accounts,
        categories,
      );
      await db.close();
      return wizardResult;
    }

    // Sempre confirma na TUI antes de salvar (requisito da task)
    final tui = TuiRunner(
      accounts: accounts,
      categories: categories,
      historyLoader: () => _recentHistory(db!),
    );

    // Se todos os campos são high confidence, ainda mostra confirmação mas pode salvar direto
    final needsEdit =
        parsed.lowConfidenceFields.isNotEmpty ||
        parsed.accountId == null ||
        (parsed.type == TransactionType.transfer && parsed.toAccountId == null);

    ParsedTransaction? finalParsed;
    if (!needsEdit && Term.isInteractive) {
      finalParsed = await tui.confirmParsed(parsed);
    } else if (!needsEdit && !Term.isInteractive) {
      // Sem terminal (pipe/script): salva direto se completo, senão erro
      if (parsed.isComplete) {
        finalParsed = parsed;
      } else {
        stderr.writeln(
          'Campos incompletos e sem terminal para confirmação: ${parsed.lowConfidenceFields}',
        );
        await db.close();
        return 1;
      }
    } else {
      // Tem campos de baixa confiança — confirma
      if (Term.isInteractive) {
        finalParsed = await tui.confirmParsed(parsed);
      } else {
        stderr.writeln(
          'Campos de baixa confiança (${parsed.lowConfidenceFields}) exigem confirmação em terminal interativo.',
        );
        await db.close();
        return 1;
      }
    }

    if (finalParsed == null) {
      stdout.writeln('Cancelado.');
      await db.close();
      return 130;
    }

    // Valida final
    if (finalParsed.amountCents == null || finalParsed.amountCents! <= 0) {
      stderr.writeln('Valor inválido.');
      await db.close();
      return 1;
    }
    if (finalParsed.accountId == null) {
      stderr.writeln('Conta é obrigatória.');
      await db.close();
      return 1;
    }
    if (finalParsed.type == TransactionType.transfer &&
        finalParsed.toAccountId == null) {
      stderr.writeln('Transferência requer conta de destino.');
      await db.close();
      return 1;
    }

    final repo = TransactionRepositoryImpl(db);
    final id = await _createWithBusyHandling(
      repo,
      finalParsed,
      tui: Term.isInteractive ? tui : null,
    );

    if (id == null) {
      await db.close();
      return 1;
    }

    if (Term.isInteractive) {
      tui.showSuccess(id, finalParsed);
    } else {
      stdout.writeln('Transação criada: $id');
    }
    await db.close();
    return 0;
  } on SqliteException catch (e) {
    if (e.message.contains('database is locked') ||
        e.message.contains('busy')) {
      stderr.writeln(
        'Banco está em uso por outro processo (app gráfico aberto?).\n'
        'Feche o app e tente novamente, ou aguarde alguns segundos.',
      );
    } else {
      stderr.writeln('Erro no banco: $e');
    }
    try {
      await db?.close();
    } catch (_) {}
    return 1;
  } catch (e) {
    stderr.writeln('Erro: $e');
    try {
      await db?.close();
    } catch (_) {}
    return 1;
  }
}

Future<int> _runTuiWizard({String? dbOverride}) async {
  final dbPath = resolveBestfinDbPath(override: dbOverride);
  final file = File(dbPath);
  if (!file.existsSync()) {
    stderr.writeln('Banco não encontrado em: $dbPath');
    return 1;
  }
  AppDatabase? db;
  try {
    db = _openDb(dbPath);
    final (accounts, categories) = await _loadAccountsAndCategories(db);
    if (accounts.isEmpty) {
      stderr.writeln('Nenhuma conta cadastrada.');
      await db.close();
      return 1;
    }
    final tui = TuiRunner(
      accounts: accounts,
      categories: categories,
      historyLoader: () => _recentHistory(db!),
    );
    final parsed = await tui.runWizard();
    if (parsed == null) {
      stdout.writeln('Cancelado.');
      await db.close();
      return 130;
    }
    final repo = TransactionRepositoryImpl(db);
    final id = await _createWithBusyHandling(repo, parsed, tui: tui);
    if (id == null) {
      await db.close();
      return 1;
    }
    tui.showSuccess(id, parsed);
    await db.close();
    return 0;
  } catch (e) {
    stderr.writeln('Erro: $e');
    try {
      await db?.close();
    } catch (_) {}
    return 1;
  }
}

Future<int> _runTuiWizardWithParsed(
  ParsedTransaction parsed,
  AppDatabase db,
  List<Account> accounts,
  List<Category> categories,
) async {
  final tui = TuiRunner(
    accounts: accounts,
    categories: categories,
    historyLoader: () => _recentHistory(db),
  );
  final edited = await tui.runWizard(initial: parsed);
  if (edited == null) {
    stdout.writeln('Cancelado.');
    return 130;
  }
  final repo = TransactionRepositoryImpl(db);
  final id = await _createWithBusyHandling(repo, edited, tui: tui);
  if (id == null) return 1;
  tui.showSuccess(id, edited);
  return 0;
}

Future<String?> _createWithBusyHandling(
  TransactionRepositoryImpl repo,
  ParsedTransaction p, {
  TuiRunner? tui,
}) async {
  try {
    final id = await CreateTransaction(repo).call(
      date: DateTime.now(),
      description: p.description ?? 'Lançamento CLI',
      type: p.type.name,
      amount: p.amountCents!,
      categoryId: p.type == TransactionType.transfer ? null : p.categoryId,
      accountId: p.accountId!,
      toAccountId: p.toAccountId,
    );
    return id;
  } on SqliteException catch (e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('locked') || msg.contains('busy')) {
      final err =
          'Banco em uso (app gráfico aberto?). Feche o app e tente novamente.';
      if (tui != null)
        tui.showError(err);
      else
        stderr.writeln(err);
    } else {
      final err = 'Erro ao salvar: $e';
      if (tui != null)
        tui.showError(err);
      else
        stderr.writeln(err);
    }
    return null;
  } catch (e) {
    final err = 'Erro ao salvar: $e';
    if (tui != null)
      tui.showError(err);
    else
      stderr.writeln(err);
    return null;
  }
}
