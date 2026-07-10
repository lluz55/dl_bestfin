import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory transport: pushRecords appends to [pushedRecords]; pullRecords
/// returns [remoteRecords] filtered by `since`.
class FakeTransport implements SyncTransport {
  final pushedRecords = <SyncRecord>[];
  final remoteRecords = <SyncRecord>[];

  @override
  SyncIdentity? identity = const SyncIdentity(
    publicKey:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );

  @override
  bool get isReady => identity != null;

  @override
  Uint8List? get masterKey => Uint8List(32);

  @override
  Stream<SyncIdentity?> get identityChanges => const Stream.empty();

  @override
  Stream<DevicePresenceInfo> get peerConnections => const Stream.empty();

  @override
  Map<String, RelayConnectionInfo> get relayStatuses => const {};

  @override
  Stream<Map<String, RelayConnectionInfo>> get relayStatusChanges =>
      const Stream.empty();

  @override
  Future<SyncIdentity?> loadIdentity() async => identity;

  @override
  Future<({SyncIdentity identity, String mnemonic})> createIdentity() =>
      throw UnimplementedError();

  @override
  Future<SyncIdentity> importIdentity(String mnemonic) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async => identity = null;

  @override
  Future<void> pushRecords(
    List<SyncRecord> records, {
    void Function(int sentCount, int bytesSent)? onProgress,
  }) async {
    pushedRecords.addAll(records);
    onProgress?.call(records.length, 0);
  }

  @override
  Future<List<SyncRecord>> pullRecords({
    required int since,
    void Function(int receivedCount, int bytesReceived)? onProgress,
  }) async {
    final result = remoteRecords.where((r) => r.updatedAt >= since).toList();
    onProgress?.call(result.length, 0);
    return result;
  }

  @override
  Future<void> pushPresence() async {}

  @override
  Future<void> replayUnpublished() async {}
}

void main() {
  late AppDatabase db;
  late FakeTransport transport;
  late SyncService service;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    transport = FakeTransport();
    service = SyncService(db, transport);
  });

  tearDown(() async {
    service.dispose();
    await db.close();
  });

  Future<void> seedLocalTransaction(String id, {String? accountId}) async {
    if (accountId != null) {
      await db
          .into(db.accounts)
          .insertOnConflictUpdate(
            AccountsCompanion.insert(
              id: accountId,
              name: 'Conta',
              type: 'checking',
              icon: const Value('wallet'),
              color: const Value('#000000'),
            ),
          );
    }
    await db
        .into(db.transactions)
        .insertOnConflictUpdate(
          TransactionsCompanion.insert(
            id: id,
            date: DateTime(2026, 1, 1),
            description: 'Mercado',
            type: 'expense',
          ),
        );
    if (accountId != null) {
      await db
          .into(db.entries)
          .insertOnConflictUpdate(
            EntriesCompanion.insert(
              id: '$id-entry',
              transactionId: id,
              accountId: accountId,
              amount: 1050,
              type: 'debit',
            ),
          );
    }
  }

  SyncRecord remoteTransaction(
    String id, {
    int updatedAt = 1000,
    String? categoryId,
    String? goalId,
    List<Map<String, dynamic>> entries = const [],
  }) {
    return SyncRecord(
      entityType: 'transaction',
      entityId: id,
      updatedAt: updatedAt,
      isDeleted: false,
      payload: jsonEncode({
        'id': id,
        'date': '2026-01-01T00:00:00.000',
        'description': 'Remota $id',
        'type': 'expense',
        'category_id': categoryId,
        'goal_id': goalId,
        'updated_at': '2026-01-01T00:00:00.000',
        'created_at': '2026-01-01T00:00:00.000',
        'entries': entries,
      }),
    );
  }

  group('backfill inicial', () {
    test('enfileira e envia dados que existiam antes do pareamento', () async {
      await seedLocalTransaction('tx-1', accountId: 'acc-1');
      final result = await service.syncNow();

      expect(result.success, isTrue);
      final types = transport.pushedRecords.map((r) => r.entityType).toList();
      expect(types, contains('transaction'));
      expect(types, contains('account'));

      final tx = transport.pushedRecords.firstWhere(
        (r) => r.entityType == 'transaction',
      );
      final payload = jsonDecode(tx.payload) as Map<String, dynamic>;
      expect(payload['id'], 'tx-1');
      expect((payload['entries'] as List), hasLength(1));
    });

    test('roda apenas uma vez por identidade', () async {
      await seedLocalTransaction('tx-1', accountId: 'acc-1');
      await service.syncNow();
      final firstCount = transport.pushedRecords.length;
      await service.syncNow();
      expect(transport.pushedRecords.length, firstCount);
    });
  });

  group('pull tolerante a FK', () {
    test(
      'transação com categoria/goal inexistentes é aplicada com refs nulas',
      () async {
        transport.remoteRecords.add(
          remoteTransaction(
            'tx-r1',
            categoryId: 'cat-inexistente',
            goalId: 'goal-inexistente',
          ),
        );

        final result = await service.pullRemoteChanges();
        expect(result.success, isTrue);
        expect(result.pulled, 1);

        final tx = await (db.select(
          db.transactions,
        )..where((t) => t.id.equals('tx-r1'))).getSingle();
        expect(tx.categoryId, isNull);
        expect(tx.goalId, isNull);
      },
    );

    test('um registro inválido não descarta os demais', () async {
      transport.remoteRecords.addAll([
        const SyncRecord(
          entityType: 'transaction',
          entityId: 'tx-bad',
          updatedAt: 999,
          isDeleted: false,
          payload: 'não é json',
        ),
        remoteTransaction('tx-ok', updatedAt: 1001),
      ]);

      final result = await service.pullRemoteChanges();
      expect(result.success, isTrue);
      expect(result.pulled, 1);
      expect(result.failed, 1);

      final ok = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('tx-ok'))).getSingleOrNull();
      expect(ok, isNotNull);
    });

    test('contas remotas são aplicadas com sucesso', () async {
      transport.remoteRecords.add(
        SyncRecord(
          entityType: 'account',
          entityId: 'acc-remote-1',
          updatedAt: 1000,
          isDeleted: false,
          payload: jsonEncode({
            'id': 'acc-remote-1',
            'name': 'Conta Digital',
            'type': 'checking',
            'icon': 'bank',
            'color': '#ff00ff',
            'is_archived': false,
            'updated_at': '2026-01-01T00:00:00.000',
            'created_at': '2026-01-01T00:00:00.000',
          }),
        ),
      );

      final result = await service.pullRemoteChanges();
      expect(result.success, isTrue);
      expect(result.pulled, 1);

      final acc = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals('acc-remote-1'))).getSingleOrNull();
      expect(acc, isNotNull);
      expect(acc!.name, 'Conta Digital');
      expect(acc.type, 'checking');
    });

    test('categorias são aplicadas antes das transações que as usam', () async {
      transport.remoteRecords.addAll([
        // Transação chega "antes" da categoria na lista bruta.
        remoteTransaction('tx-r2', updatedAt: 1002, categoryId: 'cat-1'),
        SyncRecord(
          entityType: 'category',
          entityId: 'cat-1',
          updatedAt: 1001,
          isDeleted: false,
          payload: jsonEncode({
            'id': 'cat-1',
            'name': 'Mercado',
            'icon': 'cart',
            'color': '#fff',
            'type': 'expense',
            'updated_at': '2026-01-01T00:00:00.000',
            'created_at': '2026-01-01T00:00:00.000',
          }),
        ),
      ]);

      final result = await service.pullRemoteChanges();
      expect(result.success, isTrue);
      expect(result.pulled, 2);

      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('tx-r2'))).getSingle();
      expect(tx.categoryId, 'cat-1');
    });

    test(
      'metas, cartões, faturas, regras recorrentes e contatos são aplicados com sucesso',
      () async {
        await seedLocalTransaction('tx-1', accountId: 'acc-1');

        transport.remoteRecords.addAll([
          SyncRecord(
            entityType: 'entity',
            entityId: 'ent-1',
            updatedAt: 1001,
            isDeleted: false,
            payload: jsonEncode({
              'id': 'ent-1',
              'name': 'João Silva',
              'type': 'payee',
              'updated_at': '2026-01-01T00:00:00.000',
              'created_at': '2026-01-01T00:00:00.000',
            }),
          ),
          SyncRecord(
            entityType: 'credit_card',
            entityId: 'cc-1',
            updatedAt: 1002,
            isDeleted: false,
            payload: jsonEncode({
              'id': 'cc-1',
              'name': 'Visa Platinum',
              'limit_amount': 500000,
              'closing_day': 5,
              'due_day': 10,
              'account_id': 'acc-1',
              'updated_at': '2026-01-01T00:00:00.000',
              'created_at': '2026-01-01T00:00:00.000',
            }),
          ),
          SyncRecord(
            entityType: 'invoice',
            entityId: 'inv-1',
            updatedAt: 1003,
            isDeleted: false,
            payload: jsonEncode({
              'id': 'inv-1',
              'credit_card_id': 'cc-1',
              'month': 7,
              'year': 2026,
              'status': 'open',
              'closing_date': '2026-07-05T00:00:00.000',
              'due_date': '2026-07-10T00:00:00.000',
              'updated_at': '2026-07-01T00:00:00.000',
              'created_at': '2026-07-01T00:00:00.000',
            }),
          ),
          SyncRecord(
            entityType: 'goal',
            entityId: 'goal-1',
            updatedAt: 1004,
            isDeleted: false,
            payload: jsonEncode({
              'id': 'goal-1',
              'name': 'Viagem',
              'target_amount': 200000,
              'current_amount': 0,
              'account_id': 'acc-1',
              'status': 'active',
              'updated_at': '2026-01-01T00:00:00.000',
              'created_at': '2026-01-01T00:00:00.000',
            }),
          ),
          SyncRecord(
            entityType: 'recurring_rule',
            entityId: 'rule-1',
            updatedAt: 1005,
            isDeleted: false,
            payload: jsonEncode({
              'id': 'rule-1',
              'base_transaction_id': 'tx-1',
              'frequency': 'monthly',
              'interval': 1,
              'next_date': '2026-08-01T00:00:00.000',
              'status': 'active',
              'updated_at': '2026-07-01T00:00:00.000',
              'created_at': '2026-07-01T00:00:00.000',
            }),
          ),
        ]);

        final result = await service.pullRemoteChanges();
        expect(result.success, isTrue);

        final ent = await (db.select(
          db.entities,
        )..where((e) => e.id.equals('ent-1'))).getSingleOrNull();
        expect(ent, isNotNull);
        expect(ent!.name, 'João Silva');

        final cc = await (db.select(
          db.creditCards,
        )..where((c) => c.id.equals('cc-1'))).getSingleOrNull();
        expect(cc, isNotNull);
        expect(cc!.name, 'Visa Platinum');

        final inv = await (db.select(
          db.invoices,
        )..where((i) => i.id.equals('inv-1'))).getSingleOrNull();
        expect(inv, isNotNull);
        expect(inv!.status, 'open');

        final gl = await (db.select(
          db.goals,
        )..where((g) => g.id.equals('goal-1'))).getSingleOrNull();
        expect(gl, isNotNull);
        expect(gl!.name, 'Viagem');

        final rule = await (db.select(
          db.recurringRules,
        )..where((r) => r.id.equals('rule-1'))).getSingleOrNull();
        expect(rule, isNotNull);
        expect(rule!.frequency, 'monthly');
      },
    );
  });

  group('versão de schema', () {
    test(
      'registro de versão mais nova é adiado, não aplicado, e marca updateRequired',
      () async {
        transport.remoteRecords.add(
          SyncRecord(
            entityType: 'transaction',
            entityId: 'tx-futuro',
            updatedAt: 1000,
            isDeleted: false,
            schemaVersion: kSyncSchemaVersion + 1,
            payload: jsonEncode({
              'id': 'tx-futuro',
              'date': '2026-01-01T00:00:00.000',
              'description': 'Do futuro',
              'type': 'expense',
              'updated_at': '2026-01-01T00:00:00.000',
              'created_at': '2026-01-01T00:00:00.000',
            }),
          ),
        );

        final result = await service.pullRemoteChanges();
        expect(result.success, isTrue);
        expect(result.pulled, 0);
        expect(result.deferred, 1);

        final tx = await (db.select(
          db.transactions,
        )..where((t) => t.id.equals('tx-futuro'))).getSingleOrNull();
        expect(tx, isNull);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt(
            'sync_incompatible_since_${transport.identity!.publicKey}',
          ),
          1000,
        );
      },
    );

    test('registro adiado é relido e aplicado quando volta em versão suportada, '
        'limpando o marcador', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 1º pull: evento de versão futura → adiado; o cursor avança mesmo assim.
      transport.remoteRecords.add(
        SyncRecord(
          entityType: 'transaction',
          entityId: 'tx-adiado',
          updatedAt: now - 7200, // fora da margem normal de releitura
          isDeleted: false,
          schemaVersion: kSyncSchemaVersion + 1,
          payload: '{}',
        ),
      );
      await service.pullRemoteChanges();

      // Simula o app atualizado: o mesmo evento agora decodifica na versão
      // suportada (na prática, o build novo entende o payload novo).
      transport.remoteRecords.clear();
      transport.remoteRecords.add(
        remoteTransaction('tx-adiado', updatedAt: now - 7200),
      );

      // 2º pull: sem o marcador, `since` excluiria o evento (7200s > margem
      // de 3600s). O marcador força a janela de volta até ele.
      final result = await service.pullRemoteChanges();
      expect(result.pulled, 1);
      expect(result.deferred, 0);

      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('tx-adiado'))).getSingleOrNull();
      expect(tx, isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          'sync_incompatible_since_${transport.identity!.publicKey}',
        ),
        isNull,
      );
    });
  });

  group('cursor de pull', () {
    test(
      'cursor acompanha o relógio local, não o createdAt do evento',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Um par com relógio ADIANTADO publica um evento no "futuro".
        transport.remoteRecords.add(
          remoteTransaction('tx-fast', updatedAt: now + 1800),
        );
        await service.pullRemoteChanges();

        final prefs = await SharedPreferences.getInstance();
        final cursor = prefs.getInt(
          'sync_pull_cursor_${transport.identity!.publicKey}',
        )!;
        // O cursor é o relógio local no início do pull — nunca salta para o
        // createdAt futuro do evento (que era o bug que tornava o sync
        // unidirecional).
        expect(cursor, greaterThanOrEqualTo(now));
        expect(cursor, lessThan(now + 1800));
      },
    );

    test('evento de par com relógio atrasado ainda é capturado após um par '
        'adiantado (sync não fica unidirecional)', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 1º pull: vê o evento do par adiantado. Sob o cursor antigo
      // (event-time) o cursor saltaria para now+1800.
      transport.remoteRecords.add(
        remoteTransaction('tx-fast', updatedAt: now + 1800),
      );
      await service.pullRemoteChanges();

      // 2º pull: um par com relógio levemente ATRASADO publica um evento.
      // Sob o cursor antigo, `since = (now+1800) - overlap` o excluiria para
      // sempre. Com o cursor ancorado no relógio local, ele é capturado.
      transport.remoteRecords.add(
        remoteTransaction('tx-slow', updatedAt: now - 60),
      );
      final result = await service.pullRemoteChanges();
      expect(result.pulled, greaterThanOrEqualTo(1));

      final tx = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('tx-slow'))).getSingleOrNull();
      expect(tx, isNotNull);
    });
  });
}
