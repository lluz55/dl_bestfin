import 'package:bestfin/cli/tui/context.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:drift/native.dart' show SqliteException;

/// Base das telas da TUI: dá acesso ao [TuiContext] e concentra os seletores
/// e o tratamento de erro compartilhados por todas as áreas.
abstract class Screen {
  Screen(this.ctx);

  final TuiContext ctx;

  /// Título exibido no topo da tela.
  String get title;

  Future<void> run();

  // ── Lista com ações ────────────────────────────────────────────────

  /// Lista navegável com atalhos de ação no rodapé.
  ///
  /// Retorna `(tecla, índice)`: a tecla é `''` quando o usuário apertou Enter
  /// sobre um item (abrir detalhe) ou uma das [actions] quando acionou um
  /// atalho. Retorna `null` quando o usuário saiu (`q`/Esc).
  ///
  /// Diferente de [Term.select], funciona com a lista vazia — os atalhos
  /// (tipicamente "novo") continuam acessíveis, com o índice `-1`.
  (String, int)? listMenu(
    String title, {
    required List<String> items,
    String? subtitle,
    List<String>? details,
    List<TermAction> actions = const [],
    String emptyMessage = 'Nada por aqui ainda.',
  }) {
    if (!Term.isInteractive) throw const TuiNotInteractive();

    if (items.isEmpty) {
      while (true) {
        Term.clear();
        Term.header(title, subtitle: subtitle);
        Term.writeln();
        Term.writeln('  ${Term.gray}$emptyMessage${Term.reset}');
        Term.writeln();
        Term.footer([...actions, const TermAction('q', 'voltar')]);
        final key = Term.readKey();
        if (key.code == KeyCode.esc ||
            key.code == KeyCode.ctrlC ||
            key.is_('q')) {
          return null;
        }
        if (key.isChar) {
          final ch = key.char!.toLowerCase();
          if (actions.any((a) => a.key == ch)) return (ch, -1);
        }
      }
    }

    String? actionKey;
    final index = Term.select(
      title,
      items: items,
      subtitle: subtitle,
      details: details,
      initialIndex: _lastIndex[title]?.clamp(0, items.length - 1) ?? 0,
      actions: actions,
      onAction: (key, i) {
        actionKey = key;
        _lastIndex[title] = i;
        return true;
      },
    );
    if (actionKey != null) return (actionKey!, _lastIndex[title] ?? 0);
    if (index == null) return null;
    _lastIndex[title] = index;
    return ('', index);
  }

  /// Lembra a linha selecionada por tela, para que voltar de um detalhe não
  /// jogue o cursor de volta ao topo.
  static final Map<String, int> _lastIndex = {};

  // ── Seletores compartilhados ───────────────────────────────────────

  Future<Account?> pickAccount(
    String label, {
    String? excludeId,
    bool includeArchived = false,
  }) async {
    var list = await ctx.rawAccounts(includeArchived: includeArchived);
    if (excludeId != null) list = list.where((a) => a.id != excludeId).toList();
    return Term.pick<Account>(
      label,
      list,
      (a) => '${a.name}  ${Term.gray}${a.type}${Term.reset}',
      emptyMessage: 'Nenhuma conta cadastrada. Crie uma em "Contas".',
    );
  }

  /// Retorna `(escolheu, conta)` — permite escolher explicitamente "nenhuma".
  Future<(bool, Account?)> pickAccountOptional(
    String label, {
    String noneLabel = '(nenhuma)',
  }) async {
    final list = await ctx.rawAccounts();
    return Term.pickOptional<Account>(
      label,
      list,
      (a) => '${a.name}  ${Term.gray}${a.type}${Term.reset}',
      noneLabel: noneLabel,
    );
  }

  Future<(bool, Category?)> pickCategoryOptional(
    String label, {
    String? type,
    String noneLabel = '(sem categoria)',
  }) async {
    final list = await ctx.rawCategories(type: type);
    return Term.pickOptional<Category>(
      label,
      list,
      (c) => '${c.name}  ${Term.gray}${c.type}${Term.reset}',
      noneLabel: noneLabel,
    );
  }

  /// Seleção múltipla com marcação (espaço alterna, Enter confirma).
  /// Retorna os **índices** marcados, ou `null` se cancelado.
  List<int>? pickMulti<T>(
    String label,
    List<T> items,
    String Function(T) render, {
    Set<int>? initial,
  }) {
    if (items.isEmpty) {
      Term.alert(label, 'Nenhum item disponível.');
      return null;
    }
    final selected = <int>{...?initial};
    var index = 0;
    while (true) {
      Term.clear();
      Term.header(label, subtitle: '${selected.length} selecionado(s)');
      final viewport = Term.viewportFor(Term.height - 8, items.length);
      var offset = 0;
      if (index >= viewport) offset = index - viewport + 1;
      for (var i = offset; i < offset + viewport && i < items.length; i++) {
        final mark = selected.contains(i)
            ? '${Term.green}[x]${Term.reset}'
            : '[ ]';
        final cursor = i == index ? '${Term.cyan}❯ ${Term.reset}' : '  ';
        Term.writeln(
          '$cursor$mark ${Term.truncate(render(items[i]), Term.width - 8)}',
        );
      }
      Term.footer(const [
        TermAction('↑↓', 'navegar'),
        TermAction('espaço', 'marcar'),
        TermAction('↵', 'confirmar'),
        TermAction('q', 'cancelar'),
      ]);

      final key = Term.readKey();
      if (key.code == KeyCode.up) {
        index = index == 0 ? items.length - 1 : index - 1;
      } else if (key.code == KeyCode.down) {
        index = (index + 1) % items.length;
      } else if (key.code == KeyCode.enter) {
        return selected.toList()..sort();
      } else if (key.code == KeyCode.esc ||
          key.code == KeyCode.ctrlC ||
          key.is_('q')) {
        return null;
      } else if (key.isChar && key.char == ' ') {
        if (!selected.remove(index)) selected.add(index);
      }
    }
  }

  // ── Execução protegida ─────────────────────────────────────────────

  /// Executa [action] traduzindo erros conhecidos em mensagens claras.
  /// Retorna `true` se concluiu sem erro.
  Future<bool> guard(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    try {
      await action();
      if (successMessage != null) {
        Term.success(successMessage);
        Term.pause();
      }
      return true;
    } catch (e) {
      Term.error(describeError(e));
      Term.pause();
      return false;
    }
  }

  /// Mensagem legível para os erros que a TUI pode encontrar.
  static String describeError(Object e) {
    if (e is SqliteException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('locked') || msg.contains('busy')) {
        return 'Banco em uso por outro processo (app gráfico aberto?). '
            'Feche o app e tente novamente.';
      }
      return 'Erro no banco: ${e.message}';
    }
    if (e is TuiNotInteractive) return e.toString();
    // Erros vindos do isolate do drift chegam embrulhados — a mensagem
    // original ainda carrega o motivo real do lock.
    final text = e.toString().toLowerCase();
    if (text.contains('database is locked') || text.contains('sqlite_busy')) {
      return 'Banco em uso por outro processo (app gráfico aberto?). '
          'Feche o app e tente novamente.';
    }
    return e.toString();
  }
}
