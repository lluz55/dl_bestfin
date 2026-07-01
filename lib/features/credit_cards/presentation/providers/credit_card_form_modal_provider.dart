import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';

class CreditCardFormModalState {
  final bool isOpen;
  final CreditCardModel? card;

  const CreditCardFormModalState({this.isOpen = false, this.card});

  CreditCardFormModalState copyWith({bool? isOpen, CreditCardModel? card}) {
    return CreditCardFormModalState(
      isOpen: isOpen ?? this.isOpen,
      card: card ?? this.card,
    );
  }
}

class CreditCardFormModalNotifier extends Notifier<CreditCardFormModalState> {
  @override
  CreditCardFormModalState build() {
    return const CreditCardFormModalState();
  }

  void open({CreditCardModel? card}) {
    state = state.copyWith(isOpen: true, card: card);
  }

  void close() {
    state = state.copyWith(isOpen: false);
  }
}

final creditCardFormModalProvider =
    NotifierProvider<CreditCardFormModalNotifier, CreditCardFormModalState>(() {
      return CreditCardFormModalNotifier();
    });
