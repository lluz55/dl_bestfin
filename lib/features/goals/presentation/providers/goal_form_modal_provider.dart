import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/goals/domain/models/goal.dart';

class GoalFormModalState {
  final bool isOpen;
  final GoalModel? goal;

  const GoalFormModalState({this.isOpen = false, this.goal});

  GoalFormModalState copyWith({bool? isOpen, GoalModel? goal}) {
    return GoalFormModalState(
      isOpen: isOpen ?? this.isOpen,
      goal: goal ?? this.goal,
    );
  }
}

class GoalFormModalNotifier extends Notifier<GoalFormModalState> {
  @override
  GoalFormModalState build() {
    return const GoalFormModalState();
  }

  void open({GoalModel? goal}) {
    state = state.copyWith(isOpen: true, goal: goal);
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }
}

final goalFormModalProvider =
    NotifierProvider<GoalFormModalNotifier, GoalFormModalState>(() {
      return GoalFormModalNotifier();
    });
