import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';

final exportJsonUseCaseProvider = Provider<ExportJsonUseCase>((ref) {
  return ExportJsonUseCase(ref.read(databaseProvider));
});

class ExportJsonUseCase {
  final AppDatabase _db;

  ExportJsonUseCase(this._db);

  Future<Map<String, dynamic>> execute() async {
    final accounts = await _db.select(_db.accounts).get();
    final appSettings = await _db.select(_db.appSettings).get();
    final attachments = await _db.select(_db.attachments).get();
    final badges = await _db.select(_db.badges).get();
    final categories = await _db.select(_db.categories).get();
    final categoryParentsList = await _db.select(_db.categoryParents).get();
    final creditCards = await _db.select(_db.creditCards).get();
    final entities = await _db.select(_db.entities).get();
    final entries = await _db.select(_db.entries).get();
    final financingInstallments = await _db
        .select(_db.financingInstallments)
        .get();
    final financings = await _db.select(_db.financings).get();
    final goals = await _db.select(_db.goals).get();
    final holidays = await _db.select(_db.holidays).get();
    final householdMembers = await _db.select(_db.householdMembers).get();
    final households = await _db.select(_db.households).get();
    final installmentPlans = await _db.select(_db.installmentPlans).get();
    final investments = await _db.select(_db.investments).get();
    final invoices = await _db.select(_db.invoices).get();
    final notificationPatterns = await _db
        .select(_db.notificationPatterns)
        .get();
    final recurringRules = await _db.select(_db.recurringRules).get();
    final streaks = await _db.select(_db.streaks).get();
    final transactions = await _db.select(_db.transactions).get();

    return {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts.map((x) => x.toJson()).toList(),
      'app_settings': appSettings.map((x) => x.toJson()).toList(),
      'attachments': attachments.map((x) => x.toJson()).toList(),
      'badges': badges.map((x) => x.toJson()).toList(),
      'categories': categories.map((x) => x.toJson()).toList(),
      'category_parents': categoryParentsList.map((x) => x.toJson()).toList(),
      'credit_cards': creditCards.map((x) => x.toJson()).toList(),
      'entities': entities.map((x) => x.toJson()).toList(),
      'entries': entries.map((x) => x.toJson()).toList(),
      'financing_installments': financingInstallments
          .map((x) => x.toJson())
          .toList(),
      'financings': financings.map((x) => x.toJson()).toList(),
      'goals': goals.map((x) => x.toJson()).toList(),
      'holidays': holidays.map((x) => x.toJson()).toList(),
      'household_members': householdMembers.map((x) => x.toJson()).toList(),
      'households': households.map((x) => x.toJson()).toList(),
      'installment_plans': installmentPlans.map((x) => x.toJson()).toList(),
      'investments': investments.map((x) => x.toJson()).toList(),
      'invoices': invoices.map((x) => x.toJson()).toList(),
      'notification_patterns': notificationPatterns
          .map((x) => x.toJson())
          .toList(),
      'recurring_rules': recurringRules.map((x) => x.toJson()).toList(),
      'streaks': streaks.map((x) => x.toJson()).toList(),
      'transactions': transactions.map((x) => x.toJson()).toList(),
    };
  }
}
