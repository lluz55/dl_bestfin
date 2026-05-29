import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';

class GetAccountBalance {
  final AccountRepository repository;

  GetAccountBalance(this.repository);

  Future<int> call(String id) {
    return repository.getAccountBalance(id);
  }
}
