import 'package:bestfin/core/database/app_database.dart' as db;

class EntryModel {
  final String id;
  final String transactionId;
  final String accountId;
  final int amount;
  final String type; // 'debit' or 'credit'
  final DateTime createdAt;

  const EntryModel({
    required this.id,
    required this.transactionId,
    required this.accountId,
    required this.amount,
    required this.type,
    required this.createdAt,
  });

  factory EntryModel.fromDb(db.Entry entry) {
    return EntryModel(
      id: entry.id,
      transactionId: entry.transactionId,
      accountId: entry.accountId,
      amount: entry.amount,
      type: entry.type,
      createdAt: entry.createdAt,
    );
  }
}
