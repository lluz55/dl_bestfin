import 'package:bestfin/cli/tui/term.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatação monetária', () {
    test('formata centavos com separador de milhar', () {
      expect(Term.formatMoney(0), r'R$ 0,00');
      expect(Term.formatMoney(5), r'R$ 0,05');
      expect(Term.formatMoney(5000), r'R$ 50,00');
      expect(Term.formatMoney(123456), r'R$ 1.234,56');
      expect(Term.formatMoney(100000000), r'R$ 1.000.000,00');
    });

    test('valores negativos levam o sinal antes do símbolo', () {
      expect(Term.formatMoney(-123456), r'-R$ 1.234,56');
    });

    test('sign: true só marca positivos', () {
      expect(Term.formatMoney(1000, sign: true), r'+R$ 10,00');
      expect(Term.formatMoney(0, sign: true), r'R$ 0,00');
    });
  });

  group('parseMoney', () {
    test('aceita os formatos que o usuário digita', () {
      expect(Term.parseMoney('50'), 5000);
      expect(Term.parseMoney('50,00'), 5000);
      expect(Term.parseMoney('50.00'), 5000);
      expect(Term.parseMoney('1.234,56'), 123456);
      expect(Term.parseMoney(r'R$ 1.234,56'), 123456);
      expect(Term.parseMoney(' 12,5 '), 1250);
    });

    test('recusa entrada inválida', () {
      expect(Term.parseMoney(''), isNull);
      expect(Term.parseMoney('abc'), isNull);
    });

    test('ida e volta preserva o valor', () {
      for (final cents in [1, 99, 100, 12345, 9999999]) {
        expect(Term.parseMoney(Term.formatMoney(cents)), cents);
      }
    });
  });

  group('datas', () {
    test('formata dd/MM/aaaa', () {
      expect(Term.formatDate(DateTime(2026, 1, 5)), '05/01/2026');
      expect(Term.formatDate(DateTime(2026, 12, 31)), '31/12/2026');
    });

    test('parseDate aceita separadores comuns e ano curto', () {
      expect(Term.parseDate('05/01/2026'), DateTime(2026, 1, 5));
      expect(Term.parseDate('5-1-2026'), DateTime(2026, 1, 5));
      expect(Term.parseDate('05/01/26'), DateTime(2026, 1, 5));
    });

    test('parseDate recusa datas impossíveis', () {
      expect(Term.parseDate('31/02/2026'), isNull);
      expect(Term.parseDate('32/01/2026'), isNull);
      expect(Term.parseDate('01/13/2026'), isNull);
      expect(Term.parseDate('hoje'), isNull);
    });
  });

  group('layout', () {
    test('visibleLength ignora escapes ANSI', () {
      expect(Term.visibleLength('abc'), 3);
      expect(Term.visibleLength('${Term.red}abc${Term.reset}'), 3);
    });

    test('pad e padLeft respeitam o comprimento visível', () {
      expect(Term.pad('ab', 5), 'ab   ');
      expect(Term.padLeft('ab', 5), '   ab');
      expect(
        Term.visibleLength(Term.pad('${Term.green}ab${Term.reset}', 5)),
        5,
      );
    });

    test('truncate corta com reticências', () {
      expect(Term.truncate('abcdef', 4), 'abc…');
      expect(Term.truncate('abc', 10), 'abc');
    });

    test('progressBar preenche proporcionalmente e satura', () {
      expect(Term.progressBar(0, cols: 4), '░░░░');
      expect(Term.progressBar(0.5, cols: 4), '██░░');
      expect(Term.progressBar(1, cols: 4), '████');
      expect(Term.progressBar(2, cols: 4), '████');
      expect(Term.progressBar(double.nan, cols: 4), '░░░░');
    });

    test('viewportFor nunca excede itens nem espaço disponível', () {
      expect(Term.viewportFor(40, 10), 10); // sobra tela: mostra tudo
      expect(Term.viewportFor(5, 10), 5); // falta tela: rola
      expect(Term.viewportFor(40, 0), 0); // lista vazia
    });

    test('viewportFor sobrevive a listas curtas e telas minúsculas', () {
      // Regressão: `clamp(3, items.length)` estourava com 1 ou 2 itens.
      expect(Term.viewportFor(40, 1), 1);
      expect(Term.viewportFor(40, 2), 2);
      expect(Term.viewportFor(0, 2), 1);
      expect(Term.viewportFor(-5, 2), 1);
    });

    test('tabela alinha colunas pelo cabeçalho e pelas linhas', () {
      final lines = Term.table(
        ['Nome', 'Valor'],
        [
          ['Mercado', '50,00'],
          ['Aluguel muito longo', '1.200,00'],
        ],
        aligns: ['l', 'r'],
      );
      expect(lines.length, 4); // cabeçalho + separador + 2 linhas
      expect(lines.first, contains('Nome'));
    });
  });
}
