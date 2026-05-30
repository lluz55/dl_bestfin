import 'package:bestfin/features/accounts/data/repositories/account_repository.dart';

class DeleteAccount {
  final AccountRepository repository;

  DeleteAccount(this.repository);

  Future<void> call(String id) async {
    final accounts = await repository.watchAllAccounts().first;
    final activeAccounts = accounts.where((a) => a.isActive).toList();

    final accountToDelete = accounts.firstWhere(
      (a) => a.id == id,
      orElse: () => throw Exception('Conta não encontrada.'),
    );

    if (accountToDelete.isActive && activeAccounts.length <= 1) {
      throw Exception(
        'Não é possível inativar ou excluir a única conta ativa.',
      );
    }

    await repository.deleteAccount(id);
  }
}
