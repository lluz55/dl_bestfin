import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/features/pdf_import/domain/models/pdf_parsed_transaction.dart';

class ParsedTransactionTile extends StatefulWidget {
  final PdfParsedTransaction transaction;
  final int index;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onDescriptionChanged;

  const ParsedTransactionTile({
    super.key,
    required this.transaction,
    required this.index,
    required this.onToggle,
    required this.onDescriptionChanged,
  });

  @override
  State<ParsedTransactionTile> createState() => _ParsedTransactionTileState();
}

class _ParsedTransactionTileState extends State<ParsedTransactionTile> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.transaction.description);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tx = widget.transaction;
    final isIncome = tx.type == 'income';
    final amountColor = isIncome ? Colors.green.shade600 : cs.error;
    final amountFormatted = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    ).format(tx.amountCents / 100);

    return AnimatedOpacity(
      opacity: tx.selected ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: Card(
        elevation: 0,
        color: tx.selected
            ? cs.surfaceContainerLow
            : cs.surfaceContainerLowest,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: tx.selected,
                onChanged: (v) => widget.onToggle(v ?? false),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(top: 2, right: 12),
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIncome
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: amountColor,
                  size: 18,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _controller,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                      onChanged: widget.onDescriptionChanged,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM/yyyy').format(tx.date),
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                amountFormatted,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
