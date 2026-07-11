import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/adaptive_modal_panel.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_card_form_modal_provider.dart';
import 'package:bestfin/features/credit_cards/presentation/screens/credit_card_form_screen.dart';

class CreditCardFormModalOverlay extends ConsumerStatefulWidget {
  const CreditCardFormModalOverlay({super.key});

  @override
  ConsumerState<CreditCardFormModalOverlay> createState() =>
      _CreditCardFormModalOverlayState();
}

class _CreditCardFormModalOverlayState
    extends ConsumerState<CreditCardFormModalOverlay> {
  bool _sheetShown = false;

  @override
  Widget build(BuildContext context) {
    final modalState = ref.watch(creditCardFormModalProvider);

    if (!modalState.isOpen) {
      _sheetShown = false;
      return const SizedBox.shrink();
    }

    if (Breakpoints.isCompact(context)) {
      if (!_sheetShown) {
        _sheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(creditCardFormModalProvider);
          if (!current.isOpen) return;
          ref.read(creditCardFormModalProvider.notifier).close();
          showAppBottomSheet<void>(
            context: context,
            useSafeArea: false,
            builder: (sheetContext) => CreditCardFormScreen(
              card: current.card,
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          );
        });
      }
      return const SizedBox.shrink();
    }

    return AdaptiveModalPanel(
      onClose: () => ref.read(creditCardFormModalProvider.notifier).close(),
      builder: (context, requestClose) =>
          CreditCardFormScreen(card: modalState.card, onClose: requestClose),
    );
  }
}
