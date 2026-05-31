class MathEvaluator {
  static double evaluate(String expression) {
    var s = expression;

    // Strip currency symbols
    s = s.replaceAll(RegExp(r'R\$\s*'), '');

    // Brazilian thousand-separator: 1.500,00 → 1500.00
    // Detect by presence of comma — assume comma is decimal, dots are thousands.
    if (s.contains(',')) {
      s = s.replaceAllMapped(RegExp(r'(\d)\.(\d{3})(?=\D|$)'), (m) => '${m.group(1)}${m.group(2)}');
      s = s.replaceAll(',', '.');
    }

    // Percentage: 15% → (15/100)
    s = s.replaceAllMapped(
      RegExp(r'(\d+\.?\d*)\s*%'),
      (m) => '(${m.group(1)}/100)',
    );

    // Unary minus: normalize +-  →  - and --  →  +
    s = s.replaceAll('+-', '-').replaceAll('--', '+');

    // Leading unary minus: -expr  →  (0-expr)
    s = s.trimLeft();
    if (s.startsWith('-')) s = '0$s';

    // Unary minus after opening paren: (-expr  →  (0-expr
    s = s.replaceAll('(-', '(0-');

    final tokens = _tokenize(s);
    if (tokens.isEmpty) throw ArgumentError('Expressão inválida');
    final rpn = _shuntingYard(tokens);
    return _evaluateRPN(rpn);
  }

  static List<String> _tokenize(String expr) {
    final List<String> tokens = [];
    final RegExp regex = RegExp(r'(\d+\.?\d*)|([\+\-\*\/\(\)])');
    for (final match in regex.allMatches(expr)) {
      final token = match.group(0);
      if (token != null && token.trim().isNotEmpty) {
        tokens.add(token.trim());
      }
    }
    return tokens;
  }

  static List<String> _shuntingYard(List<String> tokens) {
    final List<String> output = [];
    final List<String> operators = [];
    final prec = {'+': 1, '-': 1, '*': 2, '/': 2};

    for (final token in tokens) {
      if (double.tryParse(token) != null) {
        output.add(token);
      } else if (token == '(') {
        operators.add(token);
      } else if (token == ')') {
        while (operators.isNotEmpty && operators.last != '(') {
          output.add(operators.removeLast());
        }
        if (operators.isNotEmpty) operators.removeLast();
      } else if (prec.containsKey(token)) {
        while (operators.isNotEmpty &&
            prec.containsKey(operators.last) &&
            prec[operators.last]! >= prec[token]!) {
          output.add(operators.removeLast());
        }
        operators.add(token);
      }
    }
    while (operators.isNotEmpty) {
      output.add(operators.removeLast());
    }
    return output;
  }

  static double _evaluateRPN(List<String> rpn) {
    final List<double> stack = [];
    for (final token in rpn) {
      final val = double.tryParse(token);
      if (val != null) {
        stack.add(val);
      } else {
        if (stack.length < 2) throw ArgumentError('Expressão inválida');
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (token) {
          case '+':
            stack.add(a + b);
          case '-':
            stack.add(a - b);
          case '*':
            stack.add(a * b);
          case '/':
            if (b == 0) throw ArgumentError('Divisão por zero');
            stack.add(a / b);
          default:
            throw ArgumentError('Operador desconhecido: $token');
        }
      }
    }
    if (stack.length != 1) throw ArgumentError('Expressão inválida');
    return stack.single;
  }
}
