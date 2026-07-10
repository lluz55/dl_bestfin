import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/features/backup/domain/backup_version.dart';
import 'package:uuid/uuid.dart';
import 'package:csv/csv.dart';

final importDataUseCaseProvider = Provider<ImportDataUseCase>((ref) {
  // watch (não read): após um invalidate do databaseProvider (clear-all,
  // restore), o use case precisa ser reconstruído com a instância nova —
  // com read ele ficava preso a um banco já fechado.
  return ImportDataUseCase(ref.watch(databaseProvider));
});

class ImportDataUseCase {
  final AppDatabase _db;

  ImportDataUseCase(this._db);

  /// Validates a CSV string and returns a preview summary of what will be imported
  Future<Map<String, dynamic>> previewCsv(
    String csvString, {
    String separator = ';',
  }) async {
    final csvTable = Csv(fieldDelimiter: separator).decode(csvString);
    if (csvTable.isEmpty) {
      throw const FormatException('O arquivo CSV está vazio.');
    }

    final headers = csvTable.first
        .map((e) => e.toString().toLowerCase().trim())
        .toList();
    final dateIdx = headers.indexWhere(
      (h) => h.contains('data') || h.contains('date'),
    );
    final descIdx = headers.indexWhere(
      (h) => h.contains('descri') || h.contains('description'),
    );
    final valIdx = headers.indexWhere(
      (h) => h.contains('valor') || h.contains('amount') || h.contains('value'),
    );

    if (dateIdx < 0 || descIdx < 0 || valIdx < 0) {
      throw const FormatException(
        'Colunas obrigatórias não encontradas no CSV. Certifique-se de incluir: Data, Descrição e Valor.',
      );
    }

    int validRows = 0;
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      if (row.length > dateIdx && row.length > descIdx && row.length > valIdx) {
        if (row[dateIdx].toString().trim().isNotEmpty &&
            row[descIdx].toString().trim().isNotEmpty) {
          validRows++;
        }
      }
    }

    return {
      'type': 'csv',
      'total_rows': csvTable.length - 1,
      'valid_rows': validRows,
    };
  }

  /// Imports transaction data from a CSV string
  Future<int> importCsv(String csvString, {String separator = ';'}) async {
    final csvTable = Csv(fieldDelimiter: separator).decode(csvString);
    if (csvTable.length <= 1) return 0;

    final headers = csvTable.first
        .map((e) => e.toString().toLowerCase().trim())
        .toList();
    final dateIdx = headers.indexWhere(
      (h) => h.contains('data') || h.contains('date'),
    );
    final descIdx = headers.indexWhere(
      (h) => h.contains('descri') || h.contains('description'),
    );
    final typeIdx = headers.indexWhere(
      (h) => h.contains('tipo') || h.contains('type'),
    );
    final valIdx = headers.indexWhere(
      (h) => h.contains('valor') || h.contains('amount') || h.contains('value'),
    );
    final catIdx = headers.indexWhere(
      (h) => h.contains('categoria') || h.contains('category'),
    );
    final accIdx = headers.indexWhere(
      (h) =>
          h == 'conta' ||
          h.contains('origem') ||
          h.contains('account') ||
          h.contains('source'),
    );
    final destIdx = headers.indexWhere(
      (h) => h.contains('destino') || h.contains('dest') || h.contains('to'),
    );
    final sentIdx = headers.indexWhere(
      (h) => h.contains('sentiment') || h.contains('sentimento'),
    );
    final noteIdx = headers.indexWhere(
      (h) => h.contains('observa') || h.contains('note') || h.contains('notes'),
    );

    // Cache categories and accounts
    final allCategories = await _db.select(_db.categories).get();
    final allAccounts = await _db.select(_db.accounts).get();

    int importedCount = 0;

    await _db.transaction(() async {
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length <= dateIdx ||
            row.length <= descIdx ||
            row.length <= valIdx)
          continue;

        final dateRaw = row[dateIdx].toString().trim();
        final descRaw = row[descIdx].toString().trim();
        final valRaw = row[valIdx].toString().trim();

        if (dateRaw.isEmpty || descRaw.isEmpty || valRaw.isEmpty) continue;

        // Parse fields
        final date = _parseDate(dateRaw);
        final amountCents = _parseAmountCents(valRaw);
        final type = typeIdx >= 0 && row.length > typeIdx
            ? row[typeIdx].toString().toLowerCase().trim()
            : 'expense';
        final sentiment = sentIdx >= 0 && row.length > sentIdx
            ? row[sentIdx].toString().trim()
            : null;
        final notes = noteIdx >= 0 && row.length > noteIdx
            ? row[noteIdx].toString().trim()
            : null;

        // Resolve Category
        String? categoryId;
        if (catIdx >= 0 &&
            row.length > catIdx &&
            row[catIdx].toString().trim().isNotEmpty) {
          final catName = row[catIdx].toString().trim();
          var category = allCategories.firstWhere(
            (c) => c.name.toLowerCase() == catName.toLowerCase(),
            orElse: () => _nullCategory(),
          );
          if (category.id.isEmpty) {
            final catId = 'cat_${const Uuid().v4()}';
            await _db
                .into(_db.categories)
                .insert(
                  CategoriesCompanion.insert(
                    id: catId,
                    name: catName,
                    icon: 'category',
                    color: '#9E9E9E',
                    type: type == 'income' ? 'income' : 'expense',
                  ),
                );
            category = Category(
              id: catId,
              name: catName,
              icon: 'category',
              color: '#9E9E9E',
              type: type == 'income' ? 'income' : 'expense',
              isSystem: false,
              isArchived: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            allCategories.add(category);
          }
          categoryId = category.id;
        }

        // Resolve Source Account
        String accountId = '';
        if (accIdx >= 0 &&
            row.length > accIdx &&
            row[accIdx].toString().trim().isNotEmpty) {
          final accName = row[accIdx].toString().trim();
          var account = allAccounts.firstWhere(
            (a) => a.name.toLowerCase() == accName.toLowerCase(),
            orElse: () => _nullAccount(),
          );
          if (account.id.isEmpty) {
            final accId = 'acc_${const Uuid().v4()}';
            await _db
                .into(_db.accounts)
                .insert(
                  AccountsCompanion.insert(
                    id: accId,
                    name: accName,
                    type: 'checking',
                    color: const Value('#2196F3'),
                  ),
                );
            account = Account(
              id: accId,
              name: accName,
              type: 'checking',
              color: '#2196F3',
              isArchived: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            allAccounts.add(account);
          }
          accountId = account.id;
        } else {
          // Default account fallback if missing
          if (allAccounts.isEmpty) {
            final accId = 'acc_${const Uuid().v4()}';
            await _db
                .into(_db.accounts)
                .insert(
                  AccountsCompanion.insert(
                    id: accId,
                    name: 'Conta Principal',
                    type: 'checking',
                    color: const Value('#2196F3'),
                  ),
                );
            final account = Account(
              id: accId,
              name: 'Conta Principal',
              type: 'checking',
              color: '#2196F3',
              isArchived: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            allAccounts.add(account);
            accountId = accId;
          } else {
            accountId = allAccounts.first.id;
          }
        }

        // Resolve Destination Account
        String? destAccountId;
        if (destIdx >= 0 &&
            row.length > destIdx &&
            row[destIdx].toString().trim().isNotEmpty) {
          final destName = row[destIdx].toString().trim();
          var destAccount = allAccounts.firstWhere(
            (a) => a.name.toLowerCase() == destName.toLowerCase(),
            orElse: () => _nullAccount(),
          );
          if (destAccount.id.isEmpty) {
            final accId = 'acc_${const Uuid().v4()}';
            await _db
                .into(_db.accounts)
                .insert(
                  AccountsCompanion.insert(
                    id: accId,
                    name: destName,
                    type: 'checking',
                    color: const Value('#4CAF50'),
                  ),
                );
            destAccount = Account(
              id: accId,
              name: destName,
              type: 'checking',
              color: '#4CAF50',
              isArchived: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            allAccounts.add(destAccount);
          }
          destAccountId = destAccount.id;
        }

        final txId = const Uuid().v4();
        await _db.transactionsDao.createTransaction(
          data: TransactionsCompanion.insert(
            id: txId,
            date: date,
            description: descRaw,
            type: type,
            categoryId: Value(categoryId),
            sentiment: Value(sentiment),
            notes: Value(notes),
          ),
          accountId: accountId,
          amount: amountCents.abs(),
          toAccountId: destAccountId,
        );

        importedCount++;
      }
    });

    return importedCount;
  }

  /// Validates a JSON string and returns a preview summary of what will be imported
  Future<Map<String, dynamic>> previewJson(String jsonString) async {
    try {
      final decoded = json.decode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'O arquivo JSON deve conter um objeto estruturado.',
        );
      }

      if (decoded['version'] == null || decoded['exported_at'] == null) {
        throw const FormatException(
          'O formato do arquivo JSON não é compatível com o BestFin.',
        );
      }

      // Rejeita formatos antigos demais ou de um app mais novo (esquema que
      // esta build não modela) antes de mostrar o preview ao usuário.
      _validateBackupCompatibility(decoded);

      final tables = [
        'accounts',
        'categories',
        'transactions',
        'entries',
        'credit_cards',
        'goals',
        'investments',
        'financings',
        'recurring_rules',
        'badges',
        'streaks',
      ];
      final counts = <String, int>{};

      for (final t in tables) {
        final list = decoded[t];
        if (list is List) {
          counts[t] = list.length;
        } else {
          counts[t] = 0;
        }
      }

      return {
        'type': 'json',
        'version': decoded['version'],
        'schema_version': decoded['schema_version'],
        'exported_at': decoded['exported_at'],
        'counts': counts,
      };
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Erro ao analisar JSON: $e');
    }
  }

  /// Restores complete database structure from JSON Map
  Future<void> restoreJson(String jsonString) async {
    final decoded = json.decode(jsonString) as Map<String, dynamic>;

    // Revalida a compatibilidade aqui também: restoreJson pode ser chamado sem
    // passar por previewJson, e esta operação apaga o banco atual antes de
    // inserir — nunca destrua os dados por um backup incompatível.
    _validateBackupCompatibility(decoded);

    await _db.transaction(() async {
      // 1. Delete in reverse dependency order
      await _db.delete(_db.attachments).go();
      await _db.delete(_db.entries).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.invoices).go();
      await _db.delete(_db.creditCards).go();
      await _db.delete(_db.investments).go();
      await _db.delete(_db.financingInstallments).go();
      await _db.delete(_db.financings).go();
      await _db.delete(_db.recurringRules).go();
      await _db.delete(_db.installmentPlans).go();
      await _db.delete(_db.goals).go();
      await _db.delete(_db.notificationPatterns).go();
      await _db.delete(_db.holidays).go();
      await _db.delete(_db.entities).go();
      await _db.delete(_db.accounts).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.appSettings).go();
      await _db.delete(_db.badges).go();
      await _db.delete(_db.streaks).go();
      await _db.delete(_db.householdMembers).go();
      await _db.delete(_db.households).go();

      // 2. Helper lists
      final settingsList = decoded['app_settings'] as List? ?? [];
      final categoriesList = decoded['categories'] as List? ?? [];
      final accountsList = decoded['accounts'] as List? ?? [];
      final entitiesList = decoded['entities'] as List? ?? [];
      final holidaysList = decoded['holidays'] as List? ?? [];
      final notificationPatternsList =
          decoded['notification_patterns'] as List? ?? [];
      final goalsList = decoded['goals'] as List? ?? [];
      final installmentPlansList = decoded['installment_plans'] as List? ?? [];
      final recurringRulesList = decoded['recurring_rules'] as List? ?? [];
      final financingsList = decoded['financings'] as List? ?? [];
      final financingInstallmentsList =
          decoded['financing_installments'] as List? ?? [];
      final investmentsList = decoded['investments'] as List? ?? [];
      final creditCardsList = decoded['credit_cards'] as List? ?? [];
      final invoicesList = decoded['invoices'] as List? ?? [];
      final transactionsList = decoded['transactions'] as List? ?? [];
      final entriesList = decoded['entries'] as List? ?? [];
      final attachmentsList = decoded['attachments'] as List? ?? [];
      final badgesList = decoded['badges'] as List? ?? [];
      final streaksList = decoded['streaks'] as List? ?? [];
      final householdsList = decoded['households'] as List? ?? [];
      final householdMembersList = decoded['household_members'] as List? ?? [];

      // 3. Restore in dependency order
      for (final item in settingsList) {
        await _db.into(_db.appSettings).insert(AppSetting.fromJson(item));
      }

      for (final x in categoriesList) {
        await _db.into(_db.categories).insert(Category.fromJson(x));
      }

      // Restore category parent-child relationships if present in backup
      final categoryParentsList = decoded['category_parents'] as List? ?? [];
      for (final item in categoryParentsList) {
        await _db
            .into(_db.categoryParents)
            .insert(CategoryParent.fromJson(item));
      }

      for (final item in accountsList) {
        await _db.into(_db.accounts).insert(Account.fromJson(item));
      }
      for (final item in entitiesList) {
        await _db.into(_db.entities).insert(Entity.fromJson(item));
      }
      for (final item in holidaysList) {
        await _db.into(_db.holidays).insert(Holiday.fromJson(item));
      }
      for (final item in notificationPatternsList) {
        await _db
            .into(_db.notificationPatterns)
            .insert(NotificationPattern.fromJson(item));
      }
      for (final item in goalsList) {
        await _db.into(_db.goals).insert(Goal.fromJson(item));
      }
      for (final item in installmentPlansList) {
        await _db
            .into(_db.installmentPlans)
            .insert(InstallmentPlan.fromJson(item));
      }
      for (final item in recurringRulesList) {
        await _db.into(_db.recurringRules).insert(RecurringRule.fromJson(item));
      }
      for (final item in financingsList) {
        await _db.into(_db.financings).insert(Financing.fromJson(item));
      }
      for (final item in financingInstallmentsList) {
        await _db
            .into(_db.financingInstallments)
            .insert(FinancingInstallment.fromJson(item));
      }
      for (final item in investmentsList) {
        await _db.into(_db.investments).insert(Investment.fromJson(item));
      }
      for (final item in creditCardsList) {
        await _db.into(_db.creditCards).insert(CreditCard.fromJson(item));
      }
      for (final item in invoicesList) {
        await _db.into(_db.invoices).insert(Invoice.fromJson(item));
      }
      for (final item in transactionsList) {
        await _db.into(_db.transactions).insert(Transaction.fromJson(item));
      }
      for (final item in entriesList) {
        await _db.into(_db.entries).insert(Entry.fromJson(item));
      }
      for (final item in attachmentsList) {
        await _db.into(_db.attachments).insert(Attachment.fromJson(item));
      }
      for (final item in badgesList) {
        await _db.into(_db.badges).insert(Badge.fromJson(item));
      }
      for (final item in streaksList) {
        await _db.into(_db.streaks).insert(Streak.fromJson(item));
      }
      for (final item in householdsList) {
        await _db.into(_db.households).insert(Household.fromJson(item));
      }
      for (final item in householdMembersList) {
        await _db
            .into(_db.householdMembers)
            .insert(HouseholdMember.fromJson(item));
      }
    });
  }

  // --- Compatibility validation ---

  /// Verifica se um backup JSON decodificado pode ser importado com segurança.
  ///
  /// Duas checagens, na ordem de severidade:
  /// 1. `version` (formato do envelope) precisa estar entre
  ///    [kMinSupportedBackupFormatVersion] e [kBackupFormatVersion]. Formatos
  ///    mais novos têm chaves que esta build não sabe ler; mais antigos que o
  ///    mínimo não são mais suportados.
  /// 2. `schema_version` dos dados não pode ser maior que o schema desta build
  ///    ([AppDatabase.schemaVersion]) — seria importar dados de um app mais novo
  ///    com tabelas/colunas que ainda não existem aqui.
  ///
  /// Backups antigos podem não ter `schema_version`; nesse caso a checagem 2 é
  /// pulada e a importação segue em regime de melhor esforço.
  void _validateBackupCompatibility(Map<String, dynamic> decoded) {
    final formatVersion = (decoded['version'] as num?)?.toInt();
    if (formatVersion == null) {
      throw const BackupIncompatibleException(
        'O arquivo de backup não informa sua versão de formato.',
      );
    }
    if (formatVersion > kBackupFormatVersion) {
      throw BackupIncompatibleException(
        'Este backup foi gerado por uma versão mais nova do BestFin '
        '(formato v$formatVersion). Atualize o app para importá-lo.',
      );
    }
    if (formatVersion < kMinSupportedBackupFormatVersion) {
      throw BackupIncompatibleException(
        'Este backup está em um formato antigo demais (v$formatVersion) e não '
        'pode mais ser importado por esta versão do BestFin.',
      );
    }

    final schemaVersion = (decoded['schema_version'] as num?)?.toInt();
    if (schemaVersion != null && schemaVersion > _db.schemaVersion) {
      throw BackupIncompatibleException(
        'Este backup contém dados de uma versão mais nova do BestFin '
        '(schema v$schemaVersion, esta build usa v${_db.schemaVersion}). '
        'Atualize o app para restaurá-lo.',
      );
    }
  }

  // --- Utility parsing methods ---

  DateTime _parseDate(String val) {
    val = val.trim();
    try {
      if (val.contains('/')) {
        final parts = val.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } else if (val.contains('-')) {
        final parts = val.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            return DateTime.parse(val);
          } else {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            return DateTime(year, month, day);
          }
        }
      }
      return DateTime.parse(val);
    } catch (_) {
      return DateTime.now();
    }
  }

  int _parseAmountCents(String val) {
    try {
      var clean = val
          .replaceAll(r'R$', '')
          .replaceAll(r'$', '')
          .replaceAll(' ', '')
          .trim();
      final isNegative = clean.startsWith('-');
      clean = clean.replaceAll('-', '').replaceAll('+', '');

      if (clean.contains(',') && clean.contains('.')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else if (clean.contains(',')) {
        clean = clean.replaceAll(',', '.');
      }

      final doubleVal = double.parse(clean);
      final cents = (doubleVal * 100).round();
      return isNegative ? -cents : cents;
    } catch (_) {
      return 0;
    }
  }

  Category _nullCategory() => Category(
    id: '',
    name: '',
    icon: '',
    color: '',
    type: '',
    isSystem: false,
    isArchived: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Account _nullAccount() => Account(
    id: '',
    name: '',
    type: '',
    isArchived: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
