import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/features/dashboard/presentation/providers/home_widgets_provider.dart';

void showHomeWidgetsEditSheet(BuildContext context) {
  showAdaptiveModal<void>(
    context: context,
    builder: (_) => const HomeWidgetsEditSheet(),
  );
}

class HomeWidgetsEditSheet extends ConsumerStatefulWidget {
  const HomeWidgetsEditSheet({super.key});

  @override
  ConsumerState<HomeWidgetsEditSheet> createState() =>
      _HomeWidgetsEditSheetState();
}

class _HomeWidgetsEditSheetState extends ConsumerState<HomeWidgetsEditSheet> {
  late List<HomeWidgetId> _visible;
  late List<HomeWidgetId> _hidden;

  @override
  void initState() {
    super.initState();
    final current = ref.read(homeWidgetsProvider);
    _visible = List.of(current);
    _hidden = HomeWidgetId.values.where((id) => !current.contains(id)).toList();
  }

  Future<void> _save() async {
    await ref.read(homeWidgetsProvider.notifier).save(_visible, _hidden);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    await ref.read(homeWidgetsProvider.notifier).resetToDefault();
    if (mounted) Navigator.of(context).pop();
  }

  void _toggle(HomeWidgetId id, bool enabled) {
    setState(() {
      if (enabled) {
        _hidden.remove(id);
        _visible.add(id);
      } else {
        _visible.remove(id);
        _hidden.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final allInOrder = [..._visible, ..._hidden];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: context.shapes.bottomSheet,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Personalizar página inicial',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: Text(
                        'Restaurar padrão',
                        style: tt.labelMedium?.copyWith(color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Arraste para reordenar. Desmarque para ocultar.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  buildDefaultDragHandles: false,
                  itemCount: allInOrder.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = allInOrder.removeAt(oldIndex);
                      allInOrder.insert(newIndex, item);
                      _visible = allInOrder
                          .where((id) => !_hidden.contains(id))
                          .toList();
                    });
                  },
                  itemBuilder: (context, i) {
                    final id = allInOrder[i];
                    final isVisible = !_hidden.contains(id);
                    return _WidgetTile(
                      key: ValueKey(id),
                      index: i,
                      id: id,
                      isVisible: isVisible,
                      cs: cs,
                      tt: tt,
                      onToggle: (v) => _toggle(id, v),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AppButton(
                    label: 'Salvar',
                    expanded: true,
                    onPressed: _save,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WidgetTile extends StatelessWidget {
  const _WidgetTile({
    super.key,
    required this.index,
    required this.id,
    required this.isVisible,
    required this.cs,
    required this.tt,
    required this.onToggle,
  });

  final int index;
  final HomeWidgetId id;
  final bool isVisible;
  final ColorScheme cs;
  final TextTheme tt;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isVisible ? cs.surfaceContainerHigh : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Icon(
                Icons.drag_handle_rounded,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              id.label,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isVisible
                    ? cs.onSurface
                    : cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Switch(
            value: isVisible,
            onChanged: onToggle,
            activeThumbColor: cs.primary,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
