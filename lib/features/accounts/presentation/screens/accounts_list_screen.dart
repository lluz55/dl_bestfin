import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/accounts/presentation/widgets/account_card.dart';
import 'package:bestfin/features/accounts/presentation/widgets/account_visual_widget.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';

class AccountsListScreen extends ConsumerStatefulWidget {
  const AccountsListScreen({super.key});

  @override
  ConsumerState<AccountsListScreen> createState() => _AccountsListScreenState();
}

class _AccountsListScreenState extends ConsumerState<AccountsListScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    ref.watch(valuesHiddenProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final totalBalance = ref.watch(totalBalanceProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Minhas Contas',
        showVisibilityToggle: true,
        infoDescription: 'Gerencie todas as suas contas financeiras: conta corrente, poupança, carteira e outras. Acompanhe o saldo total e individual de cada conta.',
        infoFeatures: [
          'Saldo total consolidado de todas as contas',
          'Adicione contas de diferentes tipos',
          'Visualize o extrato de cada conta',
          'Conciliação bancária',
        ],
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nova conta',
            onPressed: () => context.push('/accounts/new'),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          final active = accounts.where((a) => a.isActive).toList();
          final inactive = accounts.where((a) => !a.isActive).toList();

          if (accounts.isEmpty) {
            return Center(
              child: EmptyState(
                title: 'Nenhuma Conta',
                description:
                    'Comece adicionando uma conta corrente, poupança ou carteira.',
                icon: Icons.account_balance_wallet_outlined,
                actionLabel: 'Criar Conta',
                onAction: () => context.push('/accounts/new'),
              ),
            );
          }

          return _buildContent(active, inactive, totalBalance, cs, tt);
        },
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (err, _) =>
            Center(child: Text('Erro ao carregar contas: $err')),
      ),
    );
  }

  Widget _buildContent(
    List<Account> active,
    List<Account> inactive,
    int totalBalance,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final isWide = Breakpoints.isWide(context);
    final selected = active.isEmpty
        ? null
        : active[_selectedIndex.clamp(0, active.length - 1)];

    if (isWide) {
      return _buildExpandedLayout(active, inactive, totalBalance, cs, tt, selected);
    }

    return _buildCompactLayout(active, inactive, totalBalance, cs, tt, selected);
  }

  Widget _buildCompactLayout(
    List<Account> active,
    List<Account> inactive,
    int totalBalance,
    ColorScheme cs,
    TextTheme tt,
    Account? selected,
  ) {
    return Column(
      children: [
        const SizedBox(height: 20),

        SizedBox(
          height: 210,
          child: active.isEmpty
              ? Center(
                  child: Text(
                    'Nenhuma conta ativa.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: active.length,
                  itemBuilder: (context, index) {
                    final account = active[index];
                    final isSelected =
                        index == _selectedIndex.clamp(0, active.length - 1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (isSelected) {
                            context.push('/accounts/${account.id}');
                          } else {
                            setState(() => _selectedIndex = index);
                          }
                        },
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isSelected ? 1.0 : 0.55,
                          child: AccountVisualWidget(account: account),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                if (selected != null)
                  Container(
                    key: ValueKey(selected.id),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: _AccountDetailPanel(
                      account: selected,
                      totalBalance: totalBalance,
                      cs: cs,
                      tt: tt,
                    ),
                  ).animate().fadeIn(duration: 250.ms),

                if (inactive.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildInactiveAccountsSection(inactive, tt, cs),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedLayout(
    List<Account> active,
    List<Account> inactive,
    int totalBalance,
    ColorScheme cs,
    TextTheme tt,
    Account? selected,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Contas',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: active.length,
                  itemBuilder: (context, index) {
                    final account = active[index];
                    final isSelected =
                        selected != null && account.id == selected.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AccountListTile(
                        account: account,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            final newIndex =
                                active.indexWhere((a) => a.id == account.id);
                            if (newIndex >= 0) _selectedIndex = newIndex;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              if (inactive.isNotEmpty)
                _buildInactiveAccountsSection(inactive, tt, cs),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 0.5),
        Expanded(
          child: selected == null
              ? const Center(
                  child: Text(
                    'Selecione uma conta',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    children: [
                      _AccountDetailPanel(
                        account: selected,
                        totalBalance: totalBalance,
                        cs: cs,
                        tt: tt,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _AccountDetailPanel extends StatelessWidget {
  const _AccountDetailPanel({
    required this.account,
    required this.totalBalance,
    required this.cs,
    required this.tt,
  });

  final Account account;
  final int totalBalance;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final baseColor = AccountCard.hexToColor(account.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              account.type.label,
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'Saldo',
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  IconMapper.fromCodePoint(int.parse(account.icon)),
                  color: baseColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  account.name,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Text(
              'R\$ ${(account.balance / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (totalBalance != 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Participação no saldo geral',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '${((account.balance / totalBalance) * 100).abs().toStringAsFixed(1)}%',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:
                  totalBalance != 0 ? (account.balance / totalBalance).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(baseColor),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => {},
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('Ver detalhes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => {},
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccountListTile extends StatelessWidget {
  const _AccountListTile({
    required this.account,
    required this.isSelected,
    required this.onTap,
    this.isInactive = false,
  });

  final Account account;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isInactive;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;
    final colors = context.customColors;

    return ListTile(
      selected: isSelected,
      selectedTileColor:
          cs.primaryContainer.withValues(alpha: 0.4),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AccountCard.hexToColor(account.color)
              .withValues(alpha: isInactive ? 0.08 : 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          IconMapper.fromCodePoint(int.parse(account.icon)),
          color: AccountCard.hexToColor(account.color)
              .withValues(alpha: isInactive ? 0.5 : 0.7),
          size: 22,
        ),
      ),
      title: Text(
        account.name,
        style: tt.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: isInactive ? cs.onSurfaceVariant : cs.onSurface,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.type.label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          Text(
            'R\$ ${(account.balance / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isInactive
                  ? cs.onSurfaceVariant
                  : (account.balance >= 0 ? colors.income : colors.expense),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildInactiveAccountsSection(
  List<Account> inactive,
  TextTheme tt,
  ColorScheme cs,
) {
  return ExpansionTile(
    title: Text(
      'Contas Inativas (${inactive.length})',
      style: tt.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
      ),
    ),
    leading: Icon(
      Icons.archive_outlined,
      color: cs.onSurfaceVariant,
    ),
    shape: const Border(),
    childrenPadding: EdgeInsets.zero,
    children: inactive.map((account) {
      return ListTile(
        onTap: () => {},
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AccountCard.hexToColor(account.color).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            IconMapper.fromCodePoint(int.parse(account.icon)),
            color: AccountCard.hexToColor(account.color).withValues(alpha: 0.5),
            size: 20,
          ),
        ),
        title: Text(
          account.name,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          account.type.label,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
trailing: Text(
            'R\$ ${(account.balance / 100.0).toStringAsFixed(2).replaceAll('.', ',')}',
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
      );
    }).toList(),
  );
}