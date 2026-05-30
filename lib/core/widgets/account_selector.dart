import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/amount_display.dart';
import 'package:bestfin/features/accounts/domain/models/account.dart';
import 'package:bestfin/features/accounts/presentation/providers/accounts_provider.dart';
import 'package:bestfin/features/credit_cards/domain/models/credit_card.dart';
import 'package:bestfin/features/credit_cards/presentation/providers/credit_cards_provider.dart';
import 'package:bestfin/core/utils/icon_mapper.dart';

class AccountSelector extends ConsumerStatefulWidget {
  const AccountSelector({
    super.key,
    required this.selectedAccountId,
    required this.onAccountSelected,
    this.hint = 'Selecione uma conta',
    this.showBalance = true,
    this.showCreditCards = false,
    this.selectedCreditCardId,
    this.onCreditCardSelected,
    this.focusNode,
  });

  final String? selectedAccountId;
  final ValueChanged<Account?> onAccountSelected;
  final String hint;
  final bool showBalance;
  final bool showCreditCards;
  final String? selectedCreditCardId;
  final ValueChanged<CreditCardModel?>? onCreditCardSelected;
  final FocusNode? focusNode;

  @override
  ConsumerState<AccountSelector> createState() => _AccountSelectorState();
}

class _AccountSelectorState extends ConsumerState<AccountSelector> {
  late final FocusNode _focusNode;
  bool _isSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) {
          _openSelector();
          _focusNode.unfocus();
        }
      });
    }
  }

  void _openSelector() {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    final activeAccounts = ref.read(activeAccountsProvider);
    final creditCards = widget.showCreditCards
        ? ref.read(creditCardsStreamProvider).value ?? []
        : <CreditCardModel>[];
    _showSelectorBottomSheet(context, activeAccounts, creditCards);
  }

  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final activeAccounts = ref.watch(activeAccountsProvider);
    final creditCards = widget.showCreditCards
        ? ref.watch(creditCardsStreamProvider).value ?? []
        : <CreditCardModel>[];

    // Show credit card UI only when explicitly selected via selectedCreditCardId
    CreditCardModel? selectedCard;
    if (widget.showCreditCards && widget.selectedCreditCardId != null) {
      try {
        selectedCard = creditCards.firstWhere(
          (c) => c.id == widget.selectedCreditCardId,
        );
      } catch (_) {
        selectedCard = null;
      }
    }

    Account? selectedAccount;
    if (selectedCard == null &&
        widget.selectedAccountId != null &&
        activeAccounts.isNotEmpty) {
      try {
        selectedAccount = activeAccounts.firstWhere(
          (a) => a.id == widget.selectedAccountId,
        );
      } catch (_) {
        selectedAccount = null;
      }
    }

    return Focus(
      focusNode: _focusNode,
      child: InkWell(
        onTap: _openSelector,
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
              if (selectedCard != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hexToColor(
                      selectedCard.color ?? '#2196F3',
                    ).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.credit_card_rounded,
                    color: hexToColor(selectedCard.color ?? '#2196F3'),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedCard.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Limite disponível',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showBalance)
                  AmountDisplay(
                    amountInCents: selectedCard.availableLimit,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    showSign: false,
                  ),
              ] else if (selectedAccount != null) ...[
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
                    IconMapper.fromCodePoint(int.parse(selectedAccount.icon)),
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
                if (widget.showBalance)
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
                    widget.hint,
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
      ),
    );
  }

  void _showSelectorBottomSheet(
    BuildContext context,
    List<Account> accounts,
    List<CreditCardModel> creditCards,
  ) {
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
              if (accounts.isEmpty && creditCards.isEmpty)
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
                  child: ListView(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (accounts.isNotEmpty) ...[
                        if (widget.showCreditCards && creditCards.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'CONTAS',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ...accounts.map((acc) {
                          final isSelected =
                              acc.id == widget.selectedAccountId &&
                              widget.selectedCreditCardId == null;
                          return Column(
                            children: [
                              ListTile(
                                onTap: () {
                                  widget.onAccountSelected(acc);
                                  widget.onCreditCardSelected?.call(null);
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
                                    IconMapper.fromCodePoint(
                                      int.parse(acc.icon),
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
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
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
                              ),
                              const Divider(height: 1),
                            ],
                          );
                        }),
                      ],
                      if (widget.showCreditCards && creditCards.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            'CARTÕES DE CRÉDITO',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ...creditCards.map((card) {
                          final cardColor = hexToColor(card.color ?? '#2196F3');
                          final isSelected =
                              card.id == widget.selectedCreditCardId;
                          return Column(
                            children: [
                              ListTile(
                                onTap: () {
                                  // find the account linked to this card
                                  final linkedAccount = accounts.firstWhere(
                                    (a) => a.id == card.accountId,
                                    orElse: () => accounts.first,
                                  );
                                  widget.onAccountSelected(linkedAccount);
                                  widget.onCreditCardSelected?.call(card);
                                  Navigator.pop(context);
                                },
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: cardColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.credit_card_rounded,
                                    color: cardColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  card.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  'Limite disponível',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AmountDisplay(
                                      amountInCents: card.availableLimit,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
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
                              ),
                              const Divider(height: 1),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    ).then((_) {
      _isSheetOpen = false;
    });
  }
}
