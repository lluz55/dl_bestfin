import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/adaptive_modal_panel.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_form_modal_provider.dart';
import 'package:bestfin/features/recurring/presentation/screens/recurring_form_screen.dart';

class RecurringFormModalOverlay extends ConsumerStatefulWidget {
  const RecurringFormModalOverlay({super.key});

  @override
  ConsumerState<RecurringFormModalOverlay> createState() =>
      _RecurringFormModalOverlayState();
}

class _RecurringFormModalOverlayState
    extends ConsumerState<RecurringFormModalOverlay> {
  bool _sheetShown = false;

  @override
  Widget build(BuildContext context) {
    final modalState = ref.watch(recurringFormModalProvider);

    if (!modalState.isOpen) {
      _sheetShown = false;
      return const SizedBox.shrink();
    }

    if (Breakpoints.isCompact(context)) {
      if (!_sheetShown) {
        _sheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(recurringFormModalProvider);
          if (!current.isOpen) return;
          ref.read(recurringFormModalProvider.notifier).close();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: RecurringFormScreen(
                  prefillData: current.prefillData,
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          );
        });
      }
      return const SizedBox.shrink();
    }

    return AdaptiveModalPanel(
      onClose: () => ref.read(recurringFormModalProvider.notifier).close(),
      builder: (context, requestClose) => RecurringFormScreen(
        prefillData: modalState.prefillData,
        onClose: requestClose,
      ),
    );
  }
}
