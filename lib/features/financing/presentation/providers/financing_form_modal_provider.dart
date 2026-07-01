import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinancingFormModalState {
  final bool isOpen;

  const FinancingFormModalState({this.isOpen = false});

  FinancingFormModalState copyWith({bool? isOpen}) {
    return FinancingFormModalState(isOpen: isOpen ?? this.isOpen);
  }
}

class FinancingFormModalNotifier extends Notifier<FinancingFormModalState> {
  @override
  FinancingFormModalState build() {
    return const FinancingFormModalState();
  }

  void open() {
    state = state.copyWith(isOpen: true);
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }
}

final financingFormModalProvider =
    NotifierProvider<FinancingFormModalNotifier, FinancingFormModalState>(() {
      return FinancingFormModalNotifier();
    });
