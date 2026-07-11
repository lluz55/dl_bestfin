import 'package:bestfin/features/sync/data/services/nostr_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NostrSyncService.normalizeRelayUrl', () {
    test('mantém uma URL wss válida', () {
      expect(
        NostrSyncService.normalizeRelayUrl('wss://relay.damus.io'),
        'wss://relay.damus.io',
      );
    });

    test('prefixa wss:// quando falta o esquema', () {
      expect(
        NostrSyncService.normalizeRelayUrl('nos.lol'),
        'wss://nos.lol',
      );
    });

    test('aceita ws:// (não seguro) explícito', () {
      expect(
        NostrSyncService.normalizeRelayUrl('ws://localhost:7000'),
        'ws://localhost:7000',
      );
    });

    test('remove barra final e espaços', () {
      expect(
        NostrSyncService.normalizeRelayUrl('  wss://relay.example.com/  '),
        'wss://relay.example.com',
      );
    });

    test('preserva caminho não-trivial', () {
      expect(
        NostrSyncService.normalizeRelayUrl('wss://relay.example.com/v1'),
        'wss://relay.example.com/v1',
      );
    });

    test('rejeita esquema não-websocket', () {
      expect(NostrSyncService.normalizeRelayUrl('https://x.com'), isNull);
      expect(NostrSyncService.normalizeRelayUrl('http://x.com'), isNull);
    });

    test('rejeita vazio/whitespace', () {
      expect(NostrSyncService.normalizeRelayUrl(''), isNull);
      expect(NostrSyncService.normalizeRelayUrl('   '), isNull);
    });
  });
}
