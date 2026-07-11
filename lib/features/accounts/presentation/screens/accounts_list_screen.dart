import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/providers/privacy_provider.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/balance_card.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/core/widgets/amount_display.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/accounts/presentation/widgets/account_card.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';

class AccountsListScreen extends ConsumerWidget {
  const AccountsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    ref.watch(valuesHiddenProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final totalBalanceVal = ref.watch(totalBalanceProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppPageAppBar(
        title: 'Minhas Contas',
        showVisibilityToggle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Nova conta',
            onPressed: () => context.push('/accounts/new'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
        },
        child: accountsAsync.when(
          data: (accountsList) {
            final activeAccounts = accountsList
                .where((a) => a.isActive)
                .toList();
            final inactiveAccounts = accountsList
                .where((a) => !a.isActive)
                .toList();

            if (accountsList.isEmpty) {
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

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: BalanceCard(
                    balanceInCents: totalBalanceVal,
                    accountName: 'Saldo Geral',
                    subtitle: 'SALDO CONSOLIDADO',
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (activeAccounts.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Text(
                        'Nenhuma conta ativa.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final account = activeAccounts[index];
                      return AccountCard(
                        account: account,
                        delay: Duration(milliseconds: index * 50),
                        onTap: () => context.push('/accounts/${account.id}'),
                      );
                    }, childCount: activeAccounts.length),
                  ),
                if (inactiveAccounts.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ExpansionTile(
                        title: Text(
                          'Contas Inativas (${inactiveAccounts.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        leading: Icon(
                          Icons.archive_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        shape: const Border(),
                        childrenPadding: EdgeInsets.zero,
                        children: inactiveAccounts.map((account) {
                          return ListTile(
                            onTap: () =>
                                context.push('/accounts/${account.id}'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AccountCard.hexToColor(
                                  account.color,
                                ).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                IconMapper.fromCodePoint(
                                  int.parse(account.icon),
                                ),
                                color: AccountCard.hexToColor(
                                  account.color,
                                ).withValues(alpha: 0.5),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              account.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            subtitle: Text(
                              account.type.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: AmountDisplay(
                              amountInCents: account.balance,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              showSign: false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
          loading: () => const Center(child: AppLoadingIndicator()),
          error: (err, stack) =>
              Center(child: Text('Erro ao carregar contas: $err')),
        ),
      ),
    );
  }
}
