import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/categories/presentation/providers/categories_provider.dart'
    show categoriesTreeProvider;
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart'
    show creditCardsStreamProvider;
import 'package:bestfin/core/widgets/entity_autocomplete.dart'
    show allEntitiesProvider;

/// Context string injected into the LLM parse prompt.
/// Riverpod memoizes this — rebuilt only when categories, accounts, credit cards, or entities change.
final aiQuickTxContextProvider = Provider<String>((ref) {
  final tree = ref.watch(categoriesTreeProvider).value ?? [];
  final accounts = ref.watch(activeAccountsProvider);
  final creditCards =
      ref
          .watch(creditCardsStreamProvider)
          .value
          ?.where((c) => !c.isArchived)
          .toList() ??
      [];
  final entities = ref.watch(allEntitiesProvider).value ?? [];

  final buf = StringBuffer();

  buf.writeln('=== CATEGORIAS DISPONÍVEIS ===');
  void writeCategory(dynamic c, {String indent = ''}) {
    if (c.isArchived) return;
    final sub = c.hasChildren ? ' (tem subcategorias)' : '';
    buf.writeln('$indent id="${c.id}" nome="${c.name}" tipo=${c.type}$sub');
    for (final child in c.children) {
      writeCategory(child, indent: '  $indent');
    }
  }

  for (final c in tree) {
    writeCategory(c);
  }

  buf.writeln('=== CONTAS DISPONÍVEIS ===');
  for (final a in accounts) {
    buf.writeln('id="${a.id}" nome="${a.name}" tipo=conta');
  }
  for (final cc in creditCards) {
    buf.writeln('id="${cc.id}" nome="${cc.name}" tipo=cartao_credito');
  }

  if (entities.isNotEmpty) {
    buf.writeln('=== ENTIDADES ANTERIORES (de quem / para quem) ===');
    final sorted = [...entities]
      ..sort((a, b) => b.useCount.compareTo(a.useCount));
    for (final e in sorted.take(40)) {
      buf.writeln('id="${e.id}" nome="${e.name}" tipo=${e.type}');
    }
  }

  return buf.toString();
});
