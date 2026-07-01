import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/adaptive_modal_panel.dart';
import 'package:bestfin/features/investments/presentation/providers/investment_form_modal_provider.dart';
import 'package:bestfin/features/investments/presentation/screens/investment_form_screen.dart';

class InvestmentFormModalOverlay extends ConsumerStatefulWidget {
  const InvestmentFormModalOverlay({super.key});

  @override
  ConsumerState<InvestmentFormModalOverlay> createState() =>
      _InvestmentFormModalOverlayState();
}

class _InvestmentFormModalOverlayState
    extends ConsumerState<InvestmentFormModalOverlay> {
  bool _sheetShown = false;

  @override
  Widget build(BuildContext context) {
    final modalState = ref.watch(investmentFormModalProvider);

    if (!modalState.isOpen) {
      _sheetShown = false;
      return const SizedBox.shrink();
    }

    if (Breakpoints.isCompact(context)) {
      if (!_sheetShown) {
        _sheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(investmentFormModalProvider);
          if (!current.isOpen) return;
          ref.read(investmentFormModalProvider.notifier).close();
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
                child: InvestmentFormScreen(
                  existingInvestment: current.investment,
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
      onClose: () => ref.read(investmentFormModalProvider.notifier).close(),
      builder: (context, requestClose) => InvestmentFormScreen(
        existingInvestment: modalState.investment,
        onClose: requestClose,
      ),
    );
  }
}
