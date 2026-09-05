import 'dart:convert';
import 'dart:io';

/// Toolkit de terminal sem dependências externas (ANSI + stdin em modo raw).
///
/// Usado por toda a TUI (`bestfin tui`): menus navegáveis por setas, listas
/// roláveis, formulários, tabelas e diálogos. Mantido em Dart puro para não
/// adicionar `buildInputs` nativas ao pacote Nix (ver task 55).

enum KeyCode {
  char,
  up,
  down,
  left,
  right,
  enter,
  esc,
  backspace,
  delete,
  tab,
  home,
  end,
  pageUp,
  pageDown,
  ctrlC,
  unknown,
}

class Key {
  const Key(this.code, [this.char]);

  final KeyCode code;
  final String? char;

  bool get isChar => code == KeyCode.char && char != null;

  /// Comparação conveniente e case-insensitive com uma tecla literal.
  bool is_(String c) => isChar && char!.toLowerCase() == c.toLowerCase();
}

/// Ação de rodapé exibida numa lista (`[n] novo`, `[e] editar`, ...).
class TermAction {
  const TermAction(this.key, this.label);

  final String key;
  final String label;
}

class Term {
  Term._();

  // ── Estado ─────────────────────────────────────────────────────────

  static bool _rawActive = false;
  static bool _altActive = false;

  /// Há um terminal capaz de rodar a TUI?
  ///
  /// A checagem é feita **pelo stdin**: dentro do runner Flutter/GTK o
  /// `stdout.hasTerminal` responde `false` mesmo quando o processo está ligado
  /// a um terminal de verdade (o embedder não expõe o descritor como tty),
  /// enquanto o stdin continua reportando corretamente. Como é o stdin que
  /// precisa do modo raw — a escrita ANSI funciona de qualquer forma —, é ele
  /// que decide. `BESTFIN_TUI=0`/`1` força o comportamento em scripts.
  static bool get isInteractive {
    final override = Platform.environment['BESTFIN_TUI'];
    if (override == '0') return false;
    if (override == '1') return true;
    return stdin.hasTerminal;
  }

  static int? _cachedWidth;
  static int? _cachedHeight;

  static int get width => _clampDimension(
    _cachedWidth ?? _dimension(() => stdout.terminalColumns, 'COLUMNS', 80),
    min: 40,
    max: 220,
  );

  static int get height => _clampDimension(
    _cachedHeight ?? _dimension(() => stdout.terminalLines, 'LINES', 24),
    min: 10,
    max: 200,
  );

  static int _dimension(int Function() probe, String envKey, int fallback) {
    var value = 0;
    try {
      value = probe();
    } catch (_) {
      value = 0;
    }
    if (value <= 0) {
      value = int.tryParse(Platform.environment[envKey] ?? '') ?? 0;
    }
    return value <= 0 ? fallback : value;
  }

  static int _clampDimension(int v, {required int min, required int max}) =>
      v < min ? min : (v > max ? max : v);

  /// Descobre o tamanho da tela via `stty size` lendo de `/dev/tty`.
  ///
  /// É o caminho que salva a TUI quando o embedder não expõe o tty ao
  /// `dart:io` (`stdout.terminalColumns` estoura) e o shell não exportou
  /// `COLUMNS`/`LINES`. Deliberadamente **não** usamos o truque de perguntar
  /// ao terminal (`ESC[6n`): a resposta chega pelo stdin e travaria o
  /// processo para sempre num terminal que não responde.
  static void refreshSize() {
    if (!Platform.isLinux && !Platform.isMacOS) return;
    try {
      final result = Process.runSync('sh', [
        '-c',
        'stty size < /dev/tty 2>/dev/null',
      ]);
      if (result.exitCode != 0) return;
      final parts = (result.stdout as String).trim().split(RegExp(r'\s+'));
      if (parts.length != 2) return;
      final rows = int.tryParse(parts[0]);
      final cols = int.tryParse(parts[1]);
      if (rows != null && rows > 0) _cachedHeight = rows;
      if (cols != null && cols > 0) _cachedWidth = cols;
    } catch (_) {
      // Sem `stty` no PATH — segue com stdout/env/fallback.
    }
  }

  // ── Cores / estilo ─────────────────────────────────────────────────

  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';
  static const italic = '\x1B[3m';
  static const inverse = '\x1B[7m';
  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const magenta = '\x1B[35m';
  static const cyan = '\x1B[36m';
  static const gray = '\x1B[90m';

  static String c(String text, String color) => '$color$text$reset';

  /// Comprimento visível de uma string (ignora escapes ANSI).
  static int visibleLength(String s) {
    final stripped = s.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
    return stripped.runes.length;
  }

  /// Trunca preservando o texto visível (não corta no meio de um escape).
  static String truncate(String s, int max) {
    if (visibleLength(s) <= max) return s;
    final plain = s.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
    if (plain.runes.length <= max) return s;
    final cut = String.fromCharCodes(plain.runes.take(max > 1 ? max - 1 : 1));
    return '$cut…';
  }

  static String pad(String s, int cols) {
    final len = visibleLength(s);
    if (len >= cols) return truncate(s, cols);
    return s + ' ' * (cols - len);
  }

  static String padLeft(String s, int cols) {
    final len = visibleLength(s);
    if (len >= cols) return truncate(s, cols);
    return ' ' * (cols - len) + s;
  }

  // ── Modo raw / tela alternativa ────────────────────────────────────

  static void enterRaw() {
    if (_rawActive || !isInteractive) return;
    try {
      stdin.echoMode = false;
      stdin.lineMode = false;
      _rawActive = true;
      refreshSize();
    } catch (_) {
      // Terminal não suporta — cai no modo linha.
    }
  }

  static void exitRaw() {
    if (!_rawActive) return;
    try {
      stdin.lineMode = true;
      stdin.echoMode = true;
    } catch (_) {}
    _rawActive = false;
  }

  static void enterAlt() {
    if (_altActive || !isInteractive) return;
    stdout.write('\x1B[?1049h\x1B[?25l');
    _altActive = true;
  }

  static void exitAlt() {
    if (!_altActive) return;
    stdout.write('\x1B[?25h\x1B[?1049l');
    _altActive = false;
  }

  /// Restaura o terminal — sempre chamado antes de sair do processo.
  static void restore() {
    exitAlt();
    exitRaw();
    stdout.write('\x1B[?25h$reset');
  }

  static void clear() {
    if (isInteractive) stdout.write('\x1B[2J\x1B[H');
  }

  /// Reexecuta a sondagem de tamanho — útil quando o usuário redimensiona a
  /// janela do terminal entre uma tela e outra.
  static void invalidateSize() {
    _cachedWidth = null;
    _cachedHeight = null;
    refreshSize();
  }

  static void write(String s) => stdout.write(s);
  static void writeln([String s = '']) => stdout.writeln(s);

  static void showCursor() => stdout.write('\x1B[?25h');
  static void hideCursor() => stdout.write('\x1B[?25l');

  // ── Leitura de teclas ──────────────────────────────────────────────

  /// Lê uma tecla (bloqueante). Requer [enterRaw] ativo.
  static Key readKey() {
    final b = stdin.readByteSync();
    if (b == -1) return const Key(KeyCode.esc);

    switch (b) {
      case 3:
        return const Key(KeyCode.ctrlC);
      case 9:
        return const Key(KeyCode.tab);
      case 10:
      case 13:
        return const Key(KeyCode.enter);
      case 127:
      case 8:
        return const Key(KeyCode.backspace);
      case 27:
        return _readEscapeSequence();
    }

    if (b < 32) return const Key(KeyCode.unknown);

    // ASCII simples
    if (b < 0x80) return Key(KeyCode.char, String.fromCharCode(b));

    // UTF-8 multibyte: descobre quantos bytes de continuação faltam.
    var extra = 0;
    if (b >= 0xF0) {
      extra = 3;
    } else if (b >= 0xE0) {
      extra = 2;
    } else if (b >= 0xC0) {
      extra = 1;
    }
    final bytes = <int>[b];
    for (var i = 0; i < extra; i++) {
      final n = stdin.readByteSync();
      if (n == -1) break;
      bytes.add(n);
    }
    try {
      return Key(KeyCode.char, utf8.decode(bytes));
    } catch (_) {
      return const Key(KeyCode.unknown);
    }
  }

  static Key _readEscapeSequence() {
    // ESC sozinho (sem sequência pendente) = tecla Esc.
    final next = _readByteIfAvailable();
    if (next == null) return const Key(KeyCode.esc);
    if (next != 0x5B && next != 0x4F) return const Key(KeyCode.esc);

    final b = stdin.readByteSync();
    switch (b) {
      case 0x41:
        return const Key(KeyCode.up);
      case 0x42:
        return const Key(KeyCode.down);
      case 0x43:
        return const Key(KeyCode.right);
      case 0x44:
        return const Key(KeyCode.left);
      case 0x48:
        return const Key(KeyCode.home);
      case 0x46:
        return const Key(KeyCode.end);
    }
    // Sequências numéricas: ESC [ <n> ~
    if (b >= 0x30 && b <= 0x39) {
      final digits = <int>[b];
      while (true) {
        final n = stdin.readByteSync();
        if (n == -1 || n == 0x7E) break;
        if (n >= 0x30 && n <= 0x39) {
          digits.add(n);
        } else {
          break;
        }
      }
      final code = int.tryParse(String.fromCharCodes(digits)) ?? -1;
      switch (code) {
        case 1:
        case 7:
          return const Key(KeyCode.home);
        case 3:
          return const Key(KeyCode.delete);
        case 4:
        case 8:
          return const Key(KeyCode.end);
        case 5:
          return const Key(KeyCode.pageUp);
        case 6:
          return const Key(KeyCode.pageDown);
      }
    }
    return const Key(KeyCode.unknown);
  }

  /// Tenta ler um byte imediatamente disponível — usado para distinguir a
  /// tecla Esc de uma sequência de escape (seta, Home, ...).
  static int? _readByteIfAvailable() {
    // Em modo raw sem timeout não há API não-bloqueante em dart:io; a
    // heurística é que sequências chegam no mesmo burst do terminal, então
    // um readByteSync direto resolve na prática. Esc puro é raro na TUI
    // (usamos `q` para voltar), então o custo de bloquear é aceitável.
    final b = stdin.readByteSync();
    return b == -1 ? null : b;
  }

  // ── Layout ─────────────────────────────────────────────────────────

  static void header(String title, {String? subtitle}) {
    final w = width;
    writeln('$cyan$bold${pad(' $title', w)}$reset');
    if (subtitle != null && subtitle.isNotEmpty) {
      writeln('$gray${truncate(' $subtitle', w)}$reset');
    }
    writeln('$gray${'─' * w}$reset');
  }

  static void footer(List<TermAction> actions, {String? hint}) {
    final w = width;
    final parts = actions
        .map((a) => '$bold[${a.key}]$reset$gray ${a.label}')
        .join('  ');
    writeln('$gray${'─' * w}$reset');
    writeln('$gray${truncate(' $parts', w)}$reset');
    if (hint != null) writeln('$gray${truncate(' $hint', w)}$reset');
  }

  /// Renderiza uma tabela simples com colunas alinhadas.
  ///
  /// [aligns] aceita 'l' (padrão) ou 'r' por coluna.
  static List<String> table(
    List<String> headers,
    List<List<String>> rows, {
    List<String>? aligns,
    int? maxWidth,
  }) {
    if (headers.isEmpty) return const [];
    final cols = headers.length;
    final widths = List<int>.generate(cols, (i) => visibleLength(headers[i]));
    for (final r in rows) {
      for (var i = 0; i < cols && i < r.length; i++) {
        final l = visibleLength(r[i]);
        if (l > widths[i]) widths[i] = l;
      }
    }

    // Encolhe a coluna mais larga até caber na tela.
    final limit = maxWidth ?? (width - 2);
    var total = widths.fold<int>(0, (a, b) => a + b) + (cols - 1) * 2;
    while (total > limit) {
      var widest = 0;
      for (var i = 1; i < cols; i++) {
        if (widths[i] > widths[widest]) widest = i;
      }
      if (widths[widest] <= 6) break;
      widths[widest] -= 1;
      total -= 1;
    }

    String renderRow(List<String> cells, {bool head = false}) {
      final buf = StringBuffer();
      for (var i = 0; i < cols; i++) {
        final cell = i < cells.length ? cells[i] : '';
        final align = (aligns != null && i < aligns.length) ? aligns[i] : 'l';
        final rendered = align == 'r'
            ? padLeft(cell, widths[i])
            : pad(cell, widths[i]);
        buf.write(head ? '$bold$rendered$reset' : rendered);
        if (i < cols - 1) buf.write('  ');
      }
      return buf.toString();
    }

    return [
      renderRow(headers, head: true),
      '$gray${'─' * (total > limit ? limit : total)}$reset',
      ...rows.map((r) => renderRow(r)),
    ];
  }

  // ── Componentes interativos ────────────────────────────────────────

  /// Menu navegável. Retorna o índice escolhido ou `null` se cancelado
  /// (`q`, Esc ou Ctrl+C).
  ///
  /// [actions] são atalhos extras exibidos no rodapé; quando o usuário
  /// aperta uma delas, [onAction] recebe a tecla e o índice selecionado.
  /// Se [onAction] devolver `true`, o menu encerra retornando `null`.
  static int? select(
    String title, {
    required List<String> items,
    String? subtitle,
    List<String>? details,
    int initialIndex = 0,
    List<TermAction> actions = const [],
    bool Function(String key, int index)? onAction,
    String? emptyMessage,
  }) {
    if (!isInteractive) {
      throw const TuiNotInteractive();
    }
    if (items.isEmpty) {
      alert(title, emptyMessage ?? 'Nada para mostrar.');
      return null;
    }

    var index = initialIndex.clamp(0, items.length - 1);
    var offset = 0;

    while (true) {
      final chromeLines =
          4 + (subtitle == null ? 0 : 1) + (actions.isEmpty ? 1 : 3);
      final viewport = viewportFor(height - chromeLines, items.length);
      if (index < offset) offset = index;
      if (index >= offset + viewport) offset = index - viewport + 1;

      clear();
      header(title, subtitle: subtitle);
      for (var i = offset; i < offset + viewport && i < items.length; i++) {
        final selected = i == index;
        final marker = selected ? '$cyan❯ $reset' : '  ';
        final line = selected
            ? '$bold${truncate(items[i], width - 3)}$reset'
            : truncate(items[i], width - 3);
        writeln('$marker$line');
      }
      if (items.length > viewport) {
        writeln(
          '$gray  ${index + 1}/${items.length}'
          '${offset > 0 ? ' ↑' : ''}'
          '${offset + viewport < items.length ? ' ↓' : ''}$reset',
        );
      }
      if (details != null && index < details.length) {
        writeln('$gray${truncate(' ${details[index]}', width)}$reset');
      }
      footer([
        const TermAction('↑↓', 'navegar'),
        const TermAction('↵', 'abrir'),
        ...actions,
        const TermAction('q', 'voltar'),
      ]);

      final key = readKey();
      switch (key.code) {
        case KeyCode.up:
          index = index == 0 ? items.length - 1 : index - 1;
          continue;
        case KeyCode.down:
          index = (index + 1) % items.length;
          continue;
        case KeyCode.pageUp:
          index = (index - viewport).clamp(0, items.length - 1);
          continue;
        case KeyCode.pageDown:
          index = (index + viewport).clamp(0, items.length - 1);
          continue;
        case KeyCode.home:
          index = 0;
          continue;
        case KeyCode.end:
          index = items.length - 1;
          continue;
        case KeyCode.enter:
          return index;
        case KeyCode.esc:
        case KeyCode.ctrlC:
          return null;
        default:
          break;
      }
      if (key.isChar) {
        final ch = key.char!.toLowerCase();
        if (ch == 'q') return null;
        if (ch == 'k') {
          index = index == 0 ? items.length - 1 : index - 1;
          continue;
        }
        if (ch == 'j') {
          index = (index + 1) % items.length;
          continue;
        }
        // Seleção direta por número (1-9)
        final n = int.tryParse(ch);
        if (n != null && n >= 1 && n <= items.length && n <= 9) {
          return n - 1;
        }
        if (onAction != null && actions.any((a) => a.key == ch)) {
          final done = onAction(ch, index);
          if (done) return null;
        }
      }
    }
  }

  /// Escolha tipada a partir de uma lista de objetos.
  static T? pick<T>(
    String title,
    List<T> items,
    String Function(T) label, {
    String? subtitle,
    String? emptyMessage,
    int initialIndex = 0,
  }) {
    if (items.isEmpty) {
      alert(title, emptyMessage ?? 'Nenhum item disponível.');
      return null;
    }
    final i = select(
      title,
      items: items.map(label).toList(),
      subtitle: subtitle,
      initialIndex: initialIndex,
    );
    return i == null ? null : items[i];
  }

  /// Escolha opcional — adiciona uma entrada "(nenhum)" no topo.
  /// Retorna `(true, value)` quando o usuário escolheu (value pode ser null),
  /// e `(false, null)` quando cancelou.
  static (bool, T?) pickOptional<T>(
    String title,
    List<T> items,
    String Function(T) label, {
    String noneLabel = '(nenhum)',
    String? subtitle,
  }) {
    final labels = <String>[noneLabel, ...items.map(label)];
    final i = select(title, items: labels, subtitle: subtitle);
    if (i == null) return (false, null);
    if (i == 0) return (true, null);
    return (true, items[i - 1]);
  }

  /// Campo de texto com edição básica (setas, backspace, Home/End).
  /// Retorna `null` se cancelado com Esc.
  static String? input(
    String label, {
    String initial = '',
    String? hint,
    bool allowEmpty = true,
  }) {
    if (!isInteractive) throw const TuiNotInteractive();
    var buffer = initial;
    var cursor = buffer.length;

    while (true) {
      // Redesenha só a linha do campo.
      write('\r\x1B[2K');
      final shown = '$cyan$label$reset ${buffer.isEmpty ? '' : buffer}';
      write(truncate(shown, width - 1));
      // Posiciona o cursor visível na posição lógica.
      final prefix = visibleLength('$label ');
      write('\r\x1B[${prefix + cursor}C');
      showCursor();

      final key = readKey();
      hideCursor();
      switch (key.code) {
        case KeyCode.enter:
          if (!allowEmpty && buffer.trim().isEmpty) {
            write('\r\x1B[2K$red$label — obrigatório$reset');
            writeln();
            continue;
          }
          writeln();
          return buffer;
        case KeyCode.esc:
        case KeyCode.ctrlC:
          writeln();
          return null;
        case KeyCode.backspace:
          if (cursor > 0) {
            buffer = buffer.substring(0, cursor - 1) + buffer.substring(cursor);
            cursor--;
          }
          continue;
        case KeyCode.delete:
          if (cursor < buffer.length) {
            buffer = buffer.substring(0, cursor) + buffer.substring(cursor + 1);
          }
          continue;
        case KeyCode.left:
          if (cursor > 0) cursor--;
          continue;
        case KeyCode.right:
          if (cursor < buffer.length) cursor++;
          continue;
        case KeyCode.home:
          cursor = 0;
          continue;
        case KeyCode.end:
          cursor = buffer.length;
          continue;
        default:
          break;
      }
      if (key.isChar) {
        buffer =
            buffer.substring(0, cursor) + key.char! + buffer.substring(cursor);
        cursor += key.char!.length;
      }
      if (hint != null && buffer.isEmpty) {
        // hint some assim que o usuário digita — nada a fazer aqui.
      }
    }
  }

  /// Campo de valor monetário. Retorna centavos, ou `null` se cancelado.
  static int? inputMoney(
    String label, {
    int? initial,
    bool allowEmpty = false,
  }) {
    while (true) {
      final initialText = initial == null
          ? ''
          : (initial / 100).toStringAsFixed(2).replaceAll('.', ',');
      final raw = input('$label (ex: 1.234,56):', initial: initialText);
      if (raw == null) return null;
      if (raw.trim().isEmpty) {
        if (allowEmpty) return initial;
        error('Valor é obrigatório.');
        continue;
      }
      final cents = parseMoney(raw);
      if (cents == null) {
        error('Valor inválido: "$raw"');
        continue;
      }
      return cents;
    }
  }

  static int? inputInt(String label, {int? initial, int? min, int? max}) {
    while (true) {
      final raw = input('$label:', initial: initial?.toString() ?? '');
      if (raw == null) return null;
      if (raw.trim().isEmpty && initial != null) return initial;
      final v = int.tryParse(raw.trim());
      if (v == null) {
        error('Número inválido.');
        continue;
      }
      if (min != null && v < min) {
        error('Mínimo: $min');
        continue;
      }
      if (max != null && v > max) {
        error('Máximo: $max');
        continue;
      }
      return v;
    }
  }

  static double? inputDouble(String label, {double? initial}) {
    while (true) {
      final raw = input(
        '$label:',
        initial: initial?.toString().replaceAll('.', ',') ?? '',
      );
      if (raw == null) return null;
      if (raw.trim().isEmpty && initial != null) return initial;
      final v = double.tryParse(raw.trim().replaceAll(',', '.'));
      if (v == null) {
        error('Número inválido.');
        continue;
      }
      return v;
    }
  }

  /// Campo de data no formato dd/MM/aaaa. "hoje" e vazio ⇒ data de hoje.
  static DateTime? inputDate(String label, {DateTime? initial}) {
    while (true) {
      final raw = input(
        '$label (dd/mm/aaaa):',
        initial: initial == null ? '' : formatDate(initial),
      );
      if (raw == null) return null;
      final t = raw.trim().toLowerCase();
      if (t.isEmpty || t == 'hoje') {
        return initial ?? DateTime.now();
      }
      final d = parseDate(t);
      if (d == null) {
        error('Data inválida. Use dd/mm/aaaa.');
        continue;
      }
      return d;
    }
  }

  static bool confirm(String question, {bool defaultYes = false}) {
    if (!isInteractive) return defaultYes;
    while (true) {
      write(
        '\r\x1B[2K$yellow? $reset$question ${gray}[${defaultYes ? 'S/n' : 's/N'}]$reset ',
      );
      final key = readKey();
      if (key.code == KeyCode.enter) {
        writeln();
        return defaultYes;
      }
      if (key.code == KeyCode.esc || key.code == KeyCode.ctrlC) {
        writeln();
        return false;
      }
      if (key.is_('s') || key.is_('y')) {
        writeln();
        return true;
      }
      if (key.is_('n')) {
        writeln();
        return false;
      }
    }
  }

  /// Exibe um bloco de texto rolável e espera o usuário sair.
  static void pager(String title, List<String> lines, {String? subtitle}) {
    if (!isInteractive) {
      for (final l in lines) {
        writeln(l);
      }
      return;
    }
    var offset = 0;
    while (true) {
      final chrome = 5 + (subtitle == null ? 0 : 1);
      final viewport = (height - chrome).clamp(3, 1000);
      final maxOffset = (lines.length - viewport).clamp(0, lines.length);
      if (offset > maxOffset) offset = maxOffset;

      clear();
      header(title, subtitle: subtitle);
      for (var i = offset; i < offset + viewport && i < lines.length; i++) {
        writeln(truncate(lines[i], width));
      }
      footer([
        if (lines.length > viewport) const TermAction('↑↓', 'rolar'),
        const TermAction('q', 'voltar'),
      ]);

      final key = readKey();
      if (key.code == KeyCode.esc ||
          key.code == KeyCode.ctrlC ||
          key.code == KeyCode.enter ||
          key.is_('q')) {
        return;
      }
      switch (key.code) {
        case KeyCode.up:
          offset = (offset - 1).clamp(0, maxOffset);
          break;
        case KeyCode.down:
          offset = (offset + 1).clamp(0, maxOffset);
          break;
        case KeyCode.pageUp:
          offset = (offset - viewport).clamp(0, maxOffset);
          break;
        case KeyCode.pageDown:
          offset = (offset + viewport).clamp(0, maxOffset);
          break;
        case KeyCode.home:
          offset = 0;
          break;
        case KeyCode.end:
          offset = maxOffset;
          break;
        default:
          if (key.is_('j')) offset = (offset + 1).clamp(0, maxOffset);
          if (key.is_('k')) offset = (offset - 1).clamp(0, maxOffset);
      }
    }
  }

  static void alert(String title, String message) {
    if (!isInteractive) {
      writeln(message);
      return;
    }
    clear();
    header(title);
    writeln();
    writeln('  $message');
    writeln();
    pause();
  }

  static void success(String message) {
    writeln('$green✓$reset $message');
  }

  static void error(String message) {
    writeln('$red✗$reset $message');
  }

  static void warn(String message) {
    writeln('$yellow!$reset $message');
  }

  static void pause([String message = 'Pressione qualquer tecla…']) {
    if (!isInteractive) return;
    writeln('$gray$message$reset');
    readKey();
  }

  /// Imprime as linhas de um QR ([renderQr]) com fundo claro garantido —
  /// escuro no foreground, claro no background, legível em qualquer tema.
  static void writeQr(List<String> lines) {
    for (final l in lines) {
      writeln('\x1B[30;47m$l\x1B[0m');
    }
  }

  // ── Formatação ─────────────────────────────────────────────────────

  static String formatMoney(int cents, {bool sign = false}) {
    final neg = cents < 0;
    final abs = cents.abs();
    final intPart = (abs ~/ 100).toString();
    final decPart = (abs % 100).toString().padLeft(2, '0');
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    // Zero não recebe sinal — "+R$ 0,00" só polui a leitura das variações.
    final prefix = neg ? '-' : (sign && cents > 0 ? '+' : '');
    return '${prefix}R\$ $buf,$decPart';
  }

  static String formatMoneyColored(int cents, {bool sign = false}) {
    final text = formatMoney(cents, sign: sign);
    if (cents < 0) return c(text, red);
    if (cents > 0 && sign) return c(text, green);
    return text;
  }

  static int? parseMoney(String s) {
    var raw = s.trim().replaceAll(RegExp(r'R\$|\s'), '');
    if (raw.isEmpty) return null;
    if (raw.contains('.') && raw.contains(',')) {
      raw = raw.replaceAll('.', '').replaceAll(',', '.');
    } else if (raw.contains(',')) {
      raw = raw.replaceAll(',', '.');
    }
    final v = double.tryParse(raw);
    if (v == null) return null;
    return (v * 100).round();
  }

  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String formatDateShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static DateTime? parseDate(String s) {
    final m = RegExp(
      r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$',
    ).firstMatch(s.trim());
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    var year = int.parse(m.group(3)!);
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      final d = DateTime(year, month, day);
      if (d.month != month) return null; // 31/02 etc.
      return d;
    } catch (_) {
      return null;
    }
  }

  static const monthNames = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  static String monthLabel(int year, int month) =>
      '${monthNames[(month - 1).clamp(0, 11)]}/$year';

  /// Quantas linhas da lista cabem na tela.
  ///
  /// Nunca passa do número de itens (não sobra moldura vazia) nem do espaço
  /// disponível, e nunca chega a zero — uma lista de um item só continua
  /// mostrando esse item mesmo num terminal minúsculo.
  static int viewportFor(int available, int itemCount) {
    if (itemCount <= 0) return 0;
    final usable = available < 1 ? 1 : available;
    return usable > itemCount ? itemCount : usable;
  }

  /// Barra de progresso em texto (`████░░░░`).
  static String progressBar(double fraction, {int cols = 20, String? color}) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    final filled = (f * cols).round();
    final bar = '█' * filled + '░' * (cols - filled);
    return color == null ? bar : c(bar, color);
  }
}

/// Lançada quando um componente interativo é usado sem terminal (pipe/CI).
class TuiNotInteractive implements Exception {
  const TuiNotInteractive();

  @override
  String toString() =>
      'A TUI precisa de um terminal interativo (stdin em modo raw). '
      'Em scripts, use `bestfin add "<frase>"`, que grava sem interação '
      'quando a frase já traz valor, conta e categoria.';
}
