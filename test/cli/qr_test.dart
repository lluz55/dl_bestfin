import 'package:bestfin/cli/tui/qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Payload da task 80 — alfanumérico compacto, decodificável pelo scanner
  // do Android.
  const payload =
      'BESTFIN:1:0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF';

  test('renderiza matriz determinística com largura par e borda quieta', () {
    final a = renderQr(payload);
    final b = renderQr(payload);
    expect(a, equals(b), reason: 'render é determinístico');
  });

  test('todas as linhas têm a mesma largura e usam meios-blocos', () {
    final lines = renderQr(payload);
    expect(lines, isNotEmpty);
    final widths = lines.map((l) => l.length).toSet();
    expect(widths.length, 1, reason: 'largura constante');
    for (final l in lines) {
      expect(l.length.isEven, isTrue, reason: 'meios-blocos cobrem 2 módulos');
      for (final ch in l.split('')) {
        expect(const ['▀', '▄', '█', ' '].contains(ch), isTrue);
      }
    }
  });

  test('borda quieta é branca (cantos em branco)', () {
    final lines = renderQr(payload, quietZone: 4);
    // Linha superior: inteiramente espaço (4 linhas de módulo quieta = 2 linhas).
    for (var i = 0; i < 2; i++) {
      expect(lines[i].trim(), isEmpty, reason: 'linha $i deve ser quieta');
    }
    expect(lines.last.trim(), isEmpty);
  });

  test(
    'módulos escuros formam padrão do QR (canto superior esquerdo escuro)',
    () {
      // O finder pattern do canto superior esquerdo é sempre escuro na linha
      // da borda da matriz — com quiet zone 4 (2 linhas), a 3ª linha tem o topo
      // do finder escuro.
      final lines = renderQr(payload, quietZone: 4);
      final firstMatrixLine = lines[2];
      expect(
        firstMatrixLine.contains(RegExp(r'[▀█]')),
        isTrue,
        reason: 'finder pattern deve pintar a linha',
      );
    },
  );
}
