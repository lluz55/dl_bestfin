import 'package:qr/qr.dart';

/// Renderiza o payload de pareamento (`BESTFIN:1:<hex>`, task 80) como blocos
/// ANSI de meia altura (`▀▄█`) — dois módulos do QR por linha do terminal,
/// metade da altura de uma renderização por caractere.
///
/// Função pura: devolve as linhas prontas para `Term.writeln`. A borda quieta
/// é sempre em módulos "claros" (espaço), garantindo contraste nos dois
/// fundos de terminal mais comuns.
List<String> renderQr(String payload, {int quietZone = 4}) {
  final code = QrCode.fromData(
    data: payload,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final image = QrImage(code);
  return renderQrMatrix(_darkMatrix(image), quietZone: quietZone);
}

/// Versão testável: recebe a matriz de módulos escuros já decodificada.
List<String> renderQrMatrix(List<List<bool>> dark, {int quietZone = 4}) {
  final size = dark.length;
  final total = size + quietZone * 2;

  // Grid expandido com a borda quieta (false = claro).
  final grid = List.generate(
    total,
    (y) => List.generate(
      total,
      (x) =>
          x >= quietZone &&
          y >= quietZone &&
          x < quietZone + size &&
          y < quietZone + size &&
          dark[y - quietZone][x - quietZone],
    ),
  );

  // Meios-blocos: linha do terminal cobre duas linhas de módulos.
  // Par de (claro, claro) → espaço; (escuro, claro) → ▀; (claro, escuro) → ▄;
  // (escuro, escuro) → █. Com fundo padrão, ▀/▄ pintados de branco garantem
  // leitura tanto em terminal claro quanto escuro.
  final lines = <String>[];
  // Largura sempre par: cada char cobre 1 coluna × meia linha, e o total
  // de módulos (matriz + borda) pode ser ímpar — arredonda para cima.
  final cols = total + (total.isOdd ? 1 : 0);
  for (var y = 0; y < total; y += 2) {
    final buf = StringBuffer();
    for (var x = 0; x < cols; x++) {
      final top = x < total && grid[y][x];
      final bottom = y + 1 < total && x < total && grid[y + 1][x];
      if (top && bottom) {
        buf.write('█');
      } else if (top) {
        buf.write('▀');
      } else if (bottom) {
        buf.write('▄');
      } else {
        buf.write(' ');
      }
    }
    lines.add(buf.toString());
  }
  return lines;
}

/// Total de linhas que o QR vai ocupar no terminal — usado para decidir
/// paginação.
int qrHeight(String payload, {int quietZone = 4}) {
  final code = QrCode.fromData(
    data: payload,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final image = QrImage(code);
  return ((image.moduleCount + quietZone * 2) / 2).ceil();
}

List<List<bool>> _darkMatrix(QrImage image) => List.generate(
  image.moduleCount,
  (y) => List.generate(image.moduleCount, (x) => image.isDark(y, x)),
);
