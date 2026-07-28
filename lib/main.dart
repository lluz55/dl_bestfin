import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/router/app_router.dart';
import 'package:bestfin/core/shell/responsive_navigation.dart';
import 'package:bestfin/core/theme/app_theme.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/theme/custom_seed_provider.dart';
import 'package:bestfin/core/theme/theme_provider.dart';
import 'package:bestfin/core/widgets/amount_display.dart';
import 'package:bestfin/core/widgets/animated_card.dart';
import 'package:bestfin/core/widgets/animated_chip.dart';
import 'package:bestfin/core/widgets/balance_card.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/gamification/presentation/widgets/badge_unlock_overlay.dart';
import 'package:bestfin/features/gamification/presentation/providers/gamification_providers.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:bestfin/features/onboarding/presentation/providers/tutorial_provider.dart';
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/core/providers/user_profile_provider.dart';
import 'package:bestfin/core/providers/sidebar_provider.dart';
import 'package:bestfin/core/providers/reminders_settings_provider.dart';
import 'package:bestfin/core/database/database_provider.dart';
import 'package:bestfin/core/notifications/notification_service.dart';
import 'package:bestfin/core/notifications/reminder_provider.dart';
import 'package:bestfin/core/notifications/reminder_scheduler.dart';
import 'package:bestfin/features/security/presentation/providers/security_provider.dart';
import 'package:bestfin/features/security/presentation/widgets/lock_overlay.dart';
import 'package:bestfin/core/utils/secure_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bestfin/features/sync/domain/models/app_update_info.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MCPToolkitBinding.instance
    ..initialize()
    ..initializeFlutterToolkit();

  // O workaround de carregamento do sqlite3/SQLCipher em Android antigo é
  // aplicado por DbEncryption.openExecutor no momento de abrir o banco.

  try {
    await initializeNotifications();
  } catch (e) {
    debugPrint('Failed to initialize notifications: $e');
  }

  initialOnboardingCompleted = await OnboardingActions.readCompleted();
  initialOnboardingStep = await OnboardingActions.readStep();
  initialOnboardingAccountDraft = await OnboardingActions.readAccountDraft();
  initialBiometricsEnabled = await OnboardingActions.readBiometrics();
  initialTutorialSeen = await TutorialActions.readSeen();
  initialIsLocked = initialBiometricsEnabled;
  final prefs = await SharedPreferences.getInstance();
  initialAlwaysHideValues = prefs.getBool(kAlwaysHideValuesKey) ?? false;
  if (initialAlwaysHideValues) {
    initialValuesHidden = true;
  } else {
    initialValuesHidden = prefs.getBool(kValuesHiddenKey) ?? false;
  }
  initialHideRecentsPreview = prefs.getBool(kHideRecentsPreviewKey) ?? true;
  await SecureScreen.setGlobalEnabled(initialHideRecentsPreview);

  initialDefaultAccountId = prefs.getString(kDefaultAccountIdKey);
  initialSidebarCollapsed = prefs.getBool(kSidebarCollapsedKey) ?? false;
  initialRemindersEnabled = prefs.getBool(kRemindersEnabledKey) ?? true;
  initialReminderLeadTimeDays =
      prefs.getInt(kReminderLeadTimeDaysKey) ?? ReminderLeadTime.oneDay.days;
  initialUserName = prefs.getString(kUserNameKey);
  initialUserPhotoPath = prefs.getString(kUserPhotoPathKey);
  runApp(const ProviderScope(child: BestFinApp()));
}


class BestFinApp extends ConsumerStatefulWidget {
  const BestFinApp({super.key});

  @override
  ConsumerState<BestFinApp> createState() => _BestFinAppState();
}

class _BestFinAppState extends ConsumerState<BestFinApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  Timer? _reminderDueCheckTimer;
  StreamSubscription<String>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleEscKey);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Gera transações pendentes para regras de recorrência e só então
      // reconcilia os lembretes (a geração pode criar novas ocorrências
      // futuras que precisam de notificação agendada).
      await ref.read(generateRecurringProvider.future);
      unawaited(ref.read(reminderReconcileProvider.future));
      unawaited(ref.read(gamificationServiceProvider).onAppStarted());
      unawaited(_startSync());
    });

    // Checagem periódica de lembretes vencidos — mecanismo principal no
    // Linux (sem agendamento nativo no SO) e rede de segurança no Android.
    _reminderDueCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(
        ReminderScheduler(ref.read(databaseProvider)).fireDueReminders(),
      );
    });

    _notificationTapSubscription = notificationTapController.stream.listen(
      _handleNotificationTap,
    );
    // getNotificationAppLaunchDetails não é implementado no Linux — só faz
    // sentido em plataformas onde uma notificação pode abrir o app.
    if (Platform.isAndroid || Platform.isIOS) {
      notificationsPlugin.getNotificationAppLaunchDetails().then((details) {
        final payload = details?.notificationResponse?.payload;
        if (details?.didNotificationLaunchApp == true && payload != null) {
          _handleNotificationTap(payload);
        }
      });
    }
  }

  Future<void> _handleNotificationTap(String transactionId) async {
    final tx = await ref
        .read(transactionRepositoryProvider)
        .getTransactionById(transactionId);
    if (tx == null || !mounted) return;
    unawaited(ref.read(appRouterProvider).push('/transaction/edit', extra: tx));
  }

  bool _handleEscKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;

    // Com o app bloqueado a árvore de navegação continua montada atrás da
    // tela de bloqueio — Esc não pode navegar às escondidas.
    if (ref.read(isLockedProvider) && ref.read(biometricsEnabledProvider)) {
      return true;
    }

    // Popar via GoRouter (e não direto no Navigator raiz) mantém a lista de
    // rotas do go_router em sincronia — um pop cru pode abortar no meio e
    // deixar o Navigator travado (assert `!_debugLocked` no dispose).
    final router = ref.read(appRouterProvider);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
    return true;
  }

  Future<void> _startSync() async {
    try {
      await ref.read(nostrSyncServiceProvider).loadIdentity();
    } catch (error) {
      debugPrint('[Sync] loadIdentity inesperado: $error');
    }
    // Always initialize the notifier regardless of loadIdentity outcome —
    // the periodic timer and debounce must start even without an identity
    // so they resume syncing once the user re-enters the mnemonic.
    ref.read(syncStateProvider);
    unawaited(ref.read(syncStateProvider.notifier).syncNow(background: true));
  }

  // Várias telas (ex.: DashboardScreen) têm seu próprio Scaffold aninhado
  // dentro do Scaffold do AppShell. O ScaffoldMessenger sempre exibe o
  // SnackBar no Scaffold atualmente mais interno, então um SnackBar comum
  // nunca fica de forma confiável acima da barra de navegação flutuante.
  // Por isso este aviso é um overlay próprio, renderizado no `builder` do
  // MaterialApp — acima de tudo, imune a qual Scaffold interno está ativo.
  Timer? _syncBannerTimer;
  _SyncBannerData? _syncBanner;

  // True after the user taps [×] on the update banner — hides it for this
  // session but leaves the info stored in SharedPreferences so it reappears
  // on next launch and remains accessible in Settings › Sobre.
  bool _updateBannerDismissedForSession = false;

  void _showSyncBanner({
    required IconData icon,
    required String message,
    bool isError = false,
  }) {
    _syncBannerTimer?.cancel();
    setState(() {
      _syncBanner = _SyncBannerData(
        icon: icon,
        message: message,
        isError: isError,
      );
    });
    _syncBannerTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _syncBanner = null);
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleEscKey);
    WidgetsBinding.instance.removeObserver(this);
    _syncBannerTimer?.cancel();
    _reminderDueCheckTimer?.cancel();
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      unawaited(SecureScreen.enable());
    }
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      // Relax the periodic safety-net poll while backgrounded to save
      // battery/data — the live subscription and resume-triggered sync
      // below cover freshness the rest of the time.
      ref.read(syncStateProvider.notifier).onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(SecureScreen.disable());
      final biometricsEnabled = ref.read(biometricsEnabledProvider);
      if (biometricsEnabled && _backgroundedAt != null) {
        final elapsed = DateTime.now().difference(_backgroundedAt!);
        if (elapsed.inSeconds > 60) {
          ref.read(isLockedProvider.notifier).lock();
        }
      }
      _backgroundedAt = null;
      ref.read(syncStateProvider.notifier).onAppResumed();
      // Background sync on every resume — picks up remote changes immediately.
      unawaited(ref.read(syncStateProvider.notifier).syncNow(background: true));
    }
  }


  @override
  Widget build(BuildContext context) {
    ref.listen(peerConnectionsProvider, (_, next) {
      next.whenData((info) {
        _showSyncBanner(
          icon: Icons.devices_rounded,
          message: '${info.deviceName ?? info.platform} se conectou',
        );
      });
    });

    ref.listen(syncBackgroundErrorsProvider, (_, next) {
      next.whenData((message) {
        _showSyncBanner(
          icon: Icons.sync_problem_rounded,
          message: message,
          isError: true,
        );
      });
    });

    // Reset session-dismiss when a *new* (different) version arrives so the
    // banner reappears automatically for the new version even in the same session.
    ref.listen(appUpdateProvider, (prev, next) {
      final prevVersion = prev?.value?.version;
      final nextVersion = next.value?.version;
      if (nextVersion != null && nextVersion != prevVersion) {
        if (mounted) setState(() => _updateBannerDismissedForSession = false);
      }
    });

    final themeState = ref.watch(themeProvider);
    final customSeed = ref.watch(customSeedProvider);
    final router = ref.watch(appRouterProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightScheme;
        final ColorScheme darkScheme;

        if (themeState.useDynamicColor &&
            lightDynamic != null &&
            darkDynamic != null) {
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        } else {
          lightScheme = ColorScheme.fromSeed(
            seedColor: customSeed.effectiveSeed,
            brightness: Brightness.light,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: customSeed.effectiveSeed,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp.router(
          title: 'BestFin',
          theme: AppTheme.build(lightScheme),
          darkTheme: AppTheme.build(darkScheme),
          themeMode: themeState.mode,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) => BadgeUnlockOverlay(
            child: LockOverlay(
              child: Stack(
                children: [
                  child ?? const SizedBox(),
                  if (!_updateBannerDismissedForSession)
                    if (ref.watch(appUpdateProvider).value case final update?)
                      Positioned(
                        left: 16,
                        right: 16,
                        top: MediaQuery.paddingOf(context).top + 8,
                        child: _UpdateBanner(
                          info: update,
                          onDismiss: () => setState(
                            () => _updateBannerDismissedForSession = true,
                          ),
                          onDownload: () {
                            ref
                                .read(appUpdateProvider.notifier)
                                .clearUpdate();
                          },
                        ),
                      ),
                  if (_syncBanner case final banner?)
                    Positioned(
                      left: 16,
                      right: 16,
                      // Só o layout compacto (mobile) tem a barra de
                      // navegação flutuante por baixo do conteúdo; nos
                      // layouts médio/expandido (tablet/desktop) a
                      // navegação é lateral, então basta o respiro padrão.
                      bottom:
                          (Breakpoints.isCompact(context)
                              ? kFloatingNavClearance
                              : 16) +
                          MediaQuery.paddingOf(context).bottom,
                      child: _SyncBanner(data: banner),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SyncBannerData {
  const _SyncBannerData({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.data});

  final _SyncBannerData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = data.isError ? cs.errorContainer : cs.surfaceContainerHigh;
    final fg = data.isError ? cs.onErrorContainer : cs.onSurface;
    return Material(
          color: bg,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.icon, size: 18, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(data.message, style: TextStyle(color: fg)),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideY(
          begin: 0.3,
          end: 0,
          duration: 250.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({
    required this.info,
    required this.onDismiss,
    required this.onDownload,
  });

  final AppUpdateInfo info;
  final VoidCallback onDismiss;
  final VoidCallback onDownload;

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = info.isCritical ? cs.errorContainer : cs.tertiaryContainer;
    final fg = info.isCritical ? cs.onErrorContainer : cs.onTertiaryContainer;
    return Material(
          color: bg,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Icon(Icons.system_update_rounded, size: 18, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nova versão ${info.version} disponível',
                        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                      ),
                      if (info.changelog case final log?)
                        Text(
                          log,
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (info.downloadUrl case final url?)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: fg),
                    onPressed: () {
                      onDownload();
                      _launch(url);
                    },
                    child: const Text('Baixar'),
                  ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: fg),
                  onPressed: onDismiss,
                  tooltip: 'Ver depois em Configurações › Sobre',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 200.ms)
        .slideY(begin: -0.3, end: 0, duration: 250.ms, curve: Curves.easeOutCubic);
  }
}

// Design system showcase — acessível via rota de debug
class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design System Showcase'),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _ComponentsShowcase(),
          _TypographyShowcase(),
          _EmptyStateShowcase(),
          _NewComponentsShowcase(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets),
            label: 'Components',
          ),
          NavigationDestination(
            icon: Icon(Icons.text_fields_outlined),
            selectedIcon: Icon(Icons.text_fields),
            label: 'Typography',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'States',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Novo',
          ),
        ],
      ),
    );
  }
}

class _ComponentsShowcase extends StatelessWidget {
  const _ComponentsShowcase();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AnimatedCard(
          delay: Duration(milliseconds: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Animated Card',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Slide lateral (X) + fade in. Toque para press scale.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AnimatedCard(
          delay: Duration(milliseconds: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount Displays',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              AmountDisplay(amountInCents: 152045),
              AmountDisplay(amountInCents: -35000),
              AmountDisplay(amountInCents: 0, showSign: false),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedCard(
          delay: const Duration(milliseconds: 300),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const AppLoadingIndicator(),
              ElevatedButton(onPressed: () {}, child: const Text('Botão')),
              ActionChip(label: const Text('Chip'), onPressed: () {}),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypographyShowcase extends StatelessWidget {
  const _TypographyShowcase();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Display Large', style: textTheme.displayLarge),
        Text('Display Medium', style: textTheme.displayMedium),
        Text('Display Small', style: textTheme.displaySmall),
        const Divider(),
        Text('Headline Large', style: textTheme.headlineLarge),
        Text('Headline Medium', style: textTheme.headlineMedium),
        Text('Headline Small', style: textTheme.headlineSmall),
        const Divider(),
        Text('Title Large', style: textTheme.titleLarge),
        Text('Title Medium', style: textTheme.titleMedium),
        Text('Title Small', style: textTheme.titleSmall),
        const Divider(),
        Text('Body Large', style: textTheme.bodyLarge),
        Text('Body Medium', style: textTheme.bodyMedium),
        Text('Body Small', style: textTheme.bodySmall),
        const Divider(),
        Text('Label Large', style: textTheme.labelLarge),
        Text('Label Medium', style: textTheme.labelMedium),
        Text('Label Small', style: textTheme.labelSmall),
      ],
    );
  }
}

class _EmptyStateShowcase extends StatelessWidget {
  const _EmptyStateShowcase();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'Nenhuma Transação',
      description:
          'Você ainda não registrou nenhuma despesa ou receita este mês.',
      icon: Icons.account_balance_wallet_outlined,
      actionLabel: 'Nova Transação',
      onAction: () {},
    );
  }
}

class _NewComponentsShowcase extends StatefulWidget {
  const _NewComponentsShowcase();

  @override
  State<_NewComponentsShowcase> createState() => _NewComponentsShowcaseState();
}

class _NewComponentsShowcaseState extends State<_NewComponentsShowcase> {
  int _chipSelected = 0;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Balance Card',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const BalanceCard(
          balanceInCents: 476250,
          accountName: 'BestFin',
          subtitle: 'SALDO CONSOLIDADO',
        ),
        const SizedBox(height: 24),
        Text(
          'Animated Chips (toque para selecionar)',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (int i = 0; i < 4; i++)
              AnimatedChip(
                label: ['Este mês', 'Semana', '3 meses', 'Ano'][i],
                icon: [
                  Icons.calendar_month_outlined,
                  Icons.date_range_outlined,
                  Icons.bar_chart_outlined,
                  Icons.trending_up_outlined,
                ][i],
                selected: _chipSelected == i,
                onTap: () => setState(() => _chipSelected = i),
                delay: Duration(milliseconds: i * 60),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Paleta de Cores',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _ColorRow(cs: cs),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final pairs = [
      ('Primary', cs.primary, cs.onPrimary),
      ('Secondary', cs.secondary, cs.onSecondary),
      ('Tertiary', cs.tertiary, cs.onTertiary),
      ('Income', colors.income, Colors.white),
      ('Expense', colors.expense, Colors.white),
      ('Chart', colors.chartPrimary, Colors.white),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, bg, fg) in pairs)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(color: fg),
            ),
          ),
      ],
    );
  }
}
