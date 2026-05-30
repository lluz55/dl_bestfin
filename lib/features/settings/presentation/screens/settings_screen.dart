import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:drift/drift.dart' show Value;
import 'package:bestfin/core/constants/default_categories.dart';
import 'package:bestfin/core/database/app_database.dart' hide Account;
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/theme/theme_provider.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:bestfin/features/security/presentation/providers/security_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/dashboard/presentation/providers/home_widgets_provider.dart';
import 'package:bestfin/features/dashboard/presentation/providers/shortcuts_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _auth = LocalAuthentication();
  bool _biometricsAvailable = false;

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
            'Esta ação é irreversível. Todas as contas, transações, metas e demais dados serão apagados permanentemente.\n\nAs categorias padrão serão restauradas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              child: const Text('Apagar tudo'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final db = ref.read(databaseProvider);
    await db.transaction(() async {
      await db.delete(db.attachments).go();
      await db.delete(db.entries).go();
      await db.delete(db.transactions).go();
      await db.delete(db.invoices).go();
      await db.delete(db.creditCards).go();
      await db.delete(db.investments).go();
      await db.delete(db.financingInstallments).go();
      await db.delete(db.financings).go();
      await db.delete(db.recurringRules).go();
      await db.delete(db.installmentPlans).go();
      await db.delete(db.goals).go();
      await db.delete(db.notificationPatterns).go();
      await db.delete(db.holidays).go();
      await db.delete(db.entities).go();
      await db.delete(db.accounts).go();
      await db.delete(db.categories).go();
      await db.delete(db.appSettings).go();
      await db.delete(db.badges).go();
      await db.delete(db.streaks).go();
      await db.delete(db.householdMembers).go();
      await db.delete(db.households).go();

      // Re-seed default categories
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
              parentId: c.parentId != null
                  ? Value(c.parentId)
                  : const Value.absent(),
            );
          }).toList(),
        );
      });
    });

    ref.invalidate(databaseProvider);

    // Clear PIN from secure storage
    await SecurityActions.clearPin();

    // Clear all SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Reset global settings/onboarding variables
    initialOnboardingCompleted = false;
    initialBiometricsEnabled = false;
    initialValuesHidden = false;
    initialAlwaysHideValues = false;
    initialIsLocked = false;

    // Reset provider states
    ref.read(onboardingCompletedProvider.notifier).set(false);
    ref.read(biometricsEnabledProvider.notifier).set(false);
    ref.read(isLockedProvider.notifier).unlock();

    // Invalidate providers to force them to reload from the cleared state
    ref.invalidate(themeProvider);
    ref.invalidate(valuesHiddenProvider);
    ref.invalidate(alwaysHideValuesProvider);
    ref.invalidate(homeWidgetsProvider);
    ref.invalidate(shortcutsProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Todos os dados foram apagados. O app foi reiniciado.',
        ),
        backgroundColor: context.colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final themeState = ref.watch(themeProvider);
    final biometricsEnabled = ref.watch(biometricsEnabledProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Configurações'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _SectionHeader(title: 'Aparência', tt: tt, cs: cs),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'Tema',
            subtitle: _themeLabel(themeState.mode),
            cs: cs,
            tt: tt,
            onTap: () => _showThemePicker(context, ref, themeState),
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Cor dinâmica',
            subtitle: 'Usar cor do sistema',
            cs: cs,
            tt: tt,
            trailing: Switch(
              value: themeState.useDynamicColor,
              onChanged: (v) =>
                  ref.read(themeProvider.notifier).setDynamicColor(v),
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader(title: 'Privacidade', tt: tt, cs: cs),
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
          const SizedBox(height: 8),
          if (_biometricsAvailable) ...[
            _SectionHeader(title: 'Segurança', tt: tt, cs: cs),
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
            const SizedBox(height: 8),
          ],
          _SectionHeader(title: 'Transações', tt: tt, cs: cs),
          _DefaultAccountTile(cs: cs, tt: tt),
          const SizedBox(height: 8),
          _SectionHeader(title: 'Dados', tt: tt, cs: cs),
          _SettingsTile(
            icon: Icons.upload_rounded,
            title: 'Exportar dados',
            subtitle: 'Salvar backup em JSON, CSV ou PDF',
            cs: cs,
            tt: tt,
            onTap: () => context.push('/backup'),
          ),
          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'Importar dados',
            subtitle: 'Restaurar CSV, JSON ou banco SQLite',
            cs: cs,
            tt: tt,
            onTap: () => context.push('/backup'),
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
          const SizedBox(height: 8),
          _SectionHeader(title: 'Sobre', tt: tt, cs: cs),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Versão',
            subtitle: '1.0.0',
            cs: cs,
            tt: tt,
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de Privacidade',
            subtitle: 'Seus dados ficam apenas no dispositivo',
            cs: cs,
            tt: tt,
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Sistema';
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Escuro';
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, ThemeState state) {
    showModalBottomSheet(
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
                'Tema',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              for (final mode in ThemeMode.values)
                ListTile(
                  title: Text(_themeLabel(mode)),
                  leading: Icon(_themeIcon(mode)),
                  selected: state.mode == mode,
                  selectedColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    ref.read(themeProvider.notifier).setMode(mode);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.settings_brightness_rounded;
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
    }
  }
}

class _DefaultAccountTile extends ConsumerWidget {
  const _DefaultAccountTile({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeAccountsProvider);
    final defaultId = ref.watch(defaultAccountIdProvider);
    final defaultAccount = accounts.where((a) => a.id == defaultId).firstOrNull;

    return ListTile(
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
      onTap: () => _showAccountPicker(context, ref, accounts, defaultId),
    );
  }

  void _showAccountPicker(
    BuildContext context,
    WidgetRef ref,
    List<Account> accounts,
    String? currentDefaultId,
  ) {
    showModalBottomSheet(
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme tt;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? cs.onSurface;
    return ListTile(
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
