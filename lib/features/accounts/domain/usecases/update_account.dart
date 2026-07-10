import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';

class UpdateAccount {
  final AccountRepository repository;

  UpdateAccount(this.repository);

  Future<void> call({
    required String id,
    required String name,
    required String type,
    required String? icon,
    required String? color,
    bool? isActive,
    int? initialBalance,
  }) {
    return repository.updateAccount(
      id: id,
      name: name,
      type: type,
      icon: icon,
      color: color,
      isActive: isActive,
      initialBalance: initialBalance,
    );
  }
}
