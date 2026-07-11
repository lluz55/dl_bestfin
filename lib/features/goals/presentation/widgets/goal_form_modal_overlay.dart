import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/adaptive_modal_panel.dart';
import 'package:bestfin/features/goals/presentation/providers/goal_form_modal_provider.dart';
import 'package:bestfin/features/goals/presentation/screens/goal_form_screen.dart';

class GoalFormModalOverlay extends ConsumerStatefulWidget {
  const GoalFormModalOverlay({super.key});

  @override
  ConsumerState<GoalFormModalOverlay> createState() =>
      _GoalFormModalOverlayState();
}

class _GoalFormModalOverlayState extends ConsumerState<GoalFormModalOverlay> {
  bool _sheetShown = false;

  @override
  Widget build(BuildContext context) {
    final modalState = ref.watch(goalFormModalProvider);

    if (!modalState.isOpen) {
      _sheetShown = false;
      return const SizedBox.shrink();
    }

    if (Breakpoints.isCompact(context)) {
      if (!_sheetShown) {
        _sheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = ref.read(goalFormModalProvider);
          if (!current.isOpen) return;
          ref.read(goalFormModalProvider.notifier).close();
          showAppBottomSheet<void>(
            context: context,
            useSafeArea: false,
            builder: (sheetContext) => GoalFormScreen(
              existingGoal: current.goal,
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          );
        });
      }
      return const SizedBox.shrink();
    }

    return AdaptiveModalPanel(
      onClose: () => ref.read(goalFormModalProvider.notifier).close(),
      builder: (context, requestClose) =>
          GoalFormScreen(existingGoal: modalState.goal, onClose: requestClose),
    );
  }
}
