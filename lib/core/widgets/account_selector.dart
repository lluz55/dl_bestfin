import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/amount_display.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';

class AccountSelector extends ConsumerWidget {
  const AccountSelector({
    super.key,
    required this.selectedAccountId,
    required this.onAccountSelected,
    this.hint = 'Selecione uma conta',
  });

  final String? selectedAccountId;
  final ValueChanged<Account?> onAccountSelected;
  final String hint;

  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final activeAccounts = ref.watch(activeAccountsProvider);

    final selectedAccount = selectedAccountId != null
        ? activeAccounts.firstWhere(
            (a) => a.id == selectedAccountId,
            orElse: () => activeAccounts.first,
          )
        : null;

    return InkWell(
      onTap: () => _showSelectorBottomSheet(context, activeAccounts),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            if (selectedAccount != null) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hexToColor(
                    selectedAccount.color,
                  ).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconData(
                    int.parse(selectedAccount.icon),
                    fontFamily: 'MaterialIcons',
                  ),
                  color: hexToColor(selectedAccount.color),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedAccount.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      selectedAccount.type.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AmountDisplay(
                amountInCents: selectedAccount.balance,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                showSign: false,
              ),
            ] else ...[
              Icon(
                Icons.account_balance_wallet_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectorBottomSheet(BuildContext context, List<Account> accounts) {
    final theme = context.theme;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Selecione uma Conta',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Nenhuma conta ativa disponível.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final acc = accounts[idx];
                      final isSelected = acc.id == selectedAccountId;

                      return ListTile(
                        onTap: () {
                          onAccountSelected(acc);
                          Navigator.pop(context);
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: hexToColor(
                              acc.color,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            IconData(
                              int.parse(acc.icon),
                              fontFamily: 'MaterialIcons',
                            ),
                            color: hexToColor(acc.color),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          acc.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          acc.type.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AmountDisplay(
                              amountInCents: acc.balance,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              showSign: false,
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
