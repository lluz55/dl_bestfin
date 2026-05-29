import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/credit_cards.dart';

part 'credit_cards_dao.g.dart';

@DriftAccessor(tables: [CreditCards])
class CreditCardsDao extends DatabaseAccessor<AppDatabase>
    with _$CreditCardsDaoMixin {
  CreditCardsDao(AppDatabase db) : super(db);

  Stream<List<CreditCard>> watchAllCreditCards() {
    return select(creditCards).watch();
  }

  Future<CreditCard> getCreditCardById(String id) {
    return (select(creditCards)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<int> insertCreditCard(CreditCardsCompanion card) {
    return into(creditCards).insert(card);
  }

  Future<bool> updateCreditCard(CreditCardsCompanion card) {
    return update(creditCards).replace(card);
  }

  Future<int> deleteCreditCard(String id) {
    return (delete(creditCards)..where((t) => t.id.equals(id))).go();
  }
}
