import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:drift/drift.dart' show Value;
import 'package:bestfin/core/constants/app_info.dart';
import 'package:bestfin/core/constants/default_categories.dart';
import 'package:bestfin/core/database/app_database.dart' hide Account;
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/notifications/notification_service.dart';
import 'package:bestfin/core/notifications/reminder_provider.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/theme/theme_provider.dart';
import 'package:bestfin/core/theme/theme_settings_sheet.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:bestfin/features/onboarding/presentation/providers/tutorial_provider.dart';
import 'package:bestfin/features/security/presentation/providers/security_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/providers/user_profile_provider.dart';
import 'package:bestfin/core/widgets/profile_avatar.dart';
import 'package:bestfin/core/widgets/profile_editor.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/core/providers/sidebar_shortcuts_provider.dart';
import 'package:bestfin/core/providers/reminders_settings_provider.dart';
import 'package:bestfin/features/backup/presentation/screens/backup_screen.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/dashboard/presentation/providers/home_widgets_provider.dart';
import 'package:bestfin/features/dashboard/presentation/providers/shortcuts_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bestfin/features/sync/domain/models/app_update_info.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

final _androidNotificationsEnabledProvider = FutureProvider.autoDispose<bool>((
  ref,
) {
  return areAndroidNotificationsEnabled();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// Itens de configuração que abrem um sub-conteúdo. Em telas grandes esse
/// sub-conteúdo é exibido na segunda coluna (master-detail) em vez de um modal.
enum _SettingsDetail {
  profile,
  theme,
  defaultAccount,
  reminderLeadTime,
  backup,
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _auth = LocalAuthentication();
  bool _biometricsAvailable = false;
  bool _clearing = false;

  /// Detalhe selecionado exibido na segunda coluna em telas grandes.
  _SettingsDetail _selectedDetail = _SettingsDetail.theme;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      setState(() => _biometricsAvailable = canCheck && supported);
    } catch (_) {}
  }

  Future<void> _toggleBiometrics(bool enabled) async {
    if (enabled) {
      try {
        final authenticated = await _auth.authenticate(
          localizedReason: 'Confirme para ativar a proteção biométrica',
        );
        if (!authenticated || !mounted) return;
      } catch (_) {
        return;
      }
      // Must set up PIN as fallback before enabling biometrics
      final result = await context.push<bool>('/security/pin-setup');
      if (result != true || !mounted) return;
      await OnboardingActions.setBiometrics(ref, true);
    } else {
      await SecurityActions.clearPin();
      await OnboardingActions.setBiometrics(ref, false);
    }
  }

  Future<void> _changePin() async {
    await context.push<bool>('/security/pin-setup');
  }

  Future<void> _clearAllData() async {
    if (_clearing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = ctx.colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Limpar todos os dados?'),
          content: const Text(
            'Esta ação é irreversível. Todas as contas, transações, metas e demais dados serão apagados permanentemente.\n\n'
            'Este dispositivo também será desconectado da sincronização — sem isso os dados voltariam dos relays. Dados já sincronizados permanecem nos outros dispositivos.\n\n'
            'As categorias padrão serão restauradas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            AppButton(
              label: 'Apagar tudo',
              variant: AppButtonVariant.destructive,
              size: AppButtonSize.compact,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    _clearing = true;

    // Referências capturadas ANTES do await: a navegação para o onboarding
    // dispara o guard do router, que desmonta esta tela. Depender de
    // `context`/`mounted` depois do await era frágil — usamos o
    // GoRouter/messenger capturados para não esbarrar em contexto defunto.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Capturado antes do reset do provider — o arquivo em si é removido na
    // limpeza em segundo plano no fim deste método.
    final profilePhotoPath = ref.read(userProfileProvider).photoPath;

    // Encerra o sync SEM bloquear: invalida a identidade em memória agora
    // (impede o onboarding de re-sincronizar) e fecha os WebSockets dos relays
    // em segundo plano. Fechar sockets de relays lentos podia travar por tempo
    // indeterminado — era o que deixava o spinner girando "para sempre".
    ref.read(nostrSyncServiceProvider).signOutInBackground();

    // Único passo bloqueante: o wipe do banco local (rápido). Precisa concluir
    // antes do onboarding para que o app comece limpo e com as categorias padrão.
    try {
      final db = ref.read(databaseProvider);
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
        await db.delete(db.notificationPatterns).go();
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

        // Re-seed dentro da mesma transação para manter atomicidade.
        await db.batch((batch) {
          batch.insertAll(
            db.categories,
            SeedDataConstants.defaultCategories.map((c) {
              return CategoriesCompanion.insert(
                id: c.id,
                name: c.name,
                icon: c.icon,
                color: c.color,
                type: c.type.name,
                isSystem: const Value(true),
                description: Value(c.description),
              );
            }).toList(),
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
    } catch (e, st) {
      debugPrint('[ClearAll] Erro ao apagar dados: $e\n$st');
      _clearing = false;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao apagar dados: $e'),
          backgroundColor: messenger.context.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    // Descarta a instância antiga do banco: o onDispose do provider fecha a
    // conexão em segundo plano (não aguardamos o close(), que pode travar se
    // houver watchers pendentes — isso interrompia o retorno ao onboarding).
    // Uma nova instância é criada sob demanda. O drift pode logar um aviso de
    // "múltiplas instâncias" nessa transição; é benigno (só em debug) e não
    // afeta o fluxo.
    ref.invalidate(databaseProvider);

    // Reset global settings/onboarding variables
    initialOnboardingCompleted = false;
    initialOnboardingStep = 0;
    initialOnboardingAccountDraft = null;
    initialBiometricsEnabled = false;
    initialValuesHidden = false;
    initialAlwaysHideValues = false;
    initialIsLocked = false;
    initialUserName = null;
    initialUserPhotoPath = null;
    initialTutorialSeen = false;

    // Reset provider states
    ref.read(onboardingCompletedProvider.notifier).set(false);
    ref.read(biometricsEnabledProvider.notifier).set(false);
    ref.read(tutorialSeenProvider.notifier).set(false);
    ref.read(isLockedProvider.notifier).unlock();

    // Invalidate providers to force them to reload from the cleared state
    ref.invalidate(onboardingAccountDraftProvider);
    ref.invalidate(themeProvider);
    ref.invalidate(valuesHiddenProvider);
    ref.invalidate(alwaysHideValuesProvider);
    ref.invalidate(homeWidgetsProvider);
    ref.invalidate(shortcutsProvider);
    ref.invalidate(sidebarShortcutsProvider);
    ref.invalidate(userProfileProvider);

    // Navega imediatamente. `set(false)` acima já reabilita a rota /onboarding
    // no guard, então o go() não é rebatido para /home. Usa o router capturado
    // (não `context`) porque a própria navegação desmonta esta tela.
    router.go('/onboarding');

    // Limpeza secundária em segundo plano — roda enquanto o usuário já usa o
    // onboarding. Nada aqui bloqueia o retorno ao início do setup.
    unawaited(() async {
      try {
        await SecurityActions.clearPin();
      } catch (e) {
        debugPrint('[ClearAll] clearPin falhou: $e');
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (e) {
        debugPrint('[ClearAll] prefs.clear falhou: $e');
      }
      if (profilePhotoPath != null) {
        try {
          final photo = File(profilePhotoPath);
          if (await photo.exists()) await photo.delete();
        } catch (e) {
          debugPrint('[ClearAll] remoção da foto de perfil falhou: $e');
        }
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final themeState = ref.watch(themeProvider);
    final biometricsEnabled = ref.watch(biometricsEnabledProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(
        title: 'Configurações',
        infoDescription: 'Personalize o BestFin: tema, moeda, segurança com biometria/PIN, perfil do usuário, preferências do app e muito mais.',
        infoFeatures: [
          'Tema claro/escuro e cores dinâmicas',
          'Moeda e formato regional',
          'Segurança com PIN e biometria',
          'Perfil do usuário com nome e foto',
          'Informações do app e versão',
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Em telas largas (tablet/iPad, desktop) usamos um layout
          // master-detail: a lista de configurações fica na coluna esquerda e
          // o sub-conteúdo do item selecionado aparece na coluna direita, em
          // vez de abrir modais.
          final splitView = constraints.maxWidth >= Breakpoints.medium;
          final sections = _buildSections(
            cs,
            tt,
            themeState,
            biometricsEnabled,
            splitView: splitView,
          );

          final list = ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              for (final section in sections) ...[
                section,
                const SizedBox(height: 8),
              ],
            ],
          );

          if (!splitView) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: list,
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 380, child: list),
                  VerticalDivider(width: 1, color: cs.outlineVariant),
                  Expanded(child: _buildDetailPane(cs, tt)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSections(
    ColorScheme cs,
    TextTheme tt,
    ThemeState themeState,
    bool biometricsEnabled, {
    required bool splitView,
  }) {
    return [
      _SettingsSection(
        title: 'Perfil',
        cs: cs,
        tt: tt,
        tiles: [
          _ProfileTile(
            cs: cs,
            tt: tt,
            selected: splitView && _selectedDetail == _SettingsDetail.profile,
            onTap: () => _openDetail(
              splitView,
              _SettingsDetail.profile,
              () => _showProfileSheet(context),
            ),
          ),
        ],
      ),
      _SettingsSection(
        title: 'Aparência',
        cs: cs,
        tt: tt,
        tiles: [
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Tema',
            subtitle: _themeSubtitle(themeState),
            cs: cs,
            tt: tt,
            selected: splitView && _selectedDetail == _SettingsDetail.theme,
            onTap: () => _openDetail(
              splitView,
              _SettingsDetail.theme,
              () => showThemeSettingsSheet(context),
            ),
          ),
        ],
      ),
      _SettingsSection(
        title: 'Privacidade',
        cs: cs,
        tt: tt,
        tiles: [
          _SettingsTile(
            icon: Icons.visibility_off_outlined,
            title: 'Ocultar valores',
            subtitle: 'Ocultar saldos por padrão ao abrir',
            cs: cs,
            tt: tt,
            trailing: Switch(
              value: ref.watch(alwaysHideValuesProvider),
              onChanged: (v) =>
                  ref.read(alwaysHideValuesProvider.notifier).set(v),
            ),
          ),
        ],
      ),
      if (_biometricsAvailable)
        _SettingsSection(
          title: 'Segurança',
          cs: cs,
          tt: tt,
          tiles: [
            _SettingsTile(
              icon: Icons.fingerprint_rounded,
              title: 'Biometria',
              subtitle: biometricsEnabled
                  ? 'Ativada'
                  : 'Exigir biometria ao abrir o app',
              cs: cs,
              tt: tt,
              trailing: Switch(
                value: biometricsEnabled,
                onChanged: _toggleBiometrics,
              ),
            ),
            if (biometricsEnabled)
              _SettingsTile(
                icon: Icons.pin_outlined,
                title: 'Alterar PIN',
                subtitle: 'Mudar o PIN de desbloqueio',
                cs: cs,
                tt: tt,
                onTap: _changePin,
              ),
          ],
        ),
      _SettingsSection(
        title: 'Transações',
        cs: cs,
        tt: tt,
        tiles: [
          _DefaultAccountTile(
            cs: cs,
            tt: tt,
            selected:
                splitView && _selectedDetail == _SettingsDetail.defaultAccount,
            onOpenDetail: splitView
                ? () => setState(
                    () => _selectedDetail = _SettingsDetail.defaultAccount,
                  )
                : null,
          ),
        ],
      ),
      _SettingsSection(
        title: 'Notificações',
        cs: cs,
        tt: tt,
        tiles: [
          _SettingsTile(
            icon: Icons.notifications_active_outlined,
            title: 'Lembretes de transações agendadas',
            subtitle: 'Avisar antes de transações e recorrências futuras',
            cs: cs,
            tt: tt,
            trailing: Switch(
              value: ref.watch(remindersEnabledProvider),
              onChanged: (v) async {
                await ref.read(remindersEnabledProvider.notifier).set(v);
                unawaited(ref.read(reminderReconcileProvider.future));
              },
            ),
          ),
          if (ref.watch(remindersEnabledProvider)) ...[
            _SettingsTile(
              icon: Icons.schedule_outlined,
              title: 'Antecedência do lembrete',
              subtitle: ref.watch(reminderLeadTimeProvider).label,
              cs: cs,
              tt: tt,
              selected:
                  splitView &&
                  _selectedDetail == _SettingsDetail.reminderLeadTime,
              onTap: () => _openDetail(
                splitView,
                _SettingsDetail.reminderLeadTime,
                () => _showLeadTimePicker(context, ref),
              ),
            ),
            if (Platform.isAndroid) const _AndroidNotificationPermissionTile(),
          ],
        ],
      ),
      _SettingsSection(
        title: 'Dados',
        cs: cs,
        tt: tt,
        tiles: [
          _SettingsTile(
            icon: Icons.import_export_rounded,
            title: 'Exportar e importar dados',
            subtitle: 'Backup e restauração em JSON, CSV, PDF ou SQLite',
            cs: cs,
            tt: tt,
            selected: splitView && _selectedDetail == _SettingsDetail.backup,
            onTap: () => _openDetail(
              splitView,
              _SettingsDetail.backup,
              () => context.push('/backup'),
            ),
          ),
          _SettingsTile(
            icon: Icons.delete_sweep_rounded,
            title: 'Limpar todos os dados',
            subtitle: 'Apaga tudo permanentemente',
            cs: cs,
            tt: tt,
            iconColor: cs.error,
            onTap: _clearAllData,
          ),
        ],
      ),
      _SettingsSection(
        title: 'Ajuda',
        cs: cs,
        tt: tt,
        tiles: [
          _SettingsTile(
            icon: Icons.school_outlined,
            title: 'Rever tutorial',
            subtitle: 'Exibir novamente o guia de primeiros passos',
            cs: cs,
            tt: tt,
            onTap: _replayTutorial,
          ),
        ],
      ),
      _SettingsSection(
        title: 'Sobre',
        cs: cs,
        tt: tt,
        tiles: [
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Versão',
            subtitle: kAppVersion,
            cs: cs,
            tt: tt,
          ),
          if (ref.watch(appUpdateProvider).value case final update?)
            _UpdateAvailableTile(update: update, cs: cs, tt: tt),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de Privacidade',
            subtitle: 'Seus dados ficam apenas no dispositivo',
            cs: cs,
            tt: tt,
          ),
        ],
      ),
    ];
  }

  /// Redefine o tutorial e volta ao início, onde os coach marks reaparecem.
  Future<void> _replayTutorial() async {
    await TutorialActions.reset(ref);
    if (!mounted) return;
    context.go('/home');
  }

  /// Em telas grandes, seleciona o detalhe para exibir na coluna direita; em
  /// telas compactas, mantém o comportamento de abrir um modal.
  void _openDetail(
    bool splitView,
    _SettingsDetail detail,
    VoidCallback showModal,
  ) {
    if (splitView) {
      setState(() => _selectedDetail = detail);
    } else {
      showModal();
    }
  }

  Widget _buildDetailPane(ColorScheme cs, TextTheme tt) {
    final content = switch (_selectedDetail) {
      _SettingsDetail.profile => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seu perfil',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Nome e foto exibidos na tela inicial',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: const ProfileEditor(),
              ),
            ),
          ],
        ),
      ),
      _SettingsDetail.theme => const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: ThemeSettingsView(),
      ),
      _SettingsDetail.defaultAccount => const _DefaultAccountDetailPane(),
      _SettingsDetail.reminderLeadTime => const _ReminderLeadTimeDetailPane(),
      _SettingsDetail.backup => const BackupView(),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      // Alinha o sub-conteúdo ao topo (o padrão do AnimatedSwitcher é centralizar,
      // o que deixava a página de tema verticalmente centrada).
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      child: KeyedSubtree(key: ValueKey(_selectedDetail), child: content),
    );
  }

  String _themeSubtitle(ThemeState state) {
    final source = state.useDynamicColor
        ? 'Cores do papel de parede'
        : 'Cor personalizada';
    final mode = switch (state.mode) {
      ThemeMode.system => 'brilho do sistema',
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'escuro',
    };
    return '$source • $mode';
  }

  void _showProfileSheet(BuildContext context) {
    showAdaptiveModal<void>(
      context: context,
      builder: (ctx) {
        final tt = ctx.textTheme;
        return Padding(
          // Mantém o formulário acima do teclado quando o campo de nome
          // está em foco.
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seu perfil',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nome e foto exibidos na tela inicial',
                  style: tt.bodySmall?.copyWith(
                    color: ctx.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                const ProfileEditor(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLeadTimePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(reminderLeadTimeProvider);
    showAdaptiveModal<void>(
      context: context,
      builder: (context) {
        final cs = context.colorScheme;
        final tt = context.textTheme;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Antecedência do lembrete',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              for (final preset in ReminderLeadTime.values)
                ListTile(
                  title: Text(preset.label),
                  selected: current == preset,
                  selectedColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () async {
                    await ref
                        .read(reminderLeadTimeProvider.notifier)
                        .set(preset);
                    unawaited(ref.read(reminderReconcileProvider.future));
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Tile da seção Perfil: mostra o avatar e o nome atuais e abre o editor
/// (modal em telas compactas, coluna de detalhe em telas largas).
class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({
    required this.cs,
    required this.tt,
    required this.onTap,
    this.selected = false,
  });

  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return ListTile(
      selected: selected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.4),
      leading: ProfileAvatar(profile: profile, radius: 20),
      title: Text(
        profile.hasName ? profile.name! : 'Seu perfil',
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Nome e foto exibidos na tela inicial',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}

class _DefaultAccountTile extends ConsumerWidget {
  const _DefaultAccountTile({
    required this.cs,
    required this.tt,
    this.selected = false,
    this.onOpenDetail,
  });

  final ColorScheme cs;
  final TextTheme tt;

  /// Destaca o tile quando seu detalhe está aberto na coluna direita.
  final bool selected;

  /// Quando não nulo (telas grandes), abre o detalhe na segunda coluna em vez
  /// do modal.
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider);
    final defaultId = ref.watch(defaultAccountIdProvider);
    final defaultAccount = accounts.where((a) => a.id == defaultId).firstOrNull;

    return ListTile(
      selected: selected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.account_balance_wallet_outlined,
          size: 20,
          color: cs.onSurface,
        ),
      ),
      title: Text(
        'Conta padrão',
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        defaultAccount?.name ?? 'Nenhuma (seleção automática)',
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap:
          onOpenDetail ??
          () => _showAccountPicker(context, ref, accounts, defaultId),
    );
  }

  void _showAccountPicker(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts,
    String? currentDefaultId,
  ) {
    showAdaptiveModal<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conta padrão',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecionada automaticamente em novas transações',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    Icons.auto_awesome_outlined,
                    color: cs.onSurfaceVariant,
                  ),
                  title: const Text('Nenhuma (seleção automática)'),
                  selected: currentDefaultId == null,
                  selectedColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    ref.read(defaultAccountIdProvider.notifier).set(null);
                    Navigator.pop(ctx);
                  },
                ),
                for (final account in accounts)
                  ListTile(
                    leading: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                    title: Text(account.name),
                    subtitle: Text(account.type.label),
                    selected: account.id == currentDefaultId,
                    selectedColor: cs.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      ref
                          .read(defaultAccountIdProvider.notifier)
                          .set(account.id);
                      Navigator.pop(ctx);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Painel de detalhe (coluna direita, telas grandes) para escolher a conta
/// padrão. Espelha o conteúdo do `_showAccountPicker`, mas sem fechar nada — a
/// seleção apenas atualiza o provider e o próprio painel reflete o estado.
class _DefaultAccountDetailPane extends ConsumerWidget {
  const _DefaultAccountDetailPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final accounts = ref.watch(activeAccountsProvider);
    final currentDefaultId = ref.watch(defaultAccountIdProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Text(
          'Conta padrão',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Selecionada automaticamente em novas transações',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: Icon(
            Icons.auto_awesome_outlined,
            color: cs.onSurfaceVariant,
          ),
          title: const Text('Nenhuma (seleção automática)'),
          selected: currentDefaultId == null,
          selectedColor: cs.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: () => ref.read(defaultAccountIdProvider.notifier).set(null),
        ),
        for (final account in accounts)
          ListTile(
            leading: Icon(
              Icons.account_balance_wallet_outlined,
              color: cs.onSurfaceVariant,
            ),
            title: Text(account.name),
            subtitle: Text(account.type.label),
            selected: account.id == currentDefaultId,
            selectedColor: cs.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () =>
                ref.read(defaultAccountIdProvider.notifier).set(account.id),
          ),
      ],
    );
  }
}

/// Painel de detalhe (coluna direita, telas grandes) para a antecedência do
/// lembrete. Espelha o `_showLeadTimePicker` sem fechar nada.
class _ReminderLeadTimeDetailPane extends ConsumerWidget {
  const _ReminderLeadTimeDetailPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final current = ref.watch(reminderLeadTimeProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Text(
          'Antecedência do lembrete',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        for (final preset in ReminderLeadTime.values)
          ListTile(
            title: Text(preset.label),
            selected: current == preset,
            selectedColor: cs.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onTap: () async {
              await ref.read(reminderLeadTimeProvider.notifier).set(preset);
              unawaited(ref.read(reminderReconcileProvider.future));
            },
          ),
      ],
    );
  }
}

class _AndroidNotificationPermissionTile extends ConsumerWidget {
  const _AndroidNotificationPermissionTile();

  Future<void> _requestPermission(BuildContext context, WidgetRef ref) async {
    final granted = await requestAndroidNotificationPermission();
    ref.invalidate(_androidNotificationsEnabledProvider);
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permissão negada. Ative manualmente nas configurações do sistema.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final enabledAsync = ref.watch(_androidNotificationsEnabledProvider);
    final enabled = enabledAsync.maybeWhen(data: (v) => v, orElse: () => true);

    if (enabled) return const SizedBox.shrink();

    return _SettingsTile(
      icon: Icons.notifications_off_outlined,
      title: 'Permissão de notificação necessária',
      subtitle: 'Toque para permitir que o app envie lembretes',
      cs: cs,
      tt: tt,
      iconColor: cs.error,
      onTap: () => _requestPermission(context, ref),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.tiles,
    required this.cs,
    required this.tt,
  });

  final String title;
  final List<Widget> tiles;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(title: title, tt: tt, cs: cs),
        ...tiles,
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.tt,
    required this.cs,
  });

  final String title;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        title,
        style: tt.labelLarge?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.tt,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme tt;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  /// Destaca o tile quando seu detalhe está aberto na coluna direita (telas
  /// grandes com layout master-detail).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? cs.onSurface;
    return ListTile(
      selected: selected,
      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor != null
              ? iconColor!.withValues(alpha: 0.12)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: effectiveIconColor),
      ),
      title: Text(
        title,
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing:
          trailing ??
          (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _UpdateAvailableTile extends ConsumerWidget {
  const _UpdateAvailableTile({
    required this.update,
    required this.cs,
    required this.tt,
  });

  final AppUpdateInfo update;
  final ColorScheme cs;
  final TextTheme tt;

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = update.isCritical ? cs.errorContainer : cs.tertiaryContainer;
    final fg = update.isCritical ? cs.onErrorContainer : cs.onTertiaryContainer;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(Icons.system_update_rounded, color: fg),
        title: Text(
          'Versão ${update.version} disponível',
          style: tt.bodyMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          update.changelog ?? 'Nova versão disponível para download',
          style: tt.bodySmall?.copyWith(color: fg.withValues(alpha: 0.8)),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (update.downloadUrl case final url?)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: fg),
                onPressed: () {
                  ref.read(appUpdateProvider.notifier).clearUpdate();
                  _launch(url);
                },
                child: const Text('Baixar'),
              ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: fg),
              tooltip: 'Ignorar esta versão',
              onPressed: () =>
                  ref.read(appUpdateProvider.notifier).clearUpdate(),
            ),
          ],
        ),
      ),
    );
  }
}
