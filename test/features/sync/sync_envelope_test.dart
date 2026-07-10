import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bestfin/features/sync/domain/models/sync_record.dart';

void main() {
  group('envelope versionado do sync', () {
    test('roundtrip preserva versão e payload', () {
      final payload = jsonEncode({'id': 'tx-1', 'description': 'Mercado'});
      final wire = encodeSyncEnvelope(payload, schemaVersion: 7);

      final decoded = decodeSyncEnvelope(wire);
      expect(decoded.schemaVersion, 7);
      expect(decoded.payload, payload);
    });

    test('usa a versão atual por padrão', () {
      final decoded = decodeSyncEnvelope(encodeSyncEnvelope('{"id":"a"}'));
      expect(decoded.schemaVersion, kSyncSchemaVersion);
    });

    test('metadados (type/id/deleted) fazem roundtrip pelo envelope', () {
      final wire = encodeSyncEnvelope(
        '{"id":"tx-1"}',
        entityType: 'transaction',
        entityId: 'tx-1',
        isDeleted: true,
      );
      final decoded = decodeSyncEnvelope(wire);
      expect(decoded.entityType, 'transaction');
      expect(decoded.entityId, 'tx-1');
      expect(decoded.isDeleted, true);
      expect(decoded.payload, '{"id":"tx-1"}');
    });

    test('envelope sem metadados retorna type/id/deleted nulos', () {
      final decoded = decodeSyncEnvelope(encodeSyncEnvelope('{"id":"a"}'));
      expect(decoded.entityType, isNull);
      expect(decoded.entityId, isNull);
      expect(decoded.isDeleted, isNull);
    });

    test('payload legado (sem envelope) decodifica como v1', () {
      final legacy = jsonEncode({
        'id': 'tx-1',
        'description': 'Mercado',
        'updated_at': '2026-01-01T00:00:00.000',
      });

      final decoded = decodeSyncEnvelope(legacy);
      expect(decoded.schemaVersion, 1);
      expect(decoded.payload, legacy);
    });

    test('conteúdo não-JSON passa intacto como v1', () {
      final decoded = decodeSyncEnvelope('não é json');
      expect(decoded.schemaVersion, 1);
      expect(decoded.payload, 'não é json');
    });

    test(
      'entidade que por acaso tem chave "v" não é tratada como envelope',
      () {
        // Envelope exige exatamente {v: int, payload: String}.
        final lookalike = jsonEncode({
          'v': 3,
          'payload': {'id': 'x'},
        });
        final decoded = decodeSyncEnvelope(lookalike);
        expect(decoded.schemaVersion, 1);
        expect(decoded.payload, lookalike);
      },
    );
  });
}
