import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/features/gamification/domain/services/badge_checker.dart';
import 'package:bestfin/features/gamification/domain/services/insights_service.dart';

/// Conquistas: sequências (streaks), medalhas e os insights financeiros —
/// os mesmos do hub de gamificação da GUI.
class GamificationScreen extends Screen {
  GamificationScreen(super.ctx);

  @override
  String get title => 'Conquistas e insights';

  @override
  Future<void> run() async {
    while (true) {
      final choice = Term.select(
        title,
        items: const [
          'Sequências (streaks)',
          'Medalhas',
          'Insights financeiros',
          'Reavaliar medalhas e sequências',
        ],
      );
      if (choice == null) return;

      switch (choice) {
        case 0:
          await _streaks();
        case 1:
          await _badges();
        case 2:
          await _insights();
        case 3:
          await _recheck();
      }
    }
  }

  Future<void> _streaks() async {
    final streaks = await ctx.streaks.watchAllStreaks().first;
    Term.pager('Sequências', [
      '',
      if (streaks.isEmpty)
        '  ${Term.gray}Nenhuma sequência registrada ainda.${Term.reset}',
      ...streaks.map(
        (s) =>
            '  ${Term.pad(s.type.label, 24)} '
            '${Term.bold}${s.currentCount}${Term.reset} dia(s) '
            '${Term.gray}• recorde ${s.longestCount}'
            '${s.lastDate == null ? '' : ' • último ${Term.formatDate(s.lastDate!)}'}'
            '${s.isActive ? '' : ' • inativa'}${Term.reset}',
      ),
      '',
    ]);
  }

  Future<void> _badges() async {
    final badges = await ctx.db.badgesDao.getAllBadges();
    final unlocked = badges.where((b) => b.unlockedAt != null).length;
    Term.pager('Medalhas', [
      '',
      if (badges.isEmpty)
        '  ${Term.gray}Nenhuma medalha cadastrada.${Term.reset}',
      ...badges.map((b) {
        final done = b.unlockedAt != null;
        final mark = done ? Term.c('✓', Term.green) : Term.c('·', Term.gray);
        return '  $mark ${Term.pad(b.title, 28)} '
            '${Term.gray}${Term.truncate(b.description, 40)}${Term.reset}'
            '${done ? ' ${Term.gray}${Term.formatDate(b.unlockedAt!)}${Term.reset}' : ''}';
      }),
      '',
    ], subtitle: '$unlocked de ${badges.length} desbloqueadas');
  }

  Future<void> _insights() async {
    Term.clear();
    Term.header('Insights financeiros');
    Term.writeln();
    Term.writeln('  ${Term.gray}Analisando seus dados…${Term.reset}');

    final service = InsightsService(
      transactionRepository: ctx.transactions,
      db: ctx.db,
      accountRepository: ctx.accounts,
      goalRepository: ctx.goals,
      investmentRepository: ctx.investments,
    );

    try {
      final insights = await service.generateInsights();
      Term.pager('Insights financeiros', [
        '',
        if (insights.isEmpty)
          '  ${Term.gray}Sem insights no momento.${Term.reset}',
        for (final i in insights) ...[
          '  ${i.icon} ${Term.bold}${i.category?.name ?? 'geral'}${Term.reset}',
          ..._wrap(i.text, Term.width - 6).map((l) => '     $l'),
          '',
        ],
      ]);
    } catch (e) {
      Term.error(Screen.describeError(e));
      Term.pause();
    }
  }

  /// Quebra o texto do insight em linhas que cabem no terminal.
  List<String> _wrap(String text, int cols) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = StringBuffer();
    for (final w in words) {
      if (current.isEmpty) {
        current.write(w);
      } else if (current.length + 1 + w.length <= cols) {
        current.write(' $w');
      } else {
        lines.add(current.toString());
        current = StringBuffer(w);
      }
    }
    if (current.isNotEmpty) lines.add(current.toString());
    return lines;
  }

  Future<void> _recheck() async {
    Term.clear();
    Term.header('Reavaliar conquistas');
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}Recalcula sequências e verifica todas as medalhas '
      'com base nos dados atuais.${Term.reset}',
    );
    Term.writeln();
    if (!Term.confirm('Executar agora?', defaultYes: true)) return;

    await guard(() async {
      await ctx.streaks.checkAndResetStreaks();
      await BadgeChecker(
        badgesDao: ctx.db.badgesDao,
        transactionRepository: ctx.transactions,
        goalRepository: ctx.goals,
        investmentRepository: ctx.investments,
        financingRepository: ctx.financings,
        accountRepository: ctx.accounts,
        categoryRepository: ctx.categories,
        creditCardRepository: ctx.creditCards,
        streakRepository: ctx.streaks,
      ).checkAllBadges();
    }, successMessage: 'Conquistas reavaliadas.');
  }
}
