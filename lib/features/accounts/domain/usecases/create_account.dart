import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';

class CreateAccount {
  final AccountRepository repository;

  CreateAccount(this.repository);

  /// Retorna o id da conta criada.
  Future<String> call({
    required String name,
    required String type,
    required String? icon,
    required String? color,
    required int initialBalance,
  }) {
    return repository.createWithInitialBalance(
      name: name,
      type: type,
      icon: icon,
      color: color,
      initialBalance: initialBalance,
    );
  }
}
