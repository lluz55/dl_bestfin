import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecurringFormModalState {
  final bool isOpen;
  final Map<String, dynamic>? prefillData;

  const RecurringFormModalState({this.isOpen = false, this.prefillData});

  RecurringFormModalState copyWith({
    bool? isOpen,
    Map<String, dynamic>? prefillData,
  }) {
    return RecurringFormModalState(
      isOpen: isOpen ?? this.isOpen,
      prefillData: prefillData ?? this.prefillData,
    );
  }
}

class RecurringFormModalNotifier extends Notifier<RecurringFormModalState> {
  @override
  RecurringFormModalState build() {
    return const RecurringFormModalState();
  }

  void open({Map<String, dynamic>? prefillData}) {
    state = state.copyWith(isOpen: true, prefillData: prefillData);
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }
}

final recurringFormModalProvider =
    NotifierProvider<RecurringFormModalNotifier, RecurringFormModalState>(
      () => RecurringFormModalNotifier(),
    );
