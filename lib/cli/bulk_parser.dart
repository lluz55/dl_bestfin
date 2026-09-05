import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/transactions/domain/models/bulk_transaction_item.dart';

/// Parser das linhas do "Lançar em lote" da TUI (task 58).
///
/// Formato por linha: `descrição; valor [; data]` — o mesmo aceito na GUI
/// do lançamento em lote (task 38). Função pura: devolve os itens válidos
/// (prontos para [TransactionRepository.createTransactionsBulk]) e, para
/// cada linha inválida, o motivo.
class BulkParseResult {
  const BulkParseResult({required this.items, required this.problems});

  final List<BulkTransactionItem> items;

  /// `"<linha>" — motivo` para cada linha descartada.
  final List<String> problems;

  int get totalCents => items.fold<int>(0, (s, i) => s + i.amount);
}

BulkParseResult parseBulkLines(
  List<String> lines, {
  required String accountId,
  String? categoryId,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final items = <BulkTransactionItem>[];
  final problems = <String>[];

  for (final line in lines) {
    final parts = line.split(';').map((s) => s.trim()).toList();
    final reason = _validate(parts);
    if (reason != null) {
      problems.add('"$line" — $reason');
      continue;
    }
    final amount = Term.parseMoney(parts[1])!;
    final date = parts.length > 2 && parts[2].isNotEmpty
        ? (Term.parseDate(parts[2].trim()) ?? reference)
        : reference;
    items.add(
      BulkTransactionItem(
        date: date,
        description: parts[0],
        type: 'expense',
        amount: amount,
        categoryId: categoryId,
        accountId: accountId,
      ),
    );
  }

  return BulkParseResult(items: items, problems: problems);
}

String? _validate(List<String> parts) {
  if (parts.isEmpty || parts[0].trim().isEmpty) return 'descrição vazia';
  if (parts.length < 2 || parts[1].trim().isEmpty) return 'falta o valor';
  final cents = Term.parseMoney(parts[1]);
  if (cents == null || cents <= 0) {
    return 'valor inválido: "${parts[1]}"';
  }
  if (parts.length > 2 && parts[2].trim().isNotEmpty) {
    if (Term.parseDate(parts[2].trim()) == null) {
      return 'data inválida: "${parts[2]}" (use dd/mm/aaaa)';
    }
  }
  return null;
}
