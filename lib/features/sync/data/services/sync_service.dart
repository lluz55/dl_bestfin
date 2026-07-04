import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Offline-first sync service.
///
/// Flow:
/// 1. Local changes are enqueued in sync_queue (insert/update/delete)
/// 2. processSyncQueue() encrypts and publishes pending items via SyncTransport
/// 3. pullRemoteChanges() fetches records since lastSyncAt from the transport
///    and upserts them into the local Drift DB
/// 4. Conflict resolution: last-write-wins based on updated_at
class SyncService {
  final AppDatabase _db;
  final SyncTransport _transport;
  bool _syncing = false;

  static const _lastSyncKey = 'sync_last_synced_at';
  static const _pullCursorKeyPrefix = 'sync_pull_cursor_';
  static const _backfillDoneKeyPrefix = 'sync_backfill_done_';

  // How far back each pull re-reads relative to the stored cursor. The cursor
  // is this device's own wall clock at the previous pull (see pullRemoteChanges),
  // so this margin only needs to cover the clock skew between devices — not
  // event history. Merges are idempotent (last-write-wins), so re-applying
  // events inside the margin on every pull is safe; the only cost is
  // re-downloading events published within the last hour. One hour tolerates
  // any realistic skew between two personal devices while keeping that
  // re-download bounded (replaceable events mean the relay holds at most one
  // event per entity).
  static const _clockSkewMarginSeconds = 3600;

  SyncService(this._db, this._transport);

  // ── Queue management ──────────────────────────────────────────────────────

  Future<void> enqueue({
    required String operation,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.syncQueueDao.enqueue(
      id: const Uuid().v4(),
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      payload: jsonEncode(payload),
    );
  }

  // ── Push (local → remote) ─────────────────────────────────────────────────

  Future<SyncResult> processSyncQueue({
    void Function(int sent, int total, int bytesSent)? onProgress,
    int? totalItems,
  }) async {
    if (!_transport.isReady) return SyncResult.notConfigured;
    if (_syncing) return SyncResult.alreadyRunning;
    _syncing = true;

    int pushed = 0;
    int failed = 0;
    int bytesSent = 0;

    try {
      // Drain the queue in batches (getPendingItems is capped) so a large
      // backlog — e.g. the initial backfill — goes out in a single sync
      // instead of one small batch per timer tick.
      final failedIds = <String>{};
      while (true) {
        final items = await _db.syncQueueDao.getPendingItems();
        final batch = items.where((i) => !failedIds.contains(i.id)).toList();
        if (batch.isEmpty) break;

        // Multiple queued versions of the same entity would be published with
        // the same createdAt second, letting the relay's replaceable-event
        // tie-break keep a stale version. Payloads are full snapshots, so only
        // the newest item per entity needs publishing.
        final latestPerEntity = <String, SyncQueueItem>{};
        for (final item in batch) {
          latestPerEntity['${item.entityType}/${item.entityId}'] = item;
        }

        for (final item in batch) {
          try {
            final isLatest =
                latestPerEntity['${item.entityType}/${item.entityId}']?.id ==
                item.id;
            if (!_isSupportedEntity(item.entityType) || !isLatest) {
              await _db.syncQueueDao.markSynced(item.id);
              pushed++;
              onProgress?.call(pushed, totalItems ?? batch.length, bytesSent);
              continue;
            }

            await _transport.pushRecords(
              [
                SyncRecord(
                  entityType: item.entityType,
                  entityId: item.entityId,
                  payload: item.payload,
                  updatedAt: item.createdAt.millisecondsSinceEpoch ~/ 1000,
                  isDeleted: item.operation == 'delete',
                ),
              ],
              onProgress: (_, itemBytes) => bytesSent += itemBytes,
            );

            await _db.syncQueueDao.markSynced(item.id);
            pushed++;
            onProgress?.call(pushed, totalItems ?? batch.length, bytesSent);
          } catch (e, st) {
            debugPrint(
              '[Sync] Falha ao enviar ${item.entityType}/${item.entityId} '
              '(tentativa ${item.attempts + 1}): $e\n$st',
            );
            await _db.syncQueueDao.incrementAttempts(item.id);
            failedIds.add(item.id);
            failed++;
            pushed++;
            onProgress?.call(pushed, totalItems ?? batch.length, bytesSent);
          }
        }

        // Only clear items confirmed published; unpublished remain in event
        // log for replay. The queue itself is cleared after marking synced.
        await _db.syncQueueDao.clearSynced();
      }
    } finally {
      _syncing = false;
    }

    return SyncResult.completed(pushed: pushed, failed: failed);
  }

  // ── Pull (remote → local) ─────────────────────────────────────────────────

  Future<SyncResult> pullRemoteChanges({
    void Function(int received, int bytesReceived)? onProgress,
  }) async {
    if (!_transport.isReady) return SyncResult.notConfigured;

    // The cursor is stored in THIS device's wall-clock time (seconds), captured
    // at the start of each successful pull — never the maximum event timestamp
    // we observed. An event-time cursor ratchets forward to the highest
    // `created_at` returned, so a single peer whose clock runs fast dragged the
    // cursor into the future and the `since` filter then permanently excluded
    // every event published by a slower-clocked peer: sync silently went
    // one-directional (peer-with-fast-clock → everyone else, never back).
    //
    // Anchoring the cursor to our own clock decouples it from peer clocks — the
    // window only ever advances at our own pace, and `_clockSkewMarginSeconds`
    // of look-back absorbs the difference between our clock and a peer's when
    // deciding how far back to re-read. The cursor is namespaced by identity so
    // importing a different mnemonic starts from zero instead of inheriting the
    // previous identity's position.
    //
    // Captured before the network round-trip so any event a peer publishes
    // during this pull is still caught on the next one.
    final pullStartedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cursor = await _getPullCursor();
    final since = cursor <= _clockSkewMarginSeconds
        ? 0
        : cursor - _clockSkewMarginSeconds;
    int pulled = 0;
    int failed = 0;

    try {
      final records = await _transport.pullRecords(
        since: since,
        onProgress: onProgress,
      );
      // Categories and accounts must merge before transactions: foreign_keys
      // is ON and transactions/entries reference them.
      final sorted = [...records]
        ..sort((a, b) {
          final byType = _mergePriority(
            a.entityType,
          ).compareTo(_mergePriority(b.entityType));
          if (byType != 0) return byType;
          return a.updatedAt.compareTo(b.updatedAt);
        });

      for (final record in sorted) {
        try {
          final row = jsonDecode(record.payload) as Map<String, dynamic>;
          row['id'] ??= record.entityId;
          row['is_deleted'] = record.isDeleted;
          // Prefer the entity's own updated_at from the payload (accurate edit
          // time). Fall back to the Nostr event timestamp only when absent
          // (e.g. delete tombstones that contain only {id}).
          row.putIfAbsent(
            'updated_at',
            () => DateTime.fromMillisecondsSinceEpoch(
              record.updatedAt * 1000,
            ).toIso8601String(),
          );
          switch (record.entityType) {
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
              continue;
          }
          pulled++;
        } catch (e, st) {
          // One bad record must not abort the whole pull — before this guard a
          // single FK violation discarded every other pulled record.
          failed++;
          debugPrint(
            '[Sync] Falha ao aplicar ${record.entityType}/'
            '${record.entityId}: $e\n$st',
          );
        }
      }

      await _savePullCursor(pullStartedAt);
      await _updateLastSyncAt();
    } catch (e, st) {
      debugPrint('[Sync] Falha ao buscar mudanças remotas: $e\n$st');
      return SyncResult.error;
    }

    return SyncResult.completed(pushed: 0, failed: failed, pulled: pulled);
  }

  static int _mergePriority(String entityType) {
    switch (entityType) {
      case 'category':
      case 'account':
      case 'entity':
        return 0;
      case 'goal':
      case 'credit_card':
      case 'budget':
        return 1;
      case 'invoice':
      case 'recurring_rule':
      case 'installment_plan':
        return 2;
      default:
        return 3;
    }
  }

  // ── Bidirectional sync ────────────────────────────────────────────────────

  Future<SyncResult> syncNow({void Function(SyncProgress)? onProgress}) async {
    if (!_transport.isReady) return SyncResult.notConfigured;

    // replayUnpublished() is the first call that actually opens the relay
    // websockets (lazy-connected on first use) — announce it explicitly so
    // the UI doesn't sit on a stale phase text while the handshake happens.
    onProgress?.call(const SyncProgress(phase: 'Conectando aos relays...'));

    try {
      onProgress?.call(const SyncProgress(phase: 'Reenviando pendentes...'));
      await _transport.replayUnpublished();
    } catch (e, st) {
      debugPrint('[Sync] Falha ao reenviar eventos pendentes: $e\n$st');
    }

    try {
      onProgress?.call(const SyncProgress(phase: 'Anunciando presença...'));
      await _transport.pushPresence();
    } catch (e, st) {
      debugPrint('[Sync] Falha ao publicar presença do dispositivo: $e\n$st');
    }

    try {
      onProgress?.call(
        const SyncProgress(phase: 'Preparando dados iniciais...'),
      );
      await _ensureBackfill();
    } catch (e, st) {
      debugPrint('[Sync] Falha ao enfileirar backfill inicial: $e\n$st');
    }

    // Count pending items for progress reporting.
    final pendingItems = await _db.syncQueueDao.getPendingItems();
    final totalPending = pendingItems.length;

    onProgress?.call(
      SyncProgress(
        phase: 'Enviando alterações...',
        kind: SyncPhaseKind.push,
        itemsTotal: totalPending,
      ),
    );
    final pushResult = await processSyncQueue(
      onProgress: (sent, total, bytesSent) {
        onProgress?.call(
          SyncProgress(
            phase: 'Enviando alterações...',
            kind: SyncPhaseKind.push,
            itemsDone: sent,
            itemsTotal: total,
            bytesDone: bytesSent,
          ),
        );
      },
      totalItems: totalPending,
    );
    if (pushResult == SyncResult.notConfigured) return pushResult;

    onProgress?.call(
      const SyncProgress(phase: 'Baixando atualizações...', kind: SyncPhaseKind.pull),
    );
    return pullRemoteChanges(
      onProgress: (received, bytesReceived) {
        onProgress?.call(
          SyncProgress(
            phase: 'Baixando atualizações...',
            kind: SyncPhaseKind.pull,
            itemsDone: received,
            bytesDone: bytesReceived,
          ),
        );
      },
    );
  }

  // ── Initial backfill ──────────────────────────────────────────────────────

  /// Data that existed before the identity was configured never went through
  /// the repositories' enqueue hooks, so peers would only ever receive changes
  /// made after pairing. Runs once per identity: snapshots every category,
  /// account and transaction into the sync queue.
  Future<void> _ensureBackfill() async {
    final pubkey = _transport.identity?.publicKey;
    if (pubkey == null) return;

    final prefs = await SharedPreferences.getInstance();
    final doneKey = '$_backfillDoneKeyPrefix$pubkey';
    if (prefs.getBool(doneKey) ?? false) return;

    final categories = await _db.select(_db.categories).get();
    for (final c in categories) {
      final relationships = await (_db.select(
        _db.categoryParents,
      )..where((r) => r.parentCategoryId.equals(c.id))).get();
      await enqueue(
        operation: 'update',
        entityType: 'category',
        entityId: c.id,
        payload: {
          'id': c.id,
          'name': c.name,
          'icon': c.icon,
          'color': c.color,
          'type': c.type,
          'is_system': c.isSystem,
          'parent_id': c.parentId,
          'is_archived': c.isArchived,
          'description': c.description,
          'created_at': c.createdAt.toIso8601String(),
          'updated_at': c.updatedAt.toIso8601String(),
          'child_ids': relationships.map((r) => r.childCategoryId).toList(),
        },
      );
    }

    final accounts = await _db.select(_db.accounts).get();
    for (final a in accounts) {
      await enqueue(
        operation: 'update',
        entityType: 'account',
        entityId: a.id,
        payload: {
          'id': a.id,
          'name': a.name,
          'type': a.type,
          'icon': a.icon,
          'color': a.color,
          'is_archived': a.isArchived,
          'created_at': a.createdAt.toIso8601String(),
          'updated_at': a.updatedAt.toIso8601String(),
        },
      );
    }

    final goals = await _db.select(_db.goals).get();
    for (final g in goals) {
      final categoryIds = await _db.goalsDao.getGoalCategoryIds(g.id);
      await enqueue(
        operation: 'update',
        entityType: 'goal',
        entityId: g.id,
        payload: {
          'id': g.id,
          'name': g.name,
          'description': g.description,
          'target_amount': g.targetAmount,
          'current_amount': g.currentAmount,
          'target_date': g.targetDate?.toIso8601String(),
          'account_id': g.accountId,
          'color': g.color,
          'icon': g.icon,
          'type': g.type,
          'status': g.status,
          'is_recurring': g.isRecurring,
          'recurrence_frequency': g.recurrenceFrequency,
          'period_start_date': g.periodStartDate?.toIso8601String(),
          'created_at': g.createdAt.toIso8601String(),
          'updated_at': g.updatedAt.toIso8601String(),
          'category_ids': categoryIds,
        },
      );
    }

    final creditCards = await _db.select(_db.creditCards).get();
    for (final cc in creditCards) {
      await enqueue(
        operation: 'update',
        entityType: 'credit_card',
        entityId: cc.id,
        payload: {
          'id': cc.id,
          'name': cc.name,
          'limit_amount': cc.limitAmount,
          'closing_day': cc.closingDay,
          'due_day': cc.dueDay,
          'account_id': cc.accountId,
          'color': cc.color,
          'min_payment_percent': cc.minPaymentPercent,
          'is_archived': cc.isArchived,
          'created_at': cc.createdAt.toIso8601String(),
          'updated_at': cc.updatedAt.toIso8601String(),
        },
      );
    }

    final invoices = await _db.select(_db.invoices).get();
    for (final i in invoices) {
      await enqueue(
        operation: 'update',
        entityType: 'invoice',
        entityId: i.id,
        payload: {
          'id': i.id,
          'credit_card_id': i.creditCardId,
          'month': i.month,
          'year': i.year,
          'status': i.status,
          'closing_date': i.closingDate.toIso8601String(),
          'due_date': i.dueDate.toIso8601String(),
          'created_at': i.createdAt.toIso8601String(),
          'updated_at': i.updatedAt.toIso8601String(),
        },
      );
    }

    final recurringRules = await _db.select(_db.recurringRules).get();
    for (final r in recurringRules) {
      await enqueue(
        operation: 'update',
        entityType: 'recurring_rule',
        entityId: r.id,
        payload: {
          'id': r.id,
          'base_transaction_id': r.baseTransactionId,
          'frequency': r.frequency,
          'interval': r.interval,
          'next_date': r.nextDate.toIso8601String(),
          'end_date': r.endDate?.toIso8601String(),
          'status': r.status,
          'auto_confirm': r.autoConfirm,
          'created_at': r.createdAt.toIso8601String(),
          'updated_at': r.updatedAt.toIso8601String(),
        },
      );
    }

    final installmentPlans = await _db.select(_db.installmentPlans).get();
    for (final ip in installmentPlans) {
      await enqueue(
        operation: 'update',
        entityType: 'installment_plan',
        entityId: ip.id,
        payload: {
          'id': ip.id,
          'origin_transaction_id': ip.originTransactionId,
          'total_installments': ip.totalInstallments,
          'installment_value': ip.installmentValue,
          'created_at': ip.createdAt.toIso8601String(),
          'updated_at': ip.createdAt.toIso8601String(),
        },
      );
    }

    final entities = await _db.select(_db.entities).get();
    for (final e in entities) {
      await enqueue(
        operation: 'update',
        entityType: 'entity',
        entityId: e.id,
        payload: {
          'id': e.id,
          'name': e.name,
          'type': e.type,
          'category': e.category,
          'use_count': e.useCount,
          'created_at': e.createdAt.toIso8601String(),
          'updated_at': e.updatedAt.toIso8601String(),
        },
      );
    }

    final investments = await _db.select(_db.investments).get();
    for (final inv in investments) {
      await enqueue(
        operation: 'update',
        entityType: 'investment',
        entityId: inv.id,
        payload: {
          'id': inv.id,
          'name': inv.name,
          'type': inv.type,
          'invested_amount': inv.investedAmount,
          'current_yield': inv.currentYield,
          'maturity_date': inv.maturityDate?.toIso8601String(),
          'created_at': inv.createdAt.toIso8601String(),
          'updated_at': inv.updatedAt.toIso8601String(),
        },
      );
    }

    final budgets = await _db.select(_db.budgets).get();
    for (final b in budgets) {
      await enqueue(
        operation: 'update',
        entityType: 'budget',
        entityId: b.id,
        payload: {
          'id': b.id,
          'category_id': b.categoryId,
          'year': b.year,
          'month': b.month,
          'amount': b.amount,
          'rollover_amount': b.rolloverAmount,
          'created_at': b.createdAt.toIso8601String(),
          'updated_at': b.updatedAt.toIso8601String(),
        },
      );
    }

    final financingInstallmentsByFin = <String, List<FinancingInstallment>>{};
    for (final inst in await _db.select(_db.financingInstallments).get()) {
      financingInstallmentsByFin
          .putIfAbsent(inst.financingId, () => [])
          .add(inst);
    }
    final financings = await _db.select(_db.financings).get();
    for (final f in financings) {
      await enqueue(
        operation: 'update',
        entityType: 'financing',
        entityId: f.id,
        payload: {
          'id': f.id,
          'name': f.name,
          'total_amount': f.totalAmount,
          'outstanding_balance': f.outstandingBalance,
          'interest_rate': f.interestRate,
          'total_installments': f.totalInstallments,
          'amortization_system': f.amortizationSystem,
          'created_at': f.createdAt.toIso8601String(),
          'updated_at': f.updatedAt.toIso8601String(),
          'installments': (financingInstallmentsByFin[f.id] ?? const [])
              .map(
                (i) => <String, dynamic>{
                  'id': i.id,
                  'number': i.number,
                  'amortization_value': i.amortizationValue,
                  'interest_value': i.interestValue,
                  'total_value': i.totalValue,
                  'remaining_balance': i.remainingBalance,
                  'due_date': i.dueDate.toIso8601String(),
                  'paid_date': i.paidDate?.toIso8601String(),
                  'created_at': i.createdAt.toIso8601String(),
                },
              )
              .toList(),
        },
      );
    }

    final entriesByTx = <String, List<Entry>>{};
    for (final entry in await _db.select(_db.entries).get()) {
      entriesByTx.putIfAbsent(entry.transactionId, () => []).add(entry);
    }
    final splitsByTx = <String, List<TransactionSplit>>{};
    for (final split in await _db.select(_db.transactionSplits).get()) {
      splitsByTx.putIfAbsent(split.transactionId, () => []).add(split);
    }

    final transactions = await _db.select(_db.transactions).get();
    for (final tx in transactions) {
      await enqueue(
        operation: 'update',
        entityType: 'transaction',
        entityId: tx.id,
        payload: {
          'id': tx.id,
          'date': tx.date.toIso8601String(),
          'description': tx.description,
          'type': tx.type,
          'sentiment': tx.sentiment,
          'notes': tx.notes,
          'category_id': tx.categoryId,
          'entity_id': tx.entityId,
          'goal_id': tx.goalId,
          'installment_plan_id': tx.installmentPlanId,
          'installment_number': tx.installmentNumber,
          'recurring_rule_id': tx.recurringRuleId,
          'credit_card_id': tx.creditCardId,
          'raw_amount': tx.rawAmount,
          'invoice_id': tx.invoiceId,
          'is_completed': tx.isCompleted,
          'is_confirmed': tx.isConfirmed,
          'source': tx.source,
          'created_at': tx.createdAt.toIso8601String(),
          'updated_at': tx.updatedAt.toIso8601String(),
          'entries': (entriesByTx[tx.id] ?? const [])
              .map(
                (entry) => <String, dynamic>{
                  'id': entry.id,
                  'transaction_id': entry.transactionId,
                  'account_id': entry.accountId,
                  'amount': entry.amount,
                  'type': entry.type,
                  'created_at': entry.createdAt.toIso8601String(),
                },
              )
              .toList(),
          'splits': (splitsByTx[tx.id] ?? const [])
              .map(
                (split) => <String, dynamic>{
                  'id': split.id,
                  'transaction_id': split.transactionId,
                  'category_id': split.categoryId,
                  'amount': split.amount,
                  'description': split.description,
                },
              )
              .toList(),
        },
      );
    }

    await prefs.setBool(doneKey, true);
    debugPrint(
      '[Sync] Backfill inicial enfileirado: ${categories.length} categorias, '
      '${accounts.length} contas, ${transactions.length} transações, '
      '${goals.length} metas, ${creditCards.length} cartões, '
      '${invoices.length} faturas, ${recurringRules.length} regras recorrentes, '
      '${installmentPlans.length} parcelamentos, ${entities.length} contatos, '
      '${investments.length} investimentos, ${budgets.length} orçamentos, '
      '${financings.length} financiamentos',
    );
  }

  void dispose() {}

  void stopAutoSync() {}

  // ── Merge helpers ─────────────────────────────────────────────────────────

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

    final resolvedCategoryId = await _fkOrNull(
      'categories',
      row['category_id'] as String?,
    );
    if (resolvedCategoryId == null) {
      debugPrint('[Sync] Budget $id ignorado: categoria não encontrada');
      return;
    }

    await _db
        .into(_db.budgets)
        .insertOnConflictUpdate(
          BudgetsCompanion(
            id: Value(id),
            categoryId: Value(resolvedCategoryId),
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
  }

  bool _isSupportedEntity(String entityType) {
    switch (entityType) {
      case 'transaction':
      case 'account':
      case 'category':
      case 'goal':
      case 'credit_card':
      case 'invoice':
      case 'recurring_rule':
      case 'installment_plan':
      case 'entity':
      case 'financing':
      case 'investment':
      case 'budget':
        return true;
      default:
        return false;
    }
  }

  Future<int> _getPullCursor() async {
    final pubkey = _transport.identity?.publicKey;
    if (pubkey == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_pullCursorKeyPrefix$pubkey') ?? 0;
  }

  /// Persists [localPulledAtSeconds] — this device's wall clock (unix seconds)
  /// at the moment the pull began. Stored per identity. Both the old event-time
  /// cursor and this one are unix-epoch seconds, so upgrading in place needs no
  /// migration: a previously stored event timestamp is simply treated as a
  /// (roughly recent) local time on the next pull.
  Future<void> _savePullCursor(int localPulledAtSeconds) async {
    final pubkey = _transport.identity?.publicKey;
    if (pubkey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_pullCursorKeyPrefix$pubkey', localPulledAtSeconds);
  }

  Future<void> _updateLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_lastSyncKey);
    if (stored == null) return null;
    return DateTime.tryParse(stored);
  }
}

enum SyncPhaseKind { other, push, pull }

/// Progress snapshot emitted during [SyncService.syncNow]. [itemsTotal] is 0
/// during the pull phase — the relay page count isn't known ahead of time —
/// so consumers should fall back to showing [bytesDone] as a running total
/// instead of a percentage when [kind] is [SyncPhaseKind.pull].
class SyncProgress {
  final String phase;
  final SyncPhaseKind kind;
  final int itemsDone;
  final int itemsTotal;
  final int bytesDone;

  const SyncProgress({
    required this.phase,
    this.kind = SyncPhaseKind.other,
    this.itemsDone = 0,
    this.itemsTotal = 0,
    this.bytesDone = 0,
  });
}

class SyncResult {
  final bool success;
  final int pushed;
  final int pulled;
  final int failed;
  final String? errorMessage;

  const SyncResult._({
    required this.success,
    this.pushed = 0,
    this.pulled = 0,
    this.failed = 0,
    this.errorMessage,
  });

  static const notConfigured = SyncResult._(
    success: false,
    errorMessage: 'Sincronização não configurada ou identidade não carregada',
  );

  static const alreadyRunning = SyncResult._(
    success: false,
    errorMessage: 'Sincronização já em progresso',
  );

  static const error = SyncResult._(
    success: false,
    errorMessage: 'Erro ao sincronizar',
  );

  static const timeout = SyncResult._(
    success: false,
    errorMessage: 'Tempo limite excedido ao conectar aos relays',
  );

  static SyncResult completed({
    required int pushed,
    required int failed,
    int pulled = 0,
  }) => SyncResult._(
    success: true,
    pushed: pushed,
    pulled: pulled,
    failed: failed,
  );
}
