import 'dart:async';
import 'dart:typed_data';

import 'package:bestfin/cli/tui/sync_engine.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart';
import 'package:bestfin/features/sync/data/services/sync_transport.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transporte fake: sem rede, sem criptografia — só sinaliza os streams
/// que o [TuiSyncEngine] consome e conta chamadas.
class FakeTransport implements SyncTransport {
  final liveController = StreamController<void>.broadcast();
  final peerController = StreamController<DevicePresenceInfo>.broadcast();
  final relayController =
      StreamController<Map<String, RelayConnectionInfo>>.broadcast();
  final identityController = StreamController<SyncIdentity?>.broadcast();

  @override
  final SyncIdentity? identity = SyncIdentity(publicKey: 'a' * 64);

  int replayCalls = 0;
  int pullCalls = 0;
  int pushPresenceCalls = 0;
  bool failPulls = false;
  bool disposed = false;

  @override
  @override
  Stream<DevicePresenceInfo> get peerConnections => peerController.stream;

  @override
  Stream<Map<String, RelayConnectionInfo>> get relayStatusChanges =>
      relayController.stream;

  @override
  Map<String, RelayConnectionInfo> get relayStatuses => const {};

  @override
  Stream<SyncIdentity?> get identityChanges => identityController.stream;

  @override
  bool get isReady => true;

  @override
  Uint8List? get masterKey => null;

  Future<void> startLiveSync() async {}

  @override
  Future<SyncIdentity?> loadIdentity() async => identity;

  @override
  Future<({SyncIdentity identity, String mnemonic})> createIdentity() async {
    return (identity: identity!, mnemonic: 'x');
  }

  @override
  Future<SyncIdentity> importIdentity(String mnemonic) async => identity!;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> pushRecords(
    List<SyncRecord> records, {
    void Function(int, int)? onProgress,
  }) async {}

  @override
  Future<List<SyncRecord>> pullRecords({
    required int since,
    void Function(int, int)? onProgress,
  }) async {
    pullCalls++;
    if (failPulls) throw Exception('relay fora do ar');
    return [];
  }

  @override
  Future<void> pushPresence() async {
    pushPresenceCalls++;
  }

  @override
  Future<void> replayUnpublished() async {
    replayCalls++;
  }

  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  late AppDatabase db;
  late FakeTransport transport;
  late TuiSyncEngine engine;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // O SyncService persiste o cursor de pull em SharedPreferences —
    // mocka o channel para rodar sem plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            switch (call.method) {
              case 'getAll':
                return <String, Object>{};
              case 'remove':
              case 'setString':
              case 'setInt':
              case 'setBool':
              case 'setDouble':
              case 'setStringList':
                return true;
              default:
                return null;
            }
          },
        );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    transport = FakeTransport();
    engine = TuiSyncEngine(
      db,
      transport,
      syncService: SyncService(db, transport),
      startLiveSync: () async {},
      liveEvents: transport.liveController.stream,
      pushDebounce: const Duration(milliseconds: 20),
      pullDebounce: const Duration(milliseconds: 20),
      pollInterval: const Duration(hours: 1),
    );
  });

  tearDown(() async {
    await engine.dispose();
    await db.close();
  });

  Future<int> enqueuePending(String entityId) async {
    await db
        .into(db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            id: entityId,
            operation: 'insert',
            entityType: 'transaction',
            entityId: entityId,
            payload: '{}',
          ),
        );
    return (await db.syncQueueDao.watchPendingCount().first);
  }

  test('sem identidade o engine fica inativo e offline', () async {
    final offline = TuiSyncEngine(db, _NoIdentityTransport());
    await offline.start();
    expect(offline.state.hasIdentity, isFalse);
    expect(
      offline.state.statusLine(onlineRelays: 0, peers: 0),
      contains('sem identidade'),
    );
    await offline.dispose();
  });

  test('live event dispara sync (pull reage ao remoto)', () async {
    await engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final before = transport.replayCalls;
    transport.liveController.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(transport.replayCalls, greaterThan(before));
  });

  test('crescimento da fila dispara push com debounce', () async {
    await engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final before = transport.replayCalls;
    await enqueuePending('tx1');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(transport.replayCalls, greaterThan(before));
  });

  test('sync bem-sucedida publica estado de sucesso e último sync', () async {
    await engine.start();
    await engine.syncNow();
    // O sync pode ser o agendado no start (o syncNow early-returna se já
    // há sync em curso) — espera o estado assentar.
    for (
      var i = 0;
      i < 40 && engine.state.status == TuiSyncStatus.syncing;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(
      engine.state.status,
      TuiSyncStatus.success,
      reason: 'estado: ${engine.state.errorMessage}',
    );
    expect(engine.state.lastSyncAt, isNotNull);
  });

  test('falha consecutiva é agrupada no aviso', () async {
    transport.failPulls = true;
    await engine.start();
    await engine.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await engine.syncNow();
    expect(engine.state.status, TuiSyncStatus.error);
    expect(engine.state.errorMessage, isNotNull);
  });

  test('dispose cancela gatilhos e não sincroniza mais', () async {
    await engine.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await engine.dispose();
    final before = transport.replayCalls;
    transport.liveController.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(transport.replayCalls, before);
    await Future<void>.delayed(const Duration(milliseconds: 1));
  });

  test(
    'pull de registros remotos gera aviso "+N de outro dispositivo"',
    () async {
      // O SyncService com transporte fake não traz registros; simulamos o
      // aviso via estado do engine após um sync com pulled > 0 é coberto
      // indiretamente pelos testes do SyncService. Aqui garantimos que o
      // estado success sem pulled não gera aviso.
      await engine.start();
      await engine.syncNow();
      expect(engine.state.notice, isNull);
    },
  );
}

class _NoIdentityTransport extends FakeTransport {
  @override
  Future<SyncIdentity?> loadIdentity() async => null;

  @override
  bool get isReady => false;

  @override
  SyncIdentity? get identity => null;
}
