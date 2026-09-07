import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bestfin/cli/sync_daemon.dart';

// Identidade dummy — nunca usada em produção.
const _kPayload = 'BESTFIN:1:0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF';

bool get _sopsAvailable => Process.runSync('sops', ['--version']).exitCode == 0;

bool get _hasAgeKey {
  final fromEnv = Platform.environment['SOPS_AGE_KEY_FILE'];
  if (fromEnv != null && File(fromEnv).existsSync()) return true;
  final home = Platform.environment['HOME'];
  return home != null && File('$home/.config/sops/age/keys.txt').existsSync();
}

void main() {
  group('extractIdentityContent', () {
    test('payload solto em texto plano', () {
      expect(extractIdentityContent(_kPayload), isNotNull);
    });

    test('YAML com o payload como valor de chave (formato SOPS típico)', () {
      expect(
        extractIdentityContent('identity: $_kPayload\nsyncd: true\n'),
        isNotNull,
      );
    });

    test('JSON com o payload como valor', () {
      expect(
        extractIdentityContent('{"identity": "$_kPayload"}'),
        isNotNull,
      );
    });

    test('conteúdo sem identidade retorna null', () {
      expect(extractIdentityContent('chave: valor qualquer\n'), isNull);
      expect(extractIdentityContent('BESTFIN:2:zzz'), isNull);
    });
  });

  group('decryptKeyFileWithSops', () {
    test('descriptografa YAML cifrado com SOPS e extrai a identidade', () async {
      if (!_sopsAvailable || !_hasAgeKey) {
        // Ambiente sem sops/chave age (ex: CI) — não é o alvo deste teste.
        return;
      }
      final tmp = Directory.systemTemp.createTempSync('syncd-sops-test');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final plain = File('${tmp.path}/identity.yaml')
        ..writeAsStringSync('identity: $_kPayload\n');

      // O .sops.yaml da raiz só casa com caminhos do projeto — use
      // --filename-override para reaproveitar as regras de chave age.
      final enc = File('${tmp.path}/identity.enc.yaml');
      final encResult = Process.runSync('sops', [
        '-e',
        '--filename-override',
        'secrets.enc.yaml',
        '--output',
        enc.path,
        plain.path,
      ]);
      expect(encResult.exitCode, 0, reason: 'sops -e falhou: ${encResult.stderr}');

      final decrypted = await decryptKeyFileWithSops(enc.path);
      expect(decrypted, isNotNull);
      expect(extractIdentityContent(decrypted!), isNotNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('retorna null para arquivo inexistente', () async {
      expect(
        await decryptKeyFileWithSops(
          '/tmp/syncd-inexistente-${DateTime.now().millisecondsSinceEpoch}.yaml',
        ),
        isNull,
      );
    });
  });
}
