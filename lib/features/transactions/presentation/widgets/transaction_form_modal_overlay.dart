import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/adaptive_modal_panel.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';
import 'package:bestfin/features/transactions/presentation/screens/transaction_form_screen.dart';

/// Chrome compartilhado do bottom sheet de transação no mobile: fundo
/// transparente, cantos arredondados e altura limitada a 65% da tela. Usado
/// pelo formulário individual, pela inserção em massa e pela edição de
/// membros de um grupo, para manter o mesmo padrão de apresentação.
Future<T?> showLimitedTransactionSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext sheetContext) builder,
}) {
  final isMobile = Breakpoints.isCompact(context);
  return showAppBottomSheet<T>(
    context: context,
    useSafeArea: false,
    maxHeightFraction: isMobile ? kAppSheetMaxHeightFraction : null,
    builder: builder,
  );
}

class TransactionFormModalOverlay extends ConsumerStatefulWidget {
  const TransactionFormModalOverlay({super.key});

  @override
  ConsumerState<TransactionFormModalOverlay> createState() =>
      _TransactionFormModalOverlayState();
}

class _TransactionFormModalOverlayState
    extends ConsumerState<TransactionFormModalOverlay> {
  bool _sheetShown = false;

  @override
  Widget build(BuildContext context) {
    final modalState = ref.watch(transactionFormModalProvider);

    if (!modalState.isOpen) {
      _sheetShown = false;
      return const SizedBox.shrink();
    }

    if (Breakpoints.isCompact(context)) {
      if (!_sheetShown) {
        _sheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(transactionFormModalProvider);
          if (!current.isOpen) return;
          ref.read(transactionFormModalProvider.notifier).close();
          showLimitedTransactionSheet<void>(
            context: context,
            builder: (sheetContext) => TransactionFormScreen(
              initialType: current.initialType,
              transaction: current.transaction,
              isCloning: current.isCloning,
              draft: current.draft,
              openRecurringWizardOnStart: current.openRecurringWizard,
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          );
        });
      }
      return const SizedBox.shrink();
    }

    return AdaptiveModalPanel(
      onClose: () => ref.read(transactionFormModalProvider.notifier).close(),
      builder: (context, requestClose) => TransactionFormScreen(
        initialType: modalState.initialType,
        transaction: modalState.transaction,
        isCloning: modalState.isCloning,
        draft: modalState.draft,
        openRecurringWizardOnStart: modalState.openRecurringWizard,
        onClose: requestClose,
      ),
    );
  }
}
