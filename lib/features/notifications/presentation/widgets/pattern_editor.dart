import 'package:flutter/material.dart';
import 'package:bestfin/core/utils/notification_parser.dart';
import 'package:bestfin/features/notifications/domain/models/notification_pattern.dart';
import 'package:uuid/uuid.dart';

class PatternEditor extends StatefulWidget {
  final NotificationPatternModel? existing;
  final void Function(NotificationPatternModel) onSave;

  const PatternEditor({super.key, this.existing, required this.onSave});

  @override
  State<PatternEditor> createState() => _PatternEditorState();
}

class _PatternEditorState extends State<PatternEditor> {
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _patternCtrl;
  late final TextEditingController _testInputCtrl;

  String? _testResult;
  bool _testPassed = false;

  @override
  void initState() {
    super.initState();
    _bankNameCtrl = TextEditingController(
      text: widget.existing?.bankName ?? '',
    );
    _patternCtrl = TextEditingController(
      text: widget.existing?.regexPattern ?? '',
    );
    _testInputCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _patternCtrl.dispose();
    _testInputCtrl.dispose();
    super.dispose();
  }

  void _runTest() {
    final pattern = _patternCtrl.text.trim();
    final input = _testInputCtrl.text.trim();
    if (pattern.isEmpty || input.isEmpty) {
      setState(() {
        _testResult = null;
        _testPassed = false;
      });
      return;
    }

    try {
      final parsed = NotificationParser.parseWithCustomPattern(pattern, input);
      setState(() {
        _testPassed = parsed.isValid;
        _testResult = parsed.isValid
            ? 'Valor: R\$ ${(parsed.amountInCents! / 100).toStringAsFixed(2)}'
                  '${parsed.merchant != null ? ' • ${parsed.merchant}' : ''}'
            : 'Nenhuma correspondência encontrada';
      });
    } catch (e) {
      setState(() {
        _testPassed = false;
        _testResult = 'Regex inválido: $e';
      });
    }
  }

  void _save() {
    final bankName = _bankNameCtrl.text.trim();
    final pattern = _patternCtrl.text.trim();
    if (bankName.isEmpty || pattern.isEmpty) return;

    final model = NotificationPatternModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      bankName: bankName,
      regexPattern: pattern,
      isEnabled: widget.existing?.isEnabled ?? true,
      defaultCategoryId: widget.existing?.defaultCategoryId,
      defaultAccountId: widget.existing?.defaultAccountId,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    widget.onSave(model);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'Novo padrão' : 'Editar padrão',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _bankNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome do banco',
              hintText: 'Ex: Nubank',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _patternCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Padrão regex',
              hintText: r'R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
              border: OutlineInputBorder(),
            ),
            style: tt.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          Text(
            'Testar padrão',
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testInputCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Texto de exemplo',
                    hintText: 'Cole aqui o texto da notificação',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _runTest, child: const Text('Testar')),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testPassed
                    ? cs.primaryContainer.withValues(alpha: 0.4)
                    : cs.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _testResult!,
                style: tt.bodySmall?.copyWith(
                  color: _testPassed ? cs.primary : cs.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  _save();
                  Navigator.pop(context);
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
