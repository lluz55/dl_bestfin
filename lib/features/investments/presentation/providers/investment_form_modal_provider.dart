import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/investments/domain/models/investment.dart';

class InvestmentFormModalState {
  final bool isOpen;
  final Investment? investment;

  const InvestmentFormModalState({this.isOpen = false, this.investment});

  InvestmentFormModalState copyWith({bool? isOpen, Investment? investment}) {
    return InvestmentFormModalState(
      isOpen: isOpen ?? this.isOpen,
      investment: investment ?? this.investment,
    );
  }
}

class InvestmentFormModalNotifier extends Notifier<InvestmentFormModalState> {
  @override
  InvestmentFormModalState build() {
    return const InvestmentFormModalState();
  }

  void open({Investment? investment}) {
    state = state.copyWith(isOpen: true, investment: investment);
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }
}

final investmentFormModalProvider =
    NotifierProvider<InvestmentFormModalNotifier, InvestmentFormModalState>(() {
      return InvestmentFormModalNotifier();
    });
