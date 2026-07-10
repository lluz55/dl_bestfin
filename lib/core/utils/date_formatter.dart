class DateFormatter {
  /// Formata data no formato: "28/05/2026"
  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  /// Formata data e hora no formato: "28/05/2026 às 14:30"
  static String formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year às $hour:$minute';
  }

  /// Formata data curta no formato: "28 de Mai"
  static String formatDayMonth(DateTime date) {
    final day = date.day;
    final monthNames = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    final monthStr = monthNames[date.month - 1];
    return '$day de $monthStr';
  }

  /// Formata mês e ano no formato: "Maio de 2026"
  static String formatFullMonthYear(DateTime date) {
    final monthNames = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    final monthStr = monthNames[date.month - 1];
    return '$monthStr de ${date.year}';
  }

  /// Cabeçalho para agrupar transações por dia: "Hoje", "Ontem" ou "28 de Mai — qui"
  static String dayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Hoje';
    if (d == yesterday) return 'Ontem';
    return formatDayMonth(date);
  }

  /// Formata hora: "14:30"
  static String formatTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Formata a data de forma relativa: "Hoje", "Ontem", "dd/mm" (ano atual) ou "dd/mm/aaaa" (ano diferente)
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    if (compareDate == today) {
      return 'Hoje';
    } else if (compareDate == yesterday) {
      return 'Ontem';
    } else {
      if (date.year == now.year) {
        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        return '$day/$month';
      } else {
        return formatDate(date);
      }
    }
  }
}
