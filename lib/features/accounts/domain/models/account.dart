import 'package:bestfin/core/constants/account_types.dart';
import 'package:bestfin/core/database/app_database.dart' as db;

class Account {
  final String id;
  final String name;
  final AccountType type;
  final String icon;
  final String color;
  final bool isActive;
  final int balance;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.balance,
  });

  factory Account.fromDb(db.Account dbAccount, int balance) {
    final accountType = AccountType.fromString(dbAccount.type);

    String safeIcon =
        dbAccount.icon ?? accountType.defaultIcon.codePoint.toString();
    if (int.tryParse(safeIcon) == null) {
      safeIcon = accountType.defaultIcon.codePoint.toString();
    }

    return Account(
      id: dbAccount.id,
      name: dbAccount.name,
      type: accountType,
      icon: safeIcon,
      color: dbAccount.color ?? accountType.defaultColorHex,
      isActive: !dbAccount.isArchived,
      balance: balance,
    );
  }

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? icon,
    String? color,
    bool? isActive,
    int? balance,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      balance: balance ?? this.balance,
    );
  }
}
