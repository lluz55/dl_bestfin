class CurrencyFormatter {
  static bool valuesHidden = false;

  /// Mascara padrões de moedas formatadas (ex: "R$ 1.234,56") contidos em um texto comum.
  static String sanitizeText(String text) {
    if (!valuesHidden) return text;
    return text.replaceAll(RegExp(r'R\$\s*[\d\.\,]+'), 'R\$ •••••');
  }

  /// Formata centavos para o padrão BRL: "R$ 1.234,56" ou "-R$ 1.234,56"
  static String formatCents(int cents, {bool ignoreVisibility = false}) {
    if (valuesHidden && !ignoreVisibility) return 'R\$ •••••';
    final double value = cents / 100.0;
    final isNegative = value < 0;
    final absValue = value.abs();

    final parts = absValue.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final String formattedInteger = integerPart.replaceAllMapped(
      reg,
      (Match m) => '${m[1]}.',
    );

    final sign = isNegative ? '-' : '';
    return '${sign}R\$ $formattedInteger,$decimalPart';
  }

  /// Formata centavos sem o símbolo "R$": "1.234,56" ou "-1.234,56"
  static String formatCentsWithoutSymbol(
    int cents, {
    bool ignoreVisibility = false,
  }) {
    if (valuesHidden && !ignoreVisibility) return '•••••';
    final double value = cents / 100.0;
    final isNegative = value < 0;
    final absValue = value.abs();

    final parts = absValue.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final String formattedInteger = integerPart.replaceAllMapped(
      reg,
      (Match m) => '${m[1]}.',
    );

    final sign = isNegative ? '-' : '';
    return '$sign$formattedInteger,$decimalPart';
  }

  /// Formata centavos como string para o keypad numérico: 1050 → "10,50"
  static String centsToInputString(int cents) {
    if (cents <= 0) return '0,00';
    final str = cents.toString().padLeft(3, '0');
    final intPart = str.substring(0, str.length - 2);
    final decPart = str.substring(str.length - 2);
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAllMapped(reg, (m) => '${m[1]}.');
    return '$formattedInt,$decPart';
  }

  /// Converte uma string formatada ("1.234,56") para centavos (int)
  static int stringToCents(String value) {
    if (value.isEmpty) return 0;

    // Remove R$, espaços, pontos e substitui vírgula por ponto
    String cleanValue = value
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    final parsed = double.tryParse(cleanValue) ?? 0.0;
    return (parsed * 100).round();
  }
}
