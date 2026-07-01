import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/adaptive_modal_panel.dart';
import 'package:bestfin/features/transactions/presentation/providers/transaction_form_modal_provider.dart';
import 'package:bestfin/features/transactions/presentation/screens/transaction_form_screen.dart';

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
                child: TransactionFormScreen(
                  initialType: current.initialType,
                  transaction: current.transaction,
                  isCloning: current.isCloning,
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
      onClose: () => ref.read(transactionFormModalProvider.notifier).close(),
      builder: (context, requestClose) => TransactionFormScreen(
        initialType: modalState.initialType,
        transaction: modalState.transaction,
        isCloning: modalState.isCloning,
        onClose: requestClose,
      ),
    );
  }
}
