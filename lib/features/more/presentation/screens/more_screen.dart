import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bestfin/core/constants/app_info.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/animated_detail_panel.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/section_header.dart';
import 'package:bestfin/features/accounts/presentation/screens/accounts_list_screen.dart';
import 'package:bestfin/features/backup/presentation/screens/backup_screen.dart';
import 'package:bestfin/features/budgets/presentation/screens/budgets_list_screen.dart';
import 'package:bestfin/features/cashflow/presentation/screens/cashflow_screen.dart';
import 'package:bestfin/features/categories/presentation/screens/categories_screen.dart';
import 'package:bestfin/features/credit_cards/presentation/screens/credit_cards_list_screen.dart';
import 'package:bestfin/features/financing/presentation/screens/financing_list_screen.dart';
import 'package:bestfin/features/gamification/presentation/screens/gamification_hub_screen.dart';
import 'package:bestfin/features/goals/presentation/screens/goals_list_screen.dart';
import 'package:bestfin/features/investments/presentation/screens/portfolio_screen.dart';
import 'package:bestfin/features/onboarding/presentation/providers/tutorial_provider.dart';
import 'package:bestfin/features/transactions/presentation/screens/review_queue_screen.dart';
import 'package:bestfin/features/pdf_import/presentation/screens/pdf_import_screen.dart';
import 'package:bestfin/features/recurring/presentation/screens/recurring_list_screen.dart';
import 'package:bestfin/features/settings/presentation/screens/settings_screen.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

// ─── Modelo dos itens do menu ────────────────────────────────────────────────

class _MoreItem {
  const _MoreItem({
    required this.icon,
    required this.label,
    this.route,
    this.buildScreen,
    this.colorFn,
    this.onTap,
    this.subtitle,
    this.trailingBuilder,
  });

  final IconData icon;
  final String label;

  /// Rota usada no mobile (push em tela cheia).
  final String? route;

  /// Tela embutida no painel de detalhe (telas médias/grandes).
  final Widget Function()? buildScreen;

  /// Cor de destaque do ícone (atalhos em card); nulo usa a cor neutra.
  final Color Function(ColorScheme)? colorFn;

  /// Ação direta (ex: reiniciar tutorial). Alternativa a [route].
  final VoidCallback? onTap;

  /// Subtítulo informativo (ex: versão do app).
  final String? subtitle;

  /// Widget personalizado no final do tile (ex: badge de atualização).
  final Widget Function(ColorScheme)? trailingBuilder;
}

class _MoreSection {
  const _MoreSection({
    required this.title,
    required this.items,
    this.isGrid = false,
    this.footerBuilder,
  });

  final String title;
  final List<_MoreItem> items;

  /// No mobile, seções em grid viram cards de atalho; as demais, lista.
  final bool isGrid;

  /// Widget opcional renderizado após os itens da seção (ex: atualização).
  final Widget Function(BuildContext)? footerBuilder;
}

// ─── Tela ────────────────────────────────────────────────────────────────────

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static List<_MoreSection> _sections(BuildContext context, WidgetRef ref) {
    return [
      _MoreSection(
        title: 'Finanças',
        isGrid: true,
        items: [
          _MoreItem(
            icon: Icons.account_balance_rounded,
            label: 'Contas',
            route: '/accounts',
            colorFn: (cs) => cs.primary,
            buildScreen: () => const AccountsListScreen(),
          ),
          _MoreItem(
            icon: Icons.category_rounded,
            label: 'Categorias',
            route: '/categories',
            colorFn: (cs) => cs.secondary,
            buildScreen: () => const CategoriesScreen(),
          ),
          _MoreItem(
            icon: Icons.credit_card_rounded,
            label: 'Cartões',
            route: '/credit-cards',
            colorFn: (cs) => cs.tertiary,
            buildScreen: () => const CreditCardsListScreen(),
          ),
          _MoreItem(
            icon: Icons.repeat_rounded,
            label: 'Recorrentes',
            route: '/recurring',
            colorFn: (cs) => cs.error,
            buildScreen: () => const RecurringListScreen(),
          ),
        ],
      ),
      _MoreSection(
        title: 'Planejamento',
        isGrid: true,
        items: [
          _MoreItem(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Orçamento',
            route: '/budgets',
            colorFn: (cs) => cs.tertiary,
            buildScreen: () => const BudgetsListScreen(),
          ),
          _MoreItem(
            icon: Icons.waterfall_chart_rounded,
            label: 'Projeção',
            route: '/cashflow',
            colorFn: (cs) => cs.primary,
            buildScreen: () => const CashFlowScreen(),
          ),
        ],
      ),
      _MoreSection(
        title: 'Objetivos',
        isGrid: true,
        items: [
          _MoreItem(
            icon: Icons.flag_rounded,
            label: 'Metas',
            route: '/goals',
            colorFn: (cs) => cs.tertiary,
            buildScreen: () => const GoalsListScreen(),
          ),
          _MoreItem(
            icon: Icons.trending_up_rounded,
            label: 'Investimentos',
            route: '/investments',
            colorFn: (cs) => cs.secondary,
            buildScreen: () => const PortfolioScreen(),
          ),
          _MoreItem(
            icon: Icons.home_work_rounded,
            label: 'Financiamentos',
            route: '/financing',
            colorFn: (cs) => cs.primary,
            buildScreen: () => const FinancingListScreen(),
          ),
          _MoreItem(
            icon: Icons.emoji_events_rounded,
            label: 'Conquistas',
            route: '/gamification',
            colorFn: (cs) => cs.primary,
            buildScreen: () => const GamificationHubScreen(),
          ),
        ],
      ),
      _MoreSection(
        title: 'Automação',
        items: [
          _MoreItem(
            icon: Icons.pending_actions_rounded,
            label: 'Sugestões',
            route: '/transactions/pending',
            buildScreen: () => const ReviewQueueScreen(),
          ),
          _MoreItem(
            icon: Icons.picture_as_pdf_rounded,
            label: 'Importar PDF',
            route: '/pdf-import',
            buildScreen: () => const PdfImportScreen(),
          ),
        ],
      ),
      _MoreSection(
        title: 'App',
        items: [
          _MoreItem(
            icon: Icons.file_download_outlined,
            label: 'Exportar dados',
            route: '/backup',
            buildScreen: () => const BackupScreen(),
          ),
          _MoreItem(
            icon: Icons.settings_outlined,
            label: 'Configurações',
            route: '/settings',
            buildScreen: () => const SettingsScreen(),
          ),
        ],
      ),
      _MoreSection(
        title: 'Sobre',
        items: [
          _MoreItem(
            icon: Icons.school_outlined,
            label: 'Rever tutorial',
            subtitle: 'Exibir novamente o guia de primeiros passos',
            onTap: () {
              unawaited(() async {
                await TutorialActions.reset(ref);
                if (context.mounted) context.go('/home');
              }());
            },
          ),
          _MoreItem(
            icon: Icons.info_outline_rounded,
            label: 'Versão',
            subtitle: kAppVersion,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  expand: false,
                  builder: (ctx, scrollController) => _VersionDetailScreen(
                    scrollController: scrollController,
                  ),
                ),
              );
            },
            buildScreen: () => const _VersionDetailScreen(),
          ),
          _MoreItem(
            icon: Icons.privacy_tip_outlined,
            label: 'Política de Privacidade',
            subtitle: 'Seus dados ficam apenas no dispositivo',
            buildScreen: () => _InfoDetailScreen(
              icon: Icons.privacy_tip_outlined,
              title: 'Política de Privacidade',
              value: 'Seus dados ficam apenas no dispositivo',
              description: 'O BestFin não coleta, armazena ou compartilha seus dados financeiros com terceiros. Toda a informação permanece armazenada localmente no seu dispositivo, e a sincronização entre dispositivos é criptografada de ponta a ponta.',
            ),
          ),
          _MoreItem(
            icon: Icons.description_outlined,
            label: 'Licenças',
            subtitle: 'Bibliotecas de código aberto',
            onTap: () => showLicensePage(context: context),
            buildScreen: () => const LicensePage(),
          ),
        ],
        footerBuilder: (ctx) {
          final cs = ctx.colorScheme;
          final tt = ctx.textTheme;
          return Consumer(
            builder: (ctx, ref, _) {
              final update = ref.watch(appUpdateProvider).value;
              if (update == null) return const SizedBox.shrink();
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
                            launchUrl(Uri.parse(url));
                          },
                          child: const Text('Baixar'),
                        ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: fg),
                        tooltip: 'Ignorar esta versão',
                        onPressed: () => ref.read(appUpdateProvider.notifier).clearUpdate(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    ];
  }

  static List<_MoreSection> _listsFirst(BuildContext context, WidgetRef ref) {
    final all = _sections(context, ref);
    final others = all.where((s) => s.title != 'Sobre').toList();
    final ordered = [
      ...others.where((s) => !s.isGrid),
      ...others.where((s) => s.isGrid),
    ];
    return [...ordered, ...all.where((s) => s.title == 'Sobre')];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = context.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(
        title: 'Mais',
        infoDescription: 'Acesse todas as funcionalidades do BestFin em um só lugar: contas, cartões, investimentos, metas, orçamentos, relatórios e configurações.',
        infoFeatures: [
          'Controle completo de contas, cartões e investimentos',
          'Metas financeiras e orçamento envelope',
          'Importação de faturas e extratos PDF',
          'Sincronização E2E entre dispositivos',
        ],
      ),
      body: Breakpoints.isCompact(context)
          ? _MenuColumnBody(sections: _sections(context, ref))
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 640) {
                  return _MenuColumnBody(
                    sections: _listsFirst(context, ref),
                    maxWidth: 600,
                  );
                }
                return _MoreMasterDetail(sections: _listsFirst(context, ref));
              },
            ),
    );
  }
}

// ─── Menu em coluna única (mobile / fallback estreito) ───────────────────────

class _MenuColumnBody extends StatelessWidget {
  const _MenuColumnBody({required this.sections, this.maxWidth});

  final List<_MoreSection> sections;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          SectionHeader(title: sections[i].title, isFirst: i == 0),
          if (sections[i].isGrid)
            _MenuGrid(
              items: [
                for (final item in sections[i].items)
                  _MenuItem(
                    icon: item.icon,
                    label: item.label,
                    color: item.colorFn?.call(cs) ?? cs.primary,
                    onTap: item.onTap ?? (item.route != null ? () => context.push(item.route!) : () {}),
                  ),
              ],
            )
          else
            _MenuList(
              items: [
                for (final item in sections[i].items)
                  _MenuListItem(
                    icon: item.icon,
                    label: item.label,
                    subtitle: item.subtitle,
                    onTap: item.onTap ?? (item.route != null ? () => context.push(item.route!) : null),
                    trailing: item.trailingBuilder?.call(cs),
                    cs: cs,
                    tt: tt,
                  ),
              ],
              footerBuilder: sections[i].footerBuilder,
            ),
        ],
      ],
    );

    if (maxWidth == null) return list;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: list,
      ),
    );
  }
}

// ─── Master-detail (telas médias/grandes) ────────────────────────────────────

class _MoreMasterDetail extends StatefulWidget {
  const _MoreMasterDetail({required this.sections});

  final List<_MoreSection> sections;

  @override
  State<_MoreMasterDetail> createState() => _MoreMasterDetailState();
}

class _MoreMasterDetailState extends State<_MoreMasterDetail> {
  _MoreItem? _selected;

  @override
  void initState() {
    super.initState();
    _selected = _firstWithScreen();
  }

  _MoreItem? _firstWithScreen() {
    for (final section in widget.sections) {
      for (final item in section.items) {
        if (item.buildScreen != null) return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (var s = 0; s < widget.sections.length; s++) ...[
                if (widget.sections[s].items.isNotEmpty) ...[
                  SectionHeader(
                    title: widget.sections[s].title,
                    isFirst: s == 0,
                  ),
                  for (final item in widget.sections[s].items)
                    _MasterNavTile(
                      item: item,
                      selected: item.buildScreen != null && identical(item, _selected),
                      onTap: () {
                        if (item.onTap != null) {
                          item.onTap!();
                        } else if (item.buildScreen != null) {
                          setState(() => _selected = item);
                        }
                      },
                    ),
                ],
              ],
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 0.5),
        Expanded(
          child: AnimatedDetailPanel(
            keyValue: _selected?.route,
            child: _selected?.buildScreen?.call() ?? const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _MasterNavTile extends StatelessWidget {
  const _MasterNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _MoreItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final color = item.colorFn?.call(cs) ?? cs.onSurfaceVariant;

    return Material(
      color: selected ? cs.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? cs.onSecondaryContainer : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets do menu mobile ──────────────────────────────────────────────────

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.isCompact(context)) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
            padding: EdgeInsets.zero,
            children: items,
          ),
        ),
      );
    }

    // Telas maiores: os atalhos fluem com a largura disponível da coluna.
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 110,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      children: items,
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList({required this.items, this.footerBuilder});

  final List<_MenuListItem> items;
  final Widget Function(BuildContext)? footerBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ...items,
          if (footerBuilder != null) footerBuilder!(context),
        ],
      ),
    );
  }
}

class _MenuListItem extends StatelessWidget {
  const _MenuListItem({
    required this.icon,
    required this.label,
    required this.cs,
    required this.tt,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: cs.onSurface),
      title: Text(
        label,
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
          : null,
      trailing: trailing ?? (onTap != null
          ? Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20)
          : null),
      onTap: onTap,
    );
  }
}

/// Painel de detalhe para itens informativos (Versão, Política de Privacidade)
/// no layout master-detail (telas médias/grandes).
class _InfoDetailScreen extends StatelessWidget {
  const _InfoDetailScreen({
    required this.icon,
    required this.title,
    required this.value,
    this.description,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: cs.onPrimaryContainer, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 16),
            Text(
              description!,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Painel de detalhe que carrega e exibe o CHANGELOG.md.
class _VersionDetailScreen extends StatefulWidget {
  const _VersionDetailScreen({this.scrollController});

  final ScrollController? scrollController;

  @override
  State<_VersionDetailScreen> createState() => _VersionDetailScreenState();
}

class _VersionDetailScreenState extends State<_VersionDetailScreen> {
  String? _changelog;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChangelog();
  }

  Future<void> _loadChangelog() async {
    try {
      final text = await DefaultAssetBundle.of(context).loadString('CHANGELOG.md');
      if (mounted) setState(() { _changelog = text; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final entries = _parseChangelog(_changelog ?? '');

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.info_outline_rounded, color: cs.onPrimaryContainer, size: 24),
        ),
        const SizedBox(height: 16),
        Text(
          'Versão $kAppVersion',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Histórico de versões',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        for (final entry in entries) ...[
          _ChangelogEntryTile(entry: entry, cs: cs, tt: tt),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<_ChangelogEntry> _parseChangelog(String raw) {
    final entries = <_ChangelogEntry>[];
    final lines = raw.split('\n');
    _ChangelogEntry? current;

    for (final line in lines) {
      final versionMatch = RegExp(r'^##\s+v?(\d+\.\d+\.\d+)').firstMatch(line);
      if (versionMatch != null) {
        current = _ChangelogEntry(version: versionMatch.group(1)!, changes: []);
        entries.add(current);
        continue;
      }
      if (line.startsWith('## Unreleased')) {
        current = _ChangelogEntry(version: 'Próximo', changes: []);
        entries.add(current);
        continue;
      }
      if (current != null) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
          current.changes.add(trimmed.substring(2).trim());
        }
      }
    }
    return entries;
  }
}

class _ChangelogEntry {
  const _ChangelogEntry({required this.version, required this.changes});
  final String version;
  final List<String> changes;
}

class _ChangelogEntryTile extends StatelessWidget {
  const _ChangelogEntryTile({
    required this.entry,
    required this.cs,
    required this.tt,
  });

  final _ChangelogEntry entry;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.version,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          if (entry.changes.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final change in entry.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    Expanded(
                      child: Text(
                        change,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
