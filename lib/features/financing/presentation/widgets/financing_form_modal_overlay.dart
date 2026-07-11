import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/adaptive_modal_panel.dart';
import 'package:bestfin/features/financing/presentation/providers/financing_form_modal_provider.dart';
import 'package:bestfin/features/financing/presentation/screens/financing_form_screen.dart';

class FinancingFormModalOverlay extends ConsumerStatefulWidget {
  const FinancingFormModalOverlay({super.key});

  @override
  ConsumerState<FinancingFormModalOverlay> createState() =>
      _FinancingFormModalOverlayState();
}

class _FinancingFormModalOverlayState
    extends ConsumerState<FinancingFormModalOverlay> {
  bool _sheetShown = false;

  @override
  Widget build(BuildContext context) {
    final modalState = ref.watch(financingFormModalProvider);

    if (!modalState.isOpen) {
      _sheetShown = false;
      return const SizedBox.shrink();
    }

    if (Breakpoints.isCompact(context)) {
      if (!_sheetShown) {
        _sheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(financingFormModalProvider);
          if (!current.isOpen) return;
          ref.read(financingFormModalProvider.notifier).close();
          showAppBottomSheet<void>(
            context: context,
            useSafeArea: false,
            builder: (sheetContext) => FinancingFormScreen(
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          );
        });
      }
      return const SizedBox.shrink();
    }

    return AdaptiveModalPanel(
      onClose: () => ref.read(financingFormModalProvider.notifier).close(),
      builder: (context, requestClose) =>
          FinancingFormScreen(onClose: requestClose),
    );
  }
}
