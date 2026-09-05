import 'dart:io';

import 'package:bestfin/cli/bulk_parser.dart';
import 'package:bestfin/cli/nl_parser.dart';
import 'package:bestfin/cli/parse_result.dart';
import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/constants/transaction_types.dart';
import 'package:bestfin/core/database/app_database.dart' as db;
import 'package:bestfin/features/transactions/domain/models/quick_suggestion.dart';
import 'package:bestfin/features/transactions/domain/models/split_entry.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/domain/models/transaction_delete_context.dart';
import 'package:bestfin/features/transactions/domain/usecases/get_quick_suggestions.dart';

/// Filtros ativos da listagem de transações.
class _Filters {
  _Filters();

  String? type;
  String? accountId;
  String? categoryId;
  DateTime? start;
  DateTime? end;
  bool? isCompleted;

  bool get isEmpty =>
      type == null &&
      accountId == null &&
      categoryId == null &&
      start == null &&
      end == null &&
      isCompleted == null;

  String describe(
    Map<String, String> accountNames,
    Map<String, String> catNames,
  ) {
    if (isEmpty) return 'sem filtros';
    final parts = <String>[];
    if (type != null) parts.add(TransactionType.fromString(type!).label);
    if (accountId != null) {
      parts.add('conta: ${accountNames[accountId] ?? accountId}');
    }
    if (categoryId != null) {
      parts.add('categoria: ${catNames[categoryId] ?? categoryId}');
    }
    if (start != null || end != null) {
      parts.add(
        '${start == null ? '…' : Term.formatDate(start!)}'
        ' → ${end == null ? '…' : Term.formatDate(end!)}',
      );
    }
    if (isCompleted != null) {
      parts.add(isCompleted! ? 'concluídas' : 'pendentes');
    }
    return parts.join(' • ');
  }
}

/// Transações: listagem filtrável, criação (formulário ou frase), edição,
/// baixa de pendentes, confirmação de sugestões e exclusão.
class TransactionsScreen extends Screen {
  TransactionsScreen(super.ctx);

  @override
  String get title => 'Transações';

  final _filters = _Filters();

  @override
  Future<void> run() async {
    while (true) {
      final accounts = await ctx.rawAccounts();
      final categories = await ctx.rawCategories();
      final accountNames = {for (final a in accounts) a.id: a.name};
      final catNames = {for (final c in categories) c.id: c.name};

      final list = await ctx.transactions
          .watchTransactionsWithFilters(
            type: _filters.type,
            accountIds: _filters.accountId == null
                ? null
                : [_filters.accountId!],
            categoryId: _filters.categoryId,
            startDate: _filters.start,
            endDate: _filters.end,
            isCompleted: _filters.isCompleted,
          )
          .first;

      final income = list
          .where((t) => t.type == TransactionType.income)
          .fold<int>(0, (s, t) => s + t.amount.abs());
      final expense = list
          .where((t) => t.type == TransactionType.expense)
          .fold<int>(0, (s, t) => s + t.amount.abs());

      final items = list.map((t) => _renderRow(t, accountNames)).toList();

      final choice = listMenu(
        title,
        items: items,
        subtitle:
            '${list.length} lançamento(s) • '
            '${Term.c('+${Term.formatMoney(income)}', Term.green)} '
            '${Term.c('-${Term.formatMoney(expense)}', Term.red)} • '
            '${_filters.describe(accountNames, catNames)}',
        emptyMessage:
            'Nenhum lançamento com os filtros atuais. "n" cria um, "f" ajusta os filtros.',
        actions: const [
          TermAction('n', 'novo'),
          TermAction('l', 'frase'),
          TermAction('b', 'lote'),
          TermAction('f', 'filtros'),
          TermAction('x', 'limpar filtros'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final tx = i >= 0 && i < list.length ? list[i] : null;
      switch (key) {
        case 'n':
          await _create();
        case 'l':
          await _createFromPhrase();
        case 'b':
          await _bulk();
        case 'f':
          await _editFilters();
        case 'x':
          _filters
            ..type = null
            ..accountId = null
            ..categoryId = null
            ..start = null
            ..end = null
            ..isCompleted = null;
        case '':
          if (tx != null) await _detail(tx, accountNames, catNames);
      }
    }
  }

  String _renderRow(TransactionModel t, Map<String, String> accountNames) {
    final sign = switch (t.type) {
      TransactionType.income => Term.c(
        '+${Term.formatMoney(t.amount.abs())}',
        Term.green,
      ),
      TransactionType.expense => Term.c(
        '-${Term.formatMoney(t.amount.abs())}',
        Term.red,
      ),
      TransactionType.transfer => Term.c(
        '↔ ${Term.formatMoney(t.amount.abs())}',
        Term.blue,
      ),
    };
    final flags = StringBuffer();
    if (!t.isCompleted) flags.write(' ${Term.c('pendente', Term.yellow)}');
    if (!t.isConfirmed) flags.write(' ${Term.c('sugestão', Term.magenta)}');
    if (t.isSplit) flags.write(' ${Term.c('₊ dividido', Term.cyan)}');
    if (t.installmentNumber != null)
      flags.write(' ${Term.gray}#${t.installmentNumber}${Term.reset}');
    if (t.recurringRuleId != null) flags.write(' ${Term.gray}↻${Term.reset}');

    return '${Term.formatDate(t.date)}  '
        '${Term.pad(t.description, 30)} '
        '${Term.padLeft(sign, 18)}  '
        '${Term.gray}${Term.pad(accountNames[t.accountId] ?? '—', 16)}${Term.reset}'
        '$flags';
  }

  // ── Detalhe / ações sobre um lançamento ────────────────────────────

  Future<void> _detail(
    TransactionModel t,
    Map<String, String> accountNames,
    Map<String, String> catNames,
  ) async {
    while (true) {
      final options = <String>[
        'Editar',
        if (!t.isCompleted) 'Marcar como paga',
        if (!t.isConfirmed) 'Confirmar sugestão',
        'Excluir',
        'Ver detalhes completos',
      ];

      final subtitle =
          '${t.type.label} • ${Term.formatMoney(t.amount.abs())} • '
          '${Term.formatDate(t.date)}';
      final choice = Term.select(
        t.description,
        items: options,
        subtitle: subtitle,
      );
      if (choice == null) return;

      switch (options[choice]) {
        case 'Editar':
          final changed = await _edit(t);
          if (changed) return;
        case 'Marcar como paga':
          await guard(
            () => ctx.transactions.markAsPaid(t.id),
            successMessage: 'Lançamento marcado como pago.',
          );
          return;
        case 'Confirmar sugestão':
          await guard(
            () => ctx.transactions.confirmSuggestion(t.id),
            successMessage: 'Sugestão confirmada.',
          );
          return;
        case 'Excluir':
          final deleted = await _delete(t);
          if (deleted) return;
        case 'Ver detalhes completos':
          _showDetails(t, accountNames, catNames);
      }
    }
  }

  void _showDetails(
    TransactionModel t,
    Map<String, String> accountNames,
    Map<String, String> catNames,
  ) {
    final lines = <String>[
      '',
      '  ${Term.bold}${t.description}${Term.reset}',
      '',
      '  Tipo:          ${t.type.label}',
      '  Valor:         ${Term.formatMoney(t.amount.abs())}',
      '  Data:          ${Term.formatDate(t.date)}',
      '  Conta:         ${accountNames[t.accountId] ?? '—'}',
      if (t.toAccountId != null)
        '  Destino:       ${accountNames[t.toAccountId] ?? '—'}',
      '  Categoria:     ${t.categoryId == null ? '—' : catNames[t.categoryId] ?? '—'}',
      '  Concluída:     ${t.isCompleted ? 'sim' : 'não'}',
      '  Confirmada:    ${t.isConfirmed ? 'sim' : 'não'}',
      if (t.notes != null && t.notes!.isNotEmpty) '  Observações:   ${t.notes}',
      if (t.installmentPlanId != null)
        '  Parcelamento:  parcela ${t.installmentNumber ?? '?'}',
      if (t.recurringRuleId != null) '  Recorrência:   ${t.recurringRuleId}',
      if (t.creditCardId != null) '  Cartão:        ${t.creditCardId}',
      if (t.goalId != null) '  Meta:          ${t.goalId}',
      '  Origem:        ${t.source ?? 'manual'}',
      '  ID:            ${Term.gray}${t.id}${Term.reset}',
      '',
      '  ${Term.bold}Lançamentos (partida dobrada)${Term.reset}',
      ...t.entries.map(
        (e) =>
            '    ${Term.pad(accountNames[e.accountId] ?? e.accountId, 24)} '
            '${Term.padLeft(Term.formatMoneyColored(e.amount, sign: true), 16)}',
      ),
      if (t.splits.isNotEmpty) ...[
        '',
        '  ${Term.bold}Divisão por categoria${Term.reset}',
        ...t.splits.map(
          (s) =>
              '    ${Term.pad(s.categoryName ?? '(sem categoria)', 24)} '
              '${Term.padLeft(Term.formatMoney(s.amount), 16)}'
              '${s.description != null ? '  ${Term.gray}${s.description}${Term.reset}' : ''}',
        ),
      ],
      '',
    ];
    Term.pager('Detalhes — ${t.description}', lines);
  }

  // ── Criação ────────────────────────────────────────────────────────

  Future<void> _create() async {
    final form = await _form();
    if (form == null) return;
    await guard(
      () => ctx.transactions.createTransaction(
        date: form.date,
        description: form.description,
        type: form.type.name,
        amount: form.amount,
        categoryId: form.categoryId,
        accountId: form.accountId,
        toAccountId: form.toAccountId,
        notes: form.notes,
        isCompleted: form.isCompleted,
        splits: form.splits,
      ),
      successMessage: 'Lançamento criado.',
    );
  }

  /// Criação por frase em linguagem natural, reaproveitando o parser do
  /// `bestfin add` — os campos extraídos entram pré-preenchidos no formulário.
  Future<void> _createFromPhrase() async {
    Term.clear();
    Term.header('Novo lançamento por frase');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}ex: "mercado 50 no cartão", '
      '"recebi 3000 de salário na conta corrente"${Term.reset}',
    );
    Term.writeln();
    final phrase = Term.input('Frase:', allowEmpty: false);
    if (phrase == null || phrase.trim().isEmpty) return;

    final accounts = await ctx.rawAccounts();
    final categories = await ctx.rawCategories();
    final parsed = NlParser(
      accounts: accounts,
      categories: categories,
    ).parse(phrase.trim());

    final form = await _form(initial: parsed);
    if (form == null) return;
    await guard(
      () => ctx.transactions.createTransaction(
        date: form.date,
        description: form.description,
        type: form.type.name,
        amount: form.amount,
        categoryId: form.categoryId,
        accountId: form.accountId,
        toAccountId: form.toAccountId,
        notes: form.notes,
        isCompleted: form.isCompleted,
        splits: form.splits,
      ),
      successMessage: 'Lançamento criado.',
    );
  }

  Future<bool> _edit(TransactionModel t) async {
    final form = await _form(existing: t);
    if (form == null) return false;
    return guard(
      () => ctx.transactions.updateTransaction(
        id: t.id,
        date: form.date,
        description: form.description,
        type: form.type.name,
        amount: form.amount,
        categoryId: form.categoryId,
        accountId: form.accountId,
        toAccountId: form.toAccountId,
        notes: form.notes,
        isCompleted: form.isCompleted,
        // Passa [] para limpar divisões existentes; null mantém as atuais.
        splits: form.splitTouched
            ? (form.splits ?? const <SplitEntry>[])
            : null,
      ),
      successMessage: 'Lançamento atualizado.',
    );
  }

  /// Formulário de lançamento — usado na criação e na edição.
  ///
  /// Na criação, a descrição ganha autocomplete do histórico e o par
  /// descrição/tipo sugere conta/categoria/valor pelo recomendador
  /// estatístico da GUI (task 58), aceitos com ↵.
  Future<_TxForm?> _form({
    TransactionModel? existing,
    ParsedTransaction? initial,
  }) async {
    final heading = existing == null ? 'Novo lançamento' : 'Editar lançamento';
    Term.clear();
    Term.header(heading);
    Term.writeln();

    final initialType =
        existing?.type ?? initial?.type ?? TransactionType.expense;
    final type = Term.pick<TransactionType>(
      'Tipo',
      TransactionType.values,
      (t) => t.label,
      initialIndex: TransactionType.values.indexOf(initialType),
    );
    if (type == null) return null;

    final description = await _descriptionWithSuggestions(
      existing: existing,
      initial: initial,
      type: type,
    );
    if (description == null || description.trim().isEmpty) return null;

    // Sugestão estatística para a descrição digitada — conta/categoria/valor.
    final suggestion = existing == null
        ? await _matchSuggestion(description, type)
        : null;
    if (suggestion != null) {
      final accName = await _accountNameOf(suggestion.accountId);
      final catName = suggestion.categoryId == null
          ? null
          : await _categoryNameOf(suggestion.categoryId!);
      Term.writeln();
      Term.writeln(
        '  ${Term.cyan} Sugestão do histórico:${Term.reset} '
        'conta $accName, '
        'valor ${Term.formatMoney(suggestion.amount.abs())}'
        '${catName != null ? ', categoria $catName' : ''}',
      );
      Term.writeln(
        '  ${Term.gray}↵ aceita a sugestão de valor — digite outro valor para sobrescrever${Term.reset}',
      );
    }

    final amount = Term.inputMoney(
      'Valor',
      initial: existing?.amount.abs() ?? suggestion?.amount.abs(),
    );
    if (amount == null || amount <= 0) return null;

    final date = Term.inputDate(
      'Data',
      initial: existing?.date ?? DateTime.now(),
    );
    if (date == null) return null;

    final accounts = await ctx.rawAccounts();
    final preAccountId =
        existing?.accountId ?? suggestion?.accountId ?? initial?.accountId;
    final preIndex = accounts.indexWhere((a) => a.id == preAccountId);
    final account = Term.pick<db.Account>(
      type == TransactionType.transfer ? 'Conta de origem' : 'Conta',
      accounts,
      (a) => a.name,
      initialIndex: preIndex < 0 ? 0 : preIndex,
      emptyMessage: 'Nenhuma conta cadastrada. Crie uma em "Contas".',
    );
    if (account == null) return null;

    String? toAccountId;
    if (type == TransactionType.transfer) {
      final dest = await pickAccount('Conta de destino', excludeId: account.id);
      if (dest == null) return null;
      toAccountId = dest.id;
    }

    String? categoryId;
    List<SplitEntry>? splits;
    var splitTouched = false;
    if (type != TransactionType.transfer) {
      final preCategoryId =
          existing?.categoryId ?? suggestion?.categoryId ?? initial?.categoryId;
      categoryId = await _pickCategoryBy(
        type: type.name,
        initialId: preCategoryId,
      );
      if (categoryId == null && preCategoryId != null) return null;

      final wantsSplit = Term.confirm(
        'Dividir em várias categorias?',
        defaultYes: existing?.isSplit ?? false,
      );
      if (wantsSplit) {
        final edited = await _splitEditor(
          total: amount,
          initial: existing?.splits ?? const [],
          initialCategoryId: categoryId,
        );
        if (edited == null) return null;
        splits = edited;
        splitTouched = true;
      }
    }

    final notes = Term.input(
      'Observações (opcional):',
      initial: existing?.notes ?? '',
    );
    if (notes == null) return null;

    final isCompleted = Term.confirm(
      'Lançamento já efetivado?',
      defaultYes: existing?.isCompleted ?? true,
    );

    return _TxForm(
      type: type,
      amount: amount,
      description: description.trim(),
      date: date,
      accountId: account.id,
      toAccountId: toAccountId,
      // Com split, a categoria fica nas partes (mesma regra da GUI).
      categoryId: (splits != null && splits.isNotEmpty) ? null : categoryId,
      notes: notes.trim().isEmpty ? null : notes.trim(),
      isCompleted: isCompleted,
      splits: splits,
      splitTouched: splitTouched,
    );
  }

  /// Descrição com autocomplete do histórico: sugestões filtradas pelo texto
  /// parcial, aceitas com ↵ (digitando, sobrescreve).
  Future<String?> _descriptionWithSuggestions({
    TransactionModel? existing,
    ParsedTransaction? initial,
    required TransactionType type,
  }) async {
    final typed = Term.input(
      'Descrição:',
      initial: existing?.description ?? initial?.description ?? '',
      allowEmpty: false,
    );
    if (typed == null || typed.trim().isEmpty) return null;
    final text = typed.trim();
    if (existing != null) return text;

    try {
      final recents = await ctx.transactions.getRecentDescriptions(
        query: text,
        type: type.name,
      );
      final candidates = recents
          .where((d) => d.toLowerCase() != text.toLowerCase())
          .toList();
      if (candidates.isEmpty) return text;

      final labels = ['manter "$text"', ...candidates];
      final i = Term.select(
        'Descrições parecidas no histórico',
        items: labels,
        subtitle: '↵ escolhe • "manter" usa o que você digitou',
      );
      if (i == null || i == 0) return text;
      return candidates[i - 1];
    } catch (_) {
      return text;
    }
  }

  /// Encontra, no histórico, a sugestão cuja descrição casa com o texto.
  Future<QuickSuggestion?> _matchSuggestion(
    String description,
    TransactionType type,
  ) async {
    try {
      final history = await ctx.recentHistory();
      final suggestions = rankQuickSuggestions(
        history,
        now: DateTime.now(),
        typeFilter: type,
      );
      final needle = description.trim().toLowerCase();
      for (final s in suggestions) {
        if (s.description.trim().toLowerCase() == needle) return s;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _pickCategoryBy({
    required String type,
    required String? initialId,
  }) async {
    final list = await ctx.rawCategories(type: type);
    final labels = [
      if (initialId == null) '(sem categoria)' else null,
      ...list.map((c) => c.name),
      if (initialId != null) '(sem categoria)',
    ].whereType<String>().toList();
    final i = Term.select('Categoria', items: labels);
    if (i == null) return null;
    // Com categoria prévia, "(sem categoria)" é a última opção.
    if (initialId == null) {
      return i == 0 ? null : list[i - 1].id;
    }
    if (i == labels.length - 1) return null;
    return list[i].id;
  }

  Future<String> _accountNameOf(String id) async {
    final list = await ctx.rawAccounts(includeArchived: true);
    for (final a in list) {
      if (a.id == id) return a.name;
    }
    return id;
  }

  Future<String> _categoryNameOf(String id) async {
    final list = await ctx.rawCategories(includeArchived: true);
    for (final c in list) {
      if (c.id == id) return c.name;
    }
    return id;
  }

  /// Editor de divisão por categoria (mesma regra da GUI, task 31):
  /// as partes precisam somar exatamente o total antes de salvar.
  Future<List<SplitEntry>?> _splitEditor({
    required int total,
    required List<SplitEntry> initial,
    String? initialCategoryId,
  }) async {
    final parts = <SplitEntry>[...initial];
    while (true) {
      final sum = parts.fold<int>(0, (s, p) => s + p.amount);
      final remaining = total - sum;

      Term.clear();
      Term.header('Dividir em categorias');
      Term.writeln();
      if (parts.isEmpty) {
        Term.writeln('  ${Term.gray}Nenhuma parte adicionada.${Term.reset}');
      }
      for (var i = 0; i < parts.length; i++) {
        final p = parts[i];
        Term.writeln(
          '  ${i + 1}. ${Term.pad(p.categoryName ?? '(sem categoria)', 24)} '
          '${Term.padLeft(Term.formatMoney(p.amount), 14)}'
          '${p.description != null ? '  ${Term.gray}${p.description}${Term.reset}' : ''}',
        );
      }
      Term.writeln();
      final color = remaining == 0 ? Term.green : Term.red;
      Term.writeln(
        '  Total ${Term.formatMoney(total)} • distribuído '
        '${Term.c(Term.formatMoney(sum), color)} • '
        '${Term.c('falta ${Term.formatMoney(remaining)}', color)}',
      );
      Term.writeln();

      final choice = Term.select(
        'Partes',
        items: [
          'Adicionar parte',
          if (parts.isNotEmpty) 'Remover última parte',
          if (remaining == 0 && parts.isNotEmpty) 'Concluir divisão',
        ],
      );
      if (choice == null) return null;
      final item = choice == 0
          ? 'add'
          : choice == 1
          ? (parts.isNotEmpty ? 'remove' : 'add')
          : 'done';

      switch (item) {
        case 'add':
          final (chose, cat) = await pickCategoryOptional(
            'Categoria da parte',
            noneLabel: '(sem categoria)',
          );
          if (!chose) return null;
          final value = Term.inputMoney('Valor da parte');
          if (value == null || value <= 0) continue;
          if (value > remaining) {
            Term.error(
              'A parte ultrapassa o que falta (${Term.formatMoney(remaining)}).',
            );
            Term.pause();
            continue;
          }
          final desc = Term.input('Descrição da parte (opcional):');
          if (desc == null) return null;
          parts.add(
            SplitEntry(
              categoryId: cat?.id,
              categoryName: cat?.name,
              amount: value,
              description: desc.trim().isEmpty ? null : desc.trim(),
            ),
          );
        case 'remove':
          if (parts.isNotEmpty) parts.removeLast();
        case 'done':
          return parts;
      }
    }
  }

  // ── Entrada em lote (task 58) ───────────────────────────────────────

  /// Lançar vários de uma vez: cola linhas `descrição; valor [; data]`,
  /// revisa numa tabela e salva por [CreateTransactionsBulk] — atômico e
  /// com enfileiramento de sync pelo mesmo caminho da importação de PDF.
  Future<void> _bulk() async {
    Term.clear();
    Term.header('Lançar em lote');
    Term.writeln();
    Term.writeln(
      '  Uma linha por lançamento, no formato ${Term.bold}descrição; valor[; data]${Term.reset}',
    );
    Term.writeln(
      '  ${Term.gray}ex: "Mercado; 152,30" • "Aluguel; 1200; 05/08"${Term.reset}',
    );
    Term.writeln(
      '  ${Term.gray}Cole tudo de uma vez e finalize com uma linha vazia.${Term.reset}',
    );
    Term.writeln();

    // Leitura em modo linha: permite colar o bloco inteiro de uma vez.
    final lines = <String>[];
    if (!Term.isInteractive) {
      Term.error('O lote precisa de terminal interativo.');
      Term.pause();
      return;
    }
    Term.exitRaw();
    while (true) {
      stdout.write('> ');
      final line = stdin.readLineSync();
      if (line == null || line.trim().isEmpty) break;
      lines.add(line.trim());
    }
    Term.enterRaw();
    Term.invalidateSize();
    if (lines.isEmpty) return;

    final categories = await ctx.rawCategories(type: 'expense');
    db.Category? category;
    if (categories.isNotEmpty) {
      final (chose, cat) = await pickCategoryOptional(
        'Categoria comum do lote',
        type: 'expense',
      );
      if (!chose) return;
      category = cat;
    }
    final account = await pickAccount('Conta do lote');
    if (account == null) return;

    final now = DateTime.now();
    final parsed = parseBulkLines(
      lines,
      accountId: account.id,
      categoryId: category?.id,
      now: now,
    );
    final items = parsed.items;
    final problems = parsed.problems;

    if (items.isEmpty) {
      Term.error('Nenhuma linha válida.');
      for (final p in problems) {
        Term.writeln('  ${Term.red}✗${Term.reset} $p');
      }
      Term.pause();
      return;
    }

    // Revisão em tabela antes de salvar.
    Term.clear();
    Term.header('Revisar lote — ${items.length} lançamento(s)');
    Term.writeln();
    for (final l in Term.table(
      ['Data', 'Descrição', 'Valor'],
      [
        ...items.map(
          (i) => [
            Term.formatDate(i.date),
            i.description,
            Term.formatMoney(i.amount),
          ],
        ),
        [
          '',
          '${Term.bold}Total${Term.reset}',
          '${Term.bold}${Term.formatMoney(items.fold<int>(0, (s, i) => s + i.amount))}${Term.reset}',
        ],
      ],
      aligns: ['l', 'l', 'r'],
    )) {
      Term.writeln(l);
    }
    Term.writeln();
    if (problems.isNotEmpty) {
      Term.warn('${problems.length} linha(s) ignorada(s):');
      for (final p in problems) {
        Term.writeln('  ${Term.red}✗${Term.reset} $p');
      }
      Term.writeln();
    }
    if (!Term.confirm(
      'Salvar os ${items.length} lançamento(s)?',
      defaultYes: true,
    )) {
      return;
    }

    await guard(() async {
      final ids = await ctx.transactions.createTransactionsBulk(items);
      Term.success(
        '${ids.length} lançamento(s) criado(s) — sync enfileirada '
        'no mesmo caminho da importação de PDF.',
      );
    });
    Term.pause();
  }

  // ── Exclusão (com as variantes de parcelamento/recorrência) ────────

  Future<bool> _delete(TransactionModel t) async {
    final context = await ctx.transactions.getDeleteContext(t.id);

    switch (context.deleteCase) {
      case TransactionDeleteCase.regular:
        if (!Term.confirm('Excluir "${t.description}"?')) return false;
        return guard(
          () => ctx.transactions.deleteTransaction(t.id),
          successMessage: 'Lançamento excluído.',
        );

      case TransactionDeleteCase.installment:
        final options = [
          'Apenas esta parcela',
          'Esta e as próximas',
          'Todo o parcelamento '
              '(${context.totalInstallments ?? '?'} parcelas)',
        ];
        final choice = Term.select(
          'Excluir parcela ${context.installmentNumber ?? '?'}',
          items: options,
          subtitle: t.description,
        );
        if (choice == null) return false;
        final planId = context.installmentPlanId!;
        return guard(() async {
          switch (choice) {
            case 0:
              await ctx.transactions.deleteInstallmentSingle(t.id);
            case 1:
              await ctx.transactions.deleteInstallmentFromHere(t.id, planId);
            case 2:
              await ctx.transactions.deleteInstallmentAll(planId);
          }
        }, successMessage: 'Parcelas excluídas.');

      case TransactionDeleteCase.recurringBase:
        final options = [
          'Este e os lançamentos futuros',
          'Este e todos os lançamentos da recorrência',
        ];
        final choice = Term.select(
          'Excluir lançamento recorrente',
          items: options,
          subtitle: t.description,
        );
        if (choice == null) return false;
        final ruleId = context.recurringRuleId!;
        return guard(() async {
          if (choice == 0) {
            await ctx.transactions.deleteRecurringBaseAndFuture(t.id, ruleId);
          } else {
            await ctx.transactions.deleteRecurringBaseAndAll(t.id, ruleId);
          }
        }, successMessage: 'Recorrência excluída.');

      case TransactionDeleteCase.recurringClone:
        final options = ['Apenas este', 'Este e os futuros'];
        final choice = Term.select(
          'Excluir ocorrência da recorrência',
          items: options,
          subtitle: t.description,
        );
        if (choice == null) return false;
        return guard(() async {
          if (choice == 0) {
            await ctx.transactions.deleteTransaction(t.id);
          } else {
            await ctx.transactions.deleteRecurringCloneAndFuture(
              t.id,
              context.recurringRuleId!,
              t.date,
            );
          }
        }, successMessage: 'Lançamentos excluídos.');
    }
  }

  // ── Filtros ────────────────────────────────────────────────────────

  Future<void> _editFilters() async {
    while (true) {
      final options = [
        'Tipo: ${_filters.type == null ? 'todos' : TransactionType.fromString(_filters.type!).label}',
        'Conta: ${_filters.accountId == null ? 'todas' : _filters.accountId}',
        'Categoria: ${_filters.categoryId == null ? 'todas' : _filters.categoryId}',
        'Período: ${_filters.start == null && _filters.end == null ? 'todo' : '${_filters.start == null ? '…' : Term.formatDate(_filters.start!)} → ${_filters.end == null ? '…' : Term.formatDate(_filters.end!)}'}',
        'Situação: ${_filters.isCompleted == null ? 'todas' : (_filters.isCompleted! ? 'concluídas' : 'pendentes')}',
        'Limpar todos os filtros',
      ];
      final choice = Term.select('Filtros', items: options);
      if (choice == null) return;

      switch (choice) {
        case 0:
          final labels = [
            'Todos',
            ...TransactionType.values.map((t) => t.label),
          ];
          final i = Term.select('Tipo', items: labels);
          if (i != null) {
            _filters.type = i == 0 ? null : TransactionType.values[i - 1].name;
          }
        case 1:
          final (chose, acc) = await pickAccountOptional(
            'Conta',
            noneLabel: '(todas)',
          );
          if (chose) _filters.accountId = acc?.id;
        case 2:
          final (chose, cat) = await pickCategoryOptional(
            'Categoria',
            noneLabel: '(todas)',
          );
          if (chose) _filters.categoryId = cat?.id;
        case 3:
          await _pickPeriod();
        case 4:
          final i = Term.select(
            'Situação',
            items: const ['Todas', 'Concluídas', 'Pendentes'],
          );
          if (i != null) {
            _filters.isCompleted = switch (i) {
              1 => true,
              2 => false,
              _ => null,
            };
          }
        case 5:
          _filters
            ..type = null
            ..accountId = null
            ..categoryId = null
            ..start = null
            ..end = null
            ..isCompleted = null;
          return;
      }
    }
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final options = [
      'Mês atual',
      'Mês anterior',
      'Últimos 30 dias',
      'Ano atual',
      'Intervalo personalizado',
      'Todo o histórico',
    ];
    final i = Term.select('Período', items: options);
    if (i == null) return;
    switch (i) {
      case 0:
        _filters.start = DateTime(now.year, now.month, 1);
        _filters.end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case 1:
        _filters.start = DateTime(now.year, now.month - 1, 1);
        _filters.end = DateTime(now.year, now.month, 0, 23, 59, 59);
      case 2:
        _filters.start = now.subtract(const Duration(days: 30));
        _filters.end = now;
      case 3:
        _filters.start = DateTime(now.year, 1, 1);
        _filters.end = DateTime(now.year, 12, 31, 23, 59, 59);
      case 4:
        final start = Term.inputDate('Início', initial: _filters.start ?? now);
        if (start == null) return;
        final end = Term.inputDate('Fim', initial: _filters.end ?? now);
        if (end == null) return;
        _filters.start = start;
        _filters.end = DateTime(end.year, end.month, end.day, 23, 59, 59);
      case 5:
        _filters.start = null;
        _filters.end = null;
    }
  }
}

class _TxForm {
  _TxForm({
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.notes,
    required this.isCompleted,
    this.splits,
    this.splitTouched = false,
  });

  final TransactionType type;
  final int amount;
  final String description;
  final DateTime date;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? notes;
  final bool isCompleted;

  /// Divisão por categoria (task 31) — null = sem split.
  final List<SplitEntry>? splits;

  /// true quando o usuário passou pelo editor de split (permite limpar as
  /// partes existentes na edição passando lista vazia).
  final bool splitTouched;
}
