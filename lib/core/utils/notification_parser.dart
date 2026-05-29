class ParsedNotification {
  final int? amountInCents;
  final String? description;
  final String? merchant;

  const ParsedNotification({
    this.amountInCents,
    this.description,
    this.merchant,
  });

  bool get isValid => amountInCents != null && amountInCents! > 0;
}

class _BankPattern {
  final String packageName;
  final List<String> patterns;
  const _BankPattern(this.packageName, this.patterns);
}

class NotificationParser {
  static const _bankPatterns = [
    _BankPattern('com.nubank.nubank', [
      r'Compra aprovada de R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
      r'Débito de R\$\s*(?<amount>[\d.,]+)\s+-\s*(?<merchant>.+)',
      r'Compra de R\$\s*(?<amount>[\d.,]+)\s+(?<merchant>.+)',
    ]),
    _BankPattern('br.com.intermedium', [
      r'Débito R\$\s*(?<amount>[\d.,]+)\s*-\s*(?<merchant>.+)',
      r'PIX enviado de R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
      r'Pagamento de R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
    ]),
    _BankPattern('com.itau', [
      r'Compra no crédito de R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
      r'Compra no débito de R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
      r'Pix enviado: R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
    ]),
    _BankPattern('com.bradesco', [
      r'Compra aprovada de R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
      r'Débito em conta: R\$\s*(?<amount>[\d.,]+)\s*(?<merchant>.*)',
      r'Pix no valor de R\$\s*(?<amount>[\d.,]+)\s+enviado para\s+(?<merchant>.+)',
    ]),
    _BankPattern('br.com.bb.android', [
      r'Compra de R\$\s*(?<amount>[\d.,]+)\s+(?<merchant>.+)',
      r'Pix enviado: R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
      r'Débito de R\$\s*(?<amount>[\d.,]+)\s+(?<merchant>.*)',
    ]),
    _BankPattern('com.c6bank.app', [
      r'Compra aprovada: R\$\s*(?<amount>[\d.,]+)\s+em\s+(?<merchant>.+)',
      r'Débito R\$\s*(?<amount>[\d.,]+)\s+(?<merchant>.*)',
    ]),
    _BankPattern('com.picpay', [
      r'Você pagou R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
      r'Pagamento de R\$\s*(?<amount>[\d.,]+)\s+para\s+(?<merchant>.+)',
      r'Cobrança de R\$\s*(?<amount>[\d.,]+)\s+(?<merchant>.*)',
    ]),
  ];

  static ParsedNotification parse(
    String packageName,
    String title,
    String content,
  ) {
    final text = '$title $content'.trim();

    for (final bank in _bankPatterns) {
      if (packageName.startsWith(bank.packageName)) {
        for (final pattern in bank.patterns) {
          final result = _tryMatch(pattern, text);
          if (result.isValid) return result;
        }
      }
    }

    // Generic fallback for any Brazilian bank amount pattern
    return _tryMatch(r'R\$\s*(?<amount>[\d.,]+)\s+(?<merchant>.*)', text);
  }

  static ParsedNotification parseWithCustomPattern(
    String pattern,
    String text,
  ) {
    return _tryMatch(pattern, text);
  }

  static bool testPattern(String pattern, String sampleText) {
    try {
      return _tryMatch(pattern, sampleText).isValid;
    } catch (_) {
      return false;
    }
  }

  static ParsedNotification _tryMatch(String pattern, String text) {
    try {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match == null) return const ParsedNotification();

      final amountStr = match.namedGroup('amount');
      if (amountStr == null) return const ParsedNotification();

      final merchant = match.namedGroup('merchant')?.trim();
      final amount = _parseAmount(amountStr);

      return ParsedNotification(
        amountInCents: amount,
        merchant: (merchant?.isNotEmpty ?? false) ? merchant : null,
        description: text,
      );
    } catch (_) {
      return const ParsedNotification();
    }
  }

  // Handles: "1.234,56" → 123456 and "1234.56" → 123456
  static int? _parseAmount(String raw) {
    String normalized = raw.trim();
    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (normalized.contains(',')) {
      normalized = normalized.replaceAll(',', '.');
    }
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * 100).round();
  }
}
