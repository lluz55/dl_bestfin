import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bestfin/cli/tui/screens/base.dart';
import 'package:bestfin/cli/tui/term.dart';
import 'package:bestfin/core/constants/default_categories.dart';
import 'package:bestfin/core/database/app_database.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/providers/reminders_settings_provider.dart';
import 'package:bestfin/core/providers/user_profile_provider.dart';

/// Configurações: preferências do app, chaves guardadas no banco,
/// diagnóstico do arquivo e o "limpar todos os dados".
class SettingsScreen extends Screen {
  SettingsScreen(super.ctx);

  @override
  String get title => 'Configurações';

  @override
  Future<void> run() async {
    while (true) {
      final choice = Term.select(
        title,
        items: const [
          'Preferências do app',
          'Conta padrão para novos lançamentos',
          'Configurações guardadas no banco',
          'Informações do banco de dados',
          'Limpar todos os dados',
        ],
        subtitle: ctx.dbPath,
      );
      if (choice == null) return;

      switch (choice) {
        case 0:
          await _preferences();
        case 1:
          await _defaultAccount();
        case 2:
          await _dbSettings();
        case 3:
          await _dbInfo();
        case 4:
          await _clearAll();
      }
    }
  }

  // ── Preferências (SharedPreferences) ───────────────────────────────

  /// As preferências de interface moram no mesmo armazenamento que a GUI usa.
  /// Fora do processo gráfico ele pode não estar disponível — nesse caso a
  /// tela explica em vez de estourar.
  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      Term.clear();
      Term.header('Preferências do app');
      Term.writeln();
      Term.warn(
        'As preferências de interface (tema, privacidade, lembretes) ficam no '
        'armazenamento do app gráfico, que não está acessível a partir do '
        'terminal neste ambiente.',
      );
      Term.writeln();
      Term.writeln('  ${Term.gray}Detalhe: $e${Term.reset}');
      Term.writeln();
      Term.pause();
      return null;
    }
  }

  Future<void> _preferences() async {
    final prefs = await _prefs();
    if (prefs == null) return;

    while (true) {
      final name = prefs.getString(kUserNameKey) ?? '(não definido)';
      final alwaysHide = prefs.getBool(kAlwaysHideValuesKey) ?? false;
      final hidden = prefs.getBool(kValuesHiddenKey) ?? false;
      final reminders = prefs.getBool(kRemindersEnabledKey) ?? true;
      final leadTime = prefs.getInt(kReminderLeadTimeDaysKey) ?? 1;

      final choice = Term.select(
        'Preferências do app',
        items: [
          'Nome exibido: $name',
          'Sempre ocultar valores: ${alwaysHide ? 'sim' : 'não'}',
          'Valores ocultos agora: ${hidden ? 'sim' : 'não'}',
          'Lembretes de lançamentos: ${reminders ? 'ativos' : 'desativados'}',
          'Antecedência do lembrete: $leadTime dia(s)',
        ],
      );
      if (choice == null) return;

      switch (choice) {
        case 0:
          final value = Term.input(
            'Nome exibido:',
            initial: prefs.getString(kUserNameKey) ?? '',
          );
          if (value == null) break;
          if (value.trim().isEmpty) {
            await prefs.remove(kUserNameKey);
          } else {
            await prefs.setString(kUserNameKey, value.trim());
          }
        case 1:
          await prefs.setBool(kAlwaysHideValuesKey, !alwaysHide);
        case 2:
          await prefs.setBool(kValuesHiddenKey, !hidden);
        case 3:
          await prefs.setBool(kRemindersEnabledKey, !reminders);
        case 4:
          final days = Term.inputInt(
            'Antecedência em dias',
            initial: leadTime,
            min: 0,
            max: 30,
          );
          if (days != null) await prefs.setInt(kReminderLeadTimeDaysKey, days);
      }
    }
  }

  Future<void> _defaultAccount() async {
    final prefs = await _prefs();
    if (prefs == null) return;

    final current = prefs.getString(kDefaultAccountIdKey);
    final accounts = await ctx.rawAccounts();
    final currentName = current == null
        ? '(seleção automática)'
        : accounts.where((a) => a.id == current).firstOrNull?.name ?? current;

    final (chose, account) = await pickAccountOptional(
      'Conta padrão (atual: $currentName)',
      noneLabel: '(seleção automática)',
    );
    if (!chose) return;

    if (account == null) {
      await prefs.remove(kDefaultAccountIdKey);
      Term.success('Conta padrão removida — o app escolhe automaticamente.');
    } else {
      await prefs.setString(kDefaultAccountIdKey, account.id);
      Term.success('Conta padrão: ${account.name}');
    }
    Term.pause();
  }

  // ── app_settings (chave/valor no banco) ────────────────────────────

  Future<void> _dbSettings() async {
    while (true) {
      final rows = await ctx.db.select(ctx.db.appSettings).get();

      final items = rows
          .map(
            (r) =>
                '${Term.pad(r.key, 30)} '
                '${Term.gray}${Term.truncate(r.value, Term.width - 40)}${Term.reset}',
          )
          .toList();

      final choice = listMenu(
        'Configurações no banco',
        items: items,
        subtitle: 'sincronizadas junto com os demais dados',
        emptyMessage: 'Nenhuma configuração gravada no banco.',
        actions: const [
          TermAction('n', 'nova'),
          TermAction('e', 'editar'),
          TermAction('d', 'excluir'),
        ],
      );
      if (choice == null) return;

      final (key, i) = choice;
      final row = i >= 0 && i < rows.length ? rows[i] : null;
      switch (key) {
        case 'n':
          await _upsertSetting();
        case 'e':
        case '':
          if (row != null) await _upsertSetting(existing: row);
        case 'd':
          if (row != null) {
            if (!Term.confirm('Excluir a chave "${row.key}"?')) break;
            await guard(
              () => (ctx.db.delete(
                ctx.db.appSettings,
              )..where((t) => t.key.equals(row.key))).go(),
              successMessage: 'Chave removida.',
            );
          }
      }
    }
  }

  Future<void> _upsertSetting({AppSetting? existing}) async {
    Term.clear();
    Term.header(
      existing == null ? 'Nova configuração' : 'Editar ${existing.key}',
    );
    Term.writeln();

    String? key = existing?.key;
    if (existing == null) {
      key = Term.input('Chave:', allowEmpty: false);
      if (key == null || key.trim().isEmpty) return;
      key = key.trim();
    }

    final value = Term.input('Valor:', initial: existing?.value ?? '');
    if (value == null) return;

    await guard(
      () => ctx.db
          .into(ctx.db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: key!,
              value: value,
              updatedAt: Value(DateTime.now()),
            ),
          ),
      successMessage: 'Configuração salva.',
    );
  }

  // ── Diagnóstico ────────────────────────────────────────────────────

  Future<void> _dbInfo() async {
    final file = File(ctx.dbPath);
    final size = file.existsSync() ? file.lengthSync() : 0;

    Future<int> count(String table) async {
      final result = await ctx.db
          .customSelect('SELECT COUNT(*) AS c FROM $table')
          .getSingle();
      return result.data['c'] as int;
    }

    final counts = <String, int>{};
    for (final table in const [
      'transactions',
      'entries',
      'accounts',
      'categories',
      'budgets',
      'goals',
      'credit_cards',
      'invoices',
      'investments',
      'financings',
      'recurring_rules',
      'installment_plans',
      'households',
      'sync_queue',
    ]) {
      try {
        counts[table] = await count(table);
      } catch (_) {
        // Tabela ausente numa versão antiga do schema — só não é listada.
      }
    }

    Term.pager('Banco de dados', [
      '',
      '  Arquivo:        ${ctx.dbPath}',
      '  Tamanho:        ${(size / 1024).toStringAsFixed(1)} KiB',
      '  Versão schema:  ${ctx.db.schemaVersion}',
      '',
      '  ${Term.bold}Registros por tabela${Term.reset}',
      ...counts.entries.map(
        (e) => '    ${Term.pad(e.key, 22)} ${Term.padLeft('${e.value}', 8)}',
      ),
      '',
    ]);
  }

  // ── Limpar tudo ────────────────────────────────────────────────────

  Future<void> _clearAll() async {
    Term.clear();
    Term.header('Limpar todos os dados');
    Term.writeln();
    Term.warn(
      'Apaga contas, lançamentos, metas, cartões, orçamentos e todo o resto '
      'deste dispositivo, permanentemente.',
    );
    Term.writeln();
    Term.writeln(
      '  ${Term.gray}As categorias padrão são recriadas ao final. '
      'Faça um backup antes se tiver qualquer dúvida.${Term.reset}',
    );
    Term.writeln();

    if (!Term.confirm('Tem certeza?')) return;
    final typed = Term.input('Digite APAGAR para confirmar:');
    if (typed?.trim().toUpperCase() != 'APAGAR') {
      Term.writeln();
      Term.writeln('Cancelado.');
      Term.pause();
      return;
    }

    await guard(() async {
      final db = ctx.db;
      await db.transaction(() async {
        await db.delete(db.attachments).go();
        await db.delete(db.entries).go();
        await db.delete(db.transactionSplits).go();
        await db.delete(db.scheduledReminders).go();
        await db.delete(db.transactions).go();
        await db.delete(db.invoices).go();
        await db.delete(db.creditCards).go();
        await db.delete(db.investments).go();
        await db.delete(db.financingInstallments).go();
        await db.delete(db.financings).go();
        await db.delete(db.recurringRules).go();
        await db.delete(db.installmentPlans).go();
        await db.delete(db.goalCategories).go();
        await db.delete(db.goals).go();
        await db.delete(db.budgets).go();
        await db.delete(db.holidays).go();
        await db.delete(db.entities).go();
        await db.delete(db.reconciliationCheckpoints).go();
        await db.delete(db.accounts).go();
        await db.delete(db.categoryParents).go();
        await db.delete(db.categories).go();
        await db.delete(db.appSettings).go();
        await db.delete(db.badges).go();
        await db.delete(db.streaks).go();
        await db.delete(db.householdMembers).go();
        await db.delete(db.households).go();
        await db.delete(db.chatMessages).go();
        await db.delete(db.syncQueue).go();
        await db.delete(db.nostrEventLog).go();

        // Re-seed das categorias padrão na mesma transação, como faz a GUI.
        await db.batch((batch) {
          batch.insertAll(
            db.categories,
            SeedDataConstants.defaultCategories
                .map(
                  (c) => CategoriesCompanion.insert(
                    id: c.id,
                    name: c.name,
                    icon: c.icon,
                    color: c.color,
                    type: c.type.name,
                    isSystem: const Value(true),
                    description: Value(c.description),
                  ),
                )
                .toList(),
          );
        });

        await db.batch((batch) {
          batch.insertAll(
            db.categoryParents,
            SeedDataConstants.defaultCategoryRelationships
                .map(
                  (r) => CategoryParentsCompanion.insert(
                    parentCategoryId: r.$1,
                    childCategoryId: r.$2,
                  ),
                )
                .toList(),
          );
        });
      });
    }, successMessage: 'Todos os dados foram apagados.');
  }
}
