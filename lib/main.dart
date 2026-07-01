import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/router/app_router.dart';
import 'package:bestfin/core/theme/app_theme.dart';
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
import 'package:bestfin/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/providers/default_account_provider.dart';
import 'package:bestfin/features/security/presentation/providers/security_provider.dart';
import 'package:bestfin/features/security/presentation/widgets/lock_overlay.dart';
import 'package:bestfin/features/llm/domain/models/llm_state.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_provider.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_insights_provider.dart';
import 'package:bestfin/features/llm/presentation/providers/llm_narrative_provider.dart';
import 'package:bestfin/features/llm/domain/services/financial_context_builder.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MCPToolkitBinding.instance
    ..initialize()
    ..initializeFlutterToolkit();

  if (Platform.isAndroid) {
    try {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    } catch (e) {
      debugPrint('Failed to apply sqlite3 workaround: $e');
    }
  }

  initialOnboardingCompleted = await OnboardingActions.readCompleted();
  initialBiometricsEnabled = await OnboardingActions.readBiometrics();
  initialIsLocked = initialBiometricsEnabled;
  final prefs = await SharedPreferences.getInstance();
  initialAlwaysHideValues = prefs.getBool(kAlwaysHideValuesKey) ?? false;
  if (initialAlwaysHideValues) {
    initialValuesHidden = true;
  } else {
    initialValuesHidden = prefs.getBool(kValuesHiddenKey) ?? false;
  }
  initialDefaultAccountId = prefs.getString(kDefaultAccountIdKey);
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleEscKey);
    // Gera transações pendentes para regras de recorrência ao abrir o app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(generateRecurringProvider);
      ref.read(gamificationServiceProvider).onAppStarted();
      unawaited(_startSync());
    });
  }

  bool _handleEscKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;

    final router = ref.read(appRouterProvider);
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return false;

    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      router.go('/home');
    }
    return true;
  }

  Future<void> _startSync() async {
    try {
      await ref.read(backendSetupProvider.future);
      ref.read(syncServiceProvider).startAutoSync();
    } catch (error) {
      debugPrint('Failed to start auto-sync: $error');
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleEscKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final biometricsEnabled = ref.read(biometricsEnabledProvider);
      if (biometricsEnabled && _backgroundedAt != null) {
        final elapsed = DateTime.now().difference(_backgroundedAt!);
        if (elapsed.inSeconds > 60) {
          ref.read(isLockedProvider.notifier).lock();
        }
      }
      _backgroundedAt = null;
      // Trigger insight + narrative refresh if LLM is ready and cache is stale
      final llmStatus = ref.read(llmStateProvider).status;
      if (llmStatus == LlmStatus.ready) {
        FinancialContextBuilder.invalidate();
        ref.read(llmInsightsCacheInvalidatorProvider).call();
        ref.read(llmNarrativeCacheInvalidatorProvider).call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        } else if (customSeed.useCustomSeed && customSeed.seedColor != null) {
          lightScheme = ColorScheme.fromSeed(
            seedColor: customSeed.seedColor!,
            brightness: Brightness.light,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: customSeed.seedColor!,
            brightness: Brightness.dark,
          );
        } else {
          lightScheme = themeState.preset.light();
          darkScheme = themeState.preset.dark();
        }

        return MaterialApp.router(
          title: 'BestFin',
          theme: AppTheme.build(lightScheme),
          darkTheme: AppTheme.build(darkScheme),
          themeMode: themeState.mode,
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          builder: (context, child) => BadgeUnlockOverlay(
            child: LockOverlay(child: child ?? const SizedBox()),
          ),
        );
      },
    );
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
