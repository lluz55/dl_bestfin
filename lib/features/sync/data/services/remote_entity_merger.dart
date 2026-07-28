import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:bestfin/core/database/app_database.dart';

/// Applies remote (pulled) records to the local Drift database.
///
/// Extracted from [SyncService] (task 58 - refatoracao de "god files"): the
/// ~770 lines of per-entity last-write-wins merge logic lived inline in the
/// sync orchestrator. This class owns only that responsibility - turning a
/// decoded remote row into a local upsert or tombstone - so [SyncService] stays
/// focused on queue processing and pull/push orchestration. Foreign keys are
/// resolved defensively via [_fkOrNull] (a referenced parent that hasn't synced
/// yet becomes null rather than a FK violation).
class RemoteEntityMerger {
  RemoteEntityMerger(this._db);

  final AppDatabase _db;

  /// Merges a single decoded remote [row] of the given [entityType] into the
  /// local database (last-write-wins by `updated_at`). Returns `true` when the
  /// type is supported and applied, `false` for unknown types so the caller can
  /// skip counting it as pulled.
  Future<bool> apply(String entityType, Map<String, dynamic> row) async {
    switch (entityType) {
      case 'transaction':
        await _mergeTransactionFromRemote(row);
      case 'account':
        await _mergeAccountFromRemote(row);
      case 'category':
        await _mergeCategoryFromRemote(row);
      case 'goal':
        await _mergeGoalFromRemote(row);
      case 'credit_card':
        await _mergeCreditCardFromRemote(row);
      case 'invoice':
        await _mergeInvoiceFromRemote(row);
      case 'recurring_rule':
        await _mergeRecurringRuleFromRemote(row);
      case 'installment_plan':
        await _mergeInstallmentPlanFromRemote(row);
      case 'entity':
        await _mergeEntityFromRemote(row);
      case 'financing':
        await _mergeFinancingFromRemote(row);
      case 'investment':
        await _mergeInvestmentFromRemote(row);
      case 'budget':
        await _mergeBudgetFromRemote(row);
      default:
        return false;
    }
    return true;
  }

  Future<void> _mergeTransactionFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
      return;
    }

    // foreign_keys is ON and these referenced entities either aren't synced at
    // all (goals, credit cards, invoices, entities) or may not have arrived
    // yet — a dangling reference must degrade to null instead of failing the
    // insert and dropping the whole transaction on this device.
    final categoryId = await _fkOrNull(
      'categories',
      row['category_id'] as String?,
    );
    final entityId = await _fkOrNull('entities', row['entity_id'] as String?);
    final goalId = await _fkOrNull('goals', row['goal_id'] as String?);
    final creditCardId = await _fkOrNull(
      'credit_cards',
      row['credit_card_id'] as String?,
    );
    final invoiceId = await _fkOrNull('invoices', row['invoice_id'] as String?);

    await _db
        .into(_db.transactions)
        .insertOnConflictUpdate(
          TransactionsCompanion(
            id: Value(id),
            date: Value(
              DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now(),
            ),
            description: Value(row['description'] as String? ?? ''),
            type: Value(row['type'] as String? ?? 'expense'),
            sentiment: Value(row['sentiment'] as String?),
            notes: Value(row['notes'] as String?),
            categoryId: Value(categoryId),
            entityId: Value(entityId),
            goalId: Value(goalId),
            installmentPlanId: Value(row['installment_plan_id'] as String?),
            installmentNumber: Value(row['installment_number'] as int?),
            recurringRuleId: Value(row['recurring_rule_id'] as String?),
            groupId: Value(row['group_id'] as String?),
            creditCardId: Value(creditCardId),
            rawAmount: Value(row['raw_amount'] as int?),
            invoiceId: Value(invoiceId),
            isCompleted: Value(row['is_completed'] as bool? ?? true),
            isConfirmed: Value(row['is_confirmed'] as bool? ?? true),
            source: Value(row['source'] as String?),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );

    final rawEntries = row['entries'];
    if (rawEntries is List) {
      await (_db.delete(
        _db.entries,
      )..where((e) => e.transactionId.equals(id))).go();
      for (final rawEntry in rawEntries.whereType<Map>()) {
        final entry = Map<String, dynamic>.from(rawEntry);
        final accountId = entry['account_id'] as String?;
        final amount = entry['amount'] as int?;
        final type = entry['type'] as String?;
        if (accountId == null || amount == null || type == null) continue;
        if (await _fkOrNull('accounts', accountId) == null) {
          debugPrint(
            '[Sync] Entry ignorada: conta $accountId ainda não existe '
            'localmente (transação $id)',
          );
          continue;
        }
        await _db
            .into(_db.entries)
            .insertOnConflictUpdate(
              EntriesCompanion.insert(
                id: entry['id'] as String? ?? const Uuid().v4(),
                transactionId: id,
                accountId: accountId,
                amount: amount,
                type: type,
                createdAt: Value(
                  DateTime.tryParse(entry['created_at'] as String? ?? '') ??
                      DateTime.now(),
                ),
              ),
            );
      }
    }

    final rawSplits = row['splits'];
    if (rawSplits is List) {
      await (_db.delete(
        _db.transactionSplits,
      )..where((s) => s.transactionId.equals(id))).go();
      for (final rawSplit in rawSplits.whereType<Map>()) {
        final split = Map<String, dynamic>.from(rawSplit);
        final categoryId = split['category_id'] as String?;
        final amount = split['amount'] as int?;
        final description = split['description'] as String?;
        if (amount == null) continue;

        final resolvedCategoryId = await _fkOrNull('categories', categoryId);

        await _db
            .into(_db.transactionSplits)
            .insertOnConflictUpdate(
              TransactionSplitsCompanion.insert(
                id: split['id'] as String? ?? const Uuid().v4(),
                transactionId: id,
                categoryId: Value(resolvedCategoryId),
                amount: amount,
                description: Value(description),
              ),
            );
      }
    }
  }

  Future<void> _mergeAccountFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
      return;
    }

    await _db
        .into(_db.accounts)
        .insertOnConflictUpdate(
          AccountsCompanion(
            id: Value(id),
            name: Value(row['name'] as String? ?? ''),
            type: Value(row['type'] as String? ?? 'checking'),
            color: Value(row['color'] as String? ?? '#6750A4'),
            icon: Value(row['icon'] as String? ?? '984168'),
            isArchived: Value(row['is_archived'] as bool? ?? false),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _mergeCategoryFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
      return;
    }

    await _db
        .into(_db.categories)
        .insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: id,
            name: row['name'] as String? ?? '',
            icon: row['icon'] as String? ?? 'category',
            color: row['color'] as String? ?? '#6750A4',
            type: row['type'] as String? ?? 'expense',
            isSystem: Value(row['is_system'] as bool? ?? false),
            parentId: Value(row['parent_id'] as String?),
            isArchived: Value(row['is_archived'] as bool? ?? false),
            description: Value(row['description'] as String?),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
          ),
        );

    final childIds = row['child_ids'];
    if (childIds is List) {
      await (_db.delete(
        _db.categoryParents,
      )..where((r) => r.parentCategoryId.equals(id))).go();
      for (final childId in childIds.whereType<String>()) {
        await _db
            .into(_db.categoryParents)
            .insertOnConflictUpdate(
              CategoryParentsCompanion.insert(
                parentCategoryId: id,
                childCategoryId: childId,
              ),
            );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns [id] when the referenced row exists locally, null otherwise.
  Future<String?> _fkOrNull(String tableName, String? id) async {
    if (id == null) return null;
    final rows = await _db
        .customSelect(
          'SELECT 1 FROM $tableName WHERE id = ? LIMIT 1',
          variables: [Variable<String>(id)],
        )
        .get();
    return rows.isEmpty ? null : id;
  }

  Future<void> _mergeGoalFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.goals,
    )..where((g) => g.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await _db.goalsDao.deleteGoal(id);
      return;
    }

    final resolvedAccountId = await _fkOrNull(
      'accounts',
      row['account_id'] as String?,
    );

    await _db
        .into(_db.goals)
        .insertOnConflictUpdate(
          GoalsCompanion(
            id: Value(id),
            name: Value(row['name'] as String? ?? ''),
            description: Value(row['description'] as String?),
            targetAmount: Value(row['target_amount'] as int? ?? 0),
            currentAmount: Value(row['current_amount'] as int? ?? 0),
            targetDate: Value(
              DateTime.tryParse(row['target_date'] as String? ?? ''),
            ),
            accountId: Value(resolvedAccountId),
            color: Value(row['color'] as String?),
            icon: Value(row['icon'] as String?),
            type: Value(row['type'] as String? ?? 'saving'),
            status: Value(row['status'] as String? ?? 'active'),
            isRecurring: Value(row['is_recurring'] as bool? ?? false),
            recurrenceFrequency: Value(row['recurrence_frequency'] as String?),
            periodStartDate: Value(
              DateTime.tryParse(row['period_start_date'] as String? ?? ''),
            ),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );

    final categoryIds = row['category_ids'];
    if (categoryIds is List) {
      final resolvedCategoryIds = <String>[];
      for (final catId in categoryIds.cast<String>()) {
        if (await _fkOrNull('categories', catId) != null) {
          resolvedCategoryIds.add(catId);
        }
      }
      await _db.goalsDao.setGoalCategories(id, resolvedCategoryIds);
    }
  }

  Future<void> _mergeCreditCardFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.creditCards,
    )..where((c) => c.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.creditCards)..where((c) => c.id.equals(id))).go();
      return;
    }

    final resolvedAccountId = await _fkOrNull(
      'accounts',
      row['account_id'] as String?,
    );

    await _db
        .into(_db.creditCards)
        .insertOnConflictUpdate(
          CreditCardsCompanion(
            id: Value(id),
            name: Value(row['name'] as String? ?? ''),
            limitAmount: Value(row['limit_amount'] as int? ?? 0),
            closingDay: Value(row['closing_day'] as int? ?? 5),
            dueDay: Value(row['due_day'] as int? ?? 10),
            accountId: Value(resolvedAccountId ?? ''),
            color: Value(row['color'] as String?),
            minPaymentPercent: Value(row['min_payment_percent'] as int? ?? 15),
            isArchived: Value(row['is_archived'] as bool? ?? false),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _mergeInvoiceFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.invoices,
    )..where((i) => i.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.invoices)..where((i) => i.id.equals(id))).go();
      return;
    }

    final resolvedCardId = await _fkOrNull(
      'credit_cards',
      row['credit_card_id'] as String?,
    );
    if (resolvedCardId == null) {
      debugPrint(
        '[Sync] Invoice $id ignorado: cartão de crédito não encontrado',
      );
      return;
    }

    await _db
        .into(_db.invoices)
        .insertOnConflictUpdate(
          InvoicesCompanion(
            id: Value(id),
            creditCardId: Value(resolvedCardId),
            month: Value(row['month'] as int? ?? 1),
            year: Value(row['year'] as int? ?? 2026),
            status: Value(row['status'] as String? ?? 'open'),
            closingDate: Value(
              DateTime.tryParse(row['closing_date'] as String? ?? '') ??
                  DateTime.now(),
            ),
            dueDate: Value(
              DateTime.tryParse(row['due_date'] as String? ?? '') ??
                  DateTime.now(),
            ),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _mergeRecurringRuleFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.recurringRules,
    )..where((r) => r.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(
        _db.recurringRules,
      )..where((r) => r.id.equals(id))).go();
      return;
    }

    final resolvedBaseTxId = await _fkOrNull(
      'transactions',
      row['base_transaction_id'] as String?,
    );
    if (resolvedBaseTxId == null) {
      debugPrint(
        '[Sync] Recurring rule $id ignorada: transação base não encontrada',
      );
      return;
    }

    await _db
        .into(_db.recurringRules)
        .insertOnConflictUpdate(
          RecurringRulesCompanion(
            id: Value(id),
            baseTransactionId: Value(resolvedBaseTxId),
            frequency: Value(row['frequency'] as String? ?? 'monthly'),
            interval: Value(row['interval'] as int? ?? 1),
            nextDate: Value(
              DateTime.tryParse(row['next_date'] as String? ?? '') ??
                  DateTime.now(),
            ),
            endDate: Value(DateTime.tryParse(row['end_date'] as String? ?? '')),
            status: Value(row['status'] as String? ?? 'active'),
            autoConfirm: Value(row['auto_confirm'] as bool? ?? false),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _mergeInstallmentPlanFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.installmentPlans,
    )..where((p) => p.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.createdAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(
        _db.installmentPlans,
      )..where((p) => p.id.equals(id))).go();
      return;
    }

    final resolvedOriginTxId = await _fkOrNull(
      'transactions',
      row['origin_transaction_id'] as String?,
    );
    if (resolvedOriginTxId == null) {
      debugPrint(
        '[Sync] Installment plan $id ignorado: transação de origem não encontrada',
      );
      return;
    }

    await _db
        .into(_db.installmentPlans)
        .insertOnConflictUpdate(
          InstallmentPlansCompanion(
            id: Value(id),
            originTransactionId: Value(resolvedOriginTxId),
            totalInstallments: Value(row['total_installments'] as int? ?? 1),
            installmentValue: Value(row['installment_value'] as int? ?? 0),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _mergeEntityFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.entities,
    )..where((e) => e.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.entities)..where((e) => e.id.equals(id))).go();
      return;
    }

    await _db
        .into(_db.entities)
        .insertOnConflictUpdate(
          EntitiesCompanion(
            id: Value(id),
            name: Value(row['name'] as String? ?? ''),
            type: Value(row['type'] as String? ?? 'payee'),
            category: Value(row['category'] as String?),
            useCount: Value(row['use_count'] as int? ?? 0),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _mergeFinancingFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.financings,
    )..where((f) => f.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(
        _db.financingInstallments,
      )..where((i) => i.financingId.equals(id))).go();
      await (_db.delete(_db.financings)..where((f) => f.id.equals(id))).go();
      return;
    }

    await _db
        .into(_db.financings)
        .insertOnConflictUpdate(
          FinancingsCompanion(
            id: Value(id),
            name: Value(row['name'] as String? ?? ''),
            totalAmount: Value(row['total_amount'] as int? ?? 0),
            outstandingBalance: Value(row['outstanding_balance'] as int? ?? 0),
            interestRate: Value(
              (row['interest_rate'] as num?)?.toDouble() ?? 0,
            ),
            totalInstallments: Value(row['total_installments'] as int? ?? 1),
            amortizationSystem: Value(
              row['amortization_system'] as String? ?? 'price',
            ),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );

    final rawInstallments = row['installments'];
    if (rawInstallments is List) {
      await (_db.delete(
        _db.financingInstallments,
      )..where((i) => i.financingId.equals(id))).go();
      for (final rawInst in rawInstallments.whereType<Map>()) {
        final inst = Map<String, dynamic>.from(rawInst);
        final dueDate = DateTime.tryParse(inst['due_date'] as String? ?? '');
        if (dueDate == null) continue;
        await _db
            .into(_db.financingInstallments)
            .insertOnConflictUpdate(
              FinancingInstallmentsCompanion.insert(
                id: inst['id'] as String? ?? const Uuid().v4(),
                financingId: id,
                number: inst['number'] as int? ?? 1,
                amortizationValue: inst['amortization_value'] as int? ?? 0,
                interestValue: inst['interest_value'] as int? ?? 0,
                totalValue: inst['total_value'] as int? ?? 0,
                remainingBalance: inst['remaining_balance'] as int? ?? 0,
                dueDate: dueDate,
                paidDate: Value(
                  DateTime.tryParse(inst['paid_date'] as String? ?? ''),
                ),
                createdAt: Value(
                  DateTime.tryParse(inst['created_at'] as String? ?? '') ??
                      DateTime.now(),
                ),
              ),
            );
      }
    }
  }

  Future<void> _mergeInvestmentFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.investments,
    )..where((i) => i.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.investments)..where((i) => i.id.equals(id))).go();
      return;
    }

    await _db
        .into(_db.investments)
        .insertOnConflictUpdate(
          InvestmentsCompanion(
            id: Value(id),
            name: Value(row['name'] as String? ?? ''),
            type: Value(row['type'] as String? ?? 'fixed_income'),
            investedAmount: Value(row['invested_amount'] as int? ?? 0),
            currentYield: Value(row['current_yield'] as int? ?? 0),
            maturityDate: Value(
              DateTime.tryParse(row['maturity_date'] as String? ?? ''),
            ),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );
  }

  Future<void> _mergeBudgetFromRemote(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    if (id == null) return;

    final local = await (_db.select(
      _db.budgets,
    )..where((b) => b.id.equals(id))).getSingleOrNull();

    final remoteUpdatedAt = DateTime.tryParse(
      row['updated_at'] as String? ?? '',
    );
    if (local != null && remoteUpdatedAt != null) {
      if (local.updatedAt.isAfter(remoteUpdatedAt)) return;
    }

    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (isDeleted) {
      await (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
      return;
    }

    final name = row['name'] as String? ?? 'Orçamento';

    // Suportar formato legado (category_id) e novo (category_ids).
    final categoryIdsRaw = row['category_ids'] as List<dynamic>?;
    final legacyCategoryId = row['category_id'] as String?;
    List<String> categoryIds;
    if (categoryIdsRaw != null) {
      categoryIds = categoryIdsRaw.cast<String>();
    } else if (legacyCategoryId != null) {
      categoryIds = [legacyCategoryId];
    } else {
      categoryIds = [];
    }

    // Validar que todas as categorias existem.
    final validCategoryIds = <String>[];
    for (final catId in categoryIds) {
      final resolved = await _fkOrNull('categories', catId);
      if (resolved != null) validCategoryIds.add(resolved);
    }

    await _db
        .into(_db.budgets)
        .insertOnConflictUpdate(
          BudgetsCompanion(
            id: Value(id),
            name: Value(name),
            year: Value(row['year'] as int? ?? DateTime.now().year),
            month: Value(row['month'] as int? ?? DateTime.now().month),
            amount: Value(row['amount'] as int? ?? 0),
            rolloverAmount: Value(row['rollover_amount'] as int? ?? 0),
            updatedAt: Value(remoteUpdatedAt ?? DateTime.now()),
            createdAt: Value(
              DateTime.tryParse(row['created_at'] as String? ?? '') ??
                  DateTime.now(),
            ),
          ),
        );

    // Sincronizar categorias na tabela pivô.
    await (_db.delete(_db.budgetCategories)
          ..where((bc) => bc.budgetId.equals(id)))
        .go();
    if (validCategoryIds.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAll(
          _db.budgetCategories,
          validCategoryIds
              .map((catId) => BudgetCategoriesCompanion.insert(
                    budgetId: id,
                    categoryId: catId,
                  ))
              .toList(),
        );
      });
    }
  }
}
