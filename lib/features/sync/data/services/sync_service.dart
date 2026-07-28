import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/sync_transport.dart';
import 'package:bestfin/features/sync/data/services/remote_entity_merger.dart';
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
  late final RemoteEntityMerger _merger = RemoteEntityMerger(_db);
  bool _syncing = false;

  static const _lastSyncKey = 'sync_last_synced_at';
  static const _pullCursorKeyPrefix = 'sync_pull_cursor_';
  static const _backfillDoneKeyPrefix = 'sync_backfill_done_';
  static const _incompatibleSinceKeyPrefix = 'sync_incompatible_since_';

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

            await _transport.pushRecords([
              SyncRecord(
                entityType: item.entityType,
                entityId: item.entityId,
                payload: item.payload,
                updatedAt: item.createdAt.millisecondsSinceEpoch ~/ 1000,
                isDeleted: item.operation == 'delete',
              ),
            ], onProgress: (_, itemBytes) => bytesSent += itemBytes);

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
    var since = cursor <= _clockSkewMarginSeconds
        ? 0
        : cursor - _clockSkewMarginSeconds;

    // Records written by a peer on a newer app (higher schema version) are
    // deferred, not applied — merging them here would drop the fields this
    // build doesn't know about, and the next local edit would republish that
    // truncated snapshot to every peer. The relay itself is the buffer:
    // replaceable events persist there, so it's enough to remember the
    // earliest deferred timestamp and keep re-reading from it until an
    // updated build can finally apply everything.
    final incompatibleSince = await _getIncompatibleSince();
    if (incompatibleSince != null) {
      final rereadFrom = incompatibleSince <= _clockSkewMarginSeconds
          ? 0
          : incompatibleSince - _clockSkewMarginSeconds;
      since = min(since, rereadFrom);
    }

    int pulled = 0;
    int failed = 0;
    int deferred = 0;
    int? earliestDeferredAt;

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
        if (record.schemaVersion > kSyncSchemaVersion) {
          deferred++;
          earliestDeferredAt = earliestDeferredAt == null
              ? record.updatedAt
              : min(earliestDeferredAt, record.updatedAt);
          continue;
        }
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
          if (!await _merger.apply(record.entityType, row)) {
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

      if (deferred > 0) {
        await _saveIncompatibleSince(
          incompatibleSince == null
              ? earliestDeferredAt
              : min(incompatibleSince, earliestDeferredAt!),
        );
        debugPrint(
          '[Sync] $deferred registros publicados por uma versão mais nova do '
          'app foram adiados — atualize o app para aplicá-los.',
        );
      } else if (incompatibleSince != null) {
        // Everything inside the re-read window applied cleanly — this build
        // now understands all published records, stop re-reading.
        await _saveIncompatibleSince(null);
      }

      await _savePullCursor(pullStartedAt);
      await _updateLastSyncAt();
    } catch (e, st) {
      debugPrint('[Sync] Falha ao buscar mudanças remotas: $e\n$st');
      return SyncResult.error;
    }

    return SyncResult.completed(
      pushed: 0,
      failed: failed,
      pulled: pulled,
      deferred: deferred,
    );
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
      const SyncProgress(
        phase: 'Baixando atualizações...',
        kind: SyncPhaseKind.pull,
      ),
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
      // Buscar categorias do orçamento.
      final catRows = await (_db.select(_db.budgetCategories)
            ..where((bc) => bc.budgetId.equals(b.id)))
          .get();
      final categoryIds = catRows.map((r) => r.categoryId).toList();

      await enqueue(
        operation: 'update',
        entityType: 'budget',
        entityId: b.id,
        payload: {
          'id': b.id,
          'name': b.name,
          'category_ids': categoryIds,
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
          'group_id': tx.groupId,
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

  /// Event timestamp (unix seconds) of the earliest record deferred because
  /// it was published with a schema version above this build's. Null when
  /// nothing is deferred. Namespaced by identity, like the pull cursor.
  Future<int?> _getIncompatibleSince() async {
    final pubkey = _transport.identity?.publicKey;
    if (pubkey == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_incompatibleSinceKeyPrefix$pubkey');
  }

  Future<void> _saveIncompatibleSince(int? value) async {
    final pubkey = _transport.identity?.publicKey;
    if (pubkey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_incompatibleSinceKeyPrefix$pubkey';
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setInt(key, value);
    }
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

  /// Records skipped because a peer published them with a newer schema
  /// version than this build supports. They stay on the relays and are
  /// re-read on every pull until the app is updated.
  final int deferred;

  final String? errorMessage;

  const SyncResult._({
    required this.success,
    this.pushed = 0,
    this.pulled = 0,
    this.failed = 0,
    this.deferred = 0,
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
    int deferred = 0,
  }) => SyncResult._(
    success: true,
    pushed: pushed,
    pulled: pulled,
    failed: failed,
    deferred: deferred,
  );
}
