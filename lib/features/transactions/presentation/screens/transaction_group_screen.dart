import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/theme/breakpoints.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/empty_state.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/transactions/domain/models/transaction.dart';
import 'package:bestfin/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:bestfin/features/transactions/presentation/screens/bulk_transaction_screen.dart';
import 'package:bestfin/features/transactions/presentation/widgets/transaction_form_modal_overlay.dart';

/// Abre a edição de um bloco agrupado no mesmo padrão de apresentação do
/// formulário de criar/editar transação: bottom sheet com altura limitada
/// (65% da tela) no mobile e painel adaptativo em telas largas.
Future<void> showTransactionGroupModal(BuildContext context, String groupId) {
  if (Breakpoints.isCompact(context)) {
    return showLimitedTransactionSheet<void>(
      context: context,
      builder: (sheetContext) => TransactionGroupScreen(
        groupId: groupId,
        onClose: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }
  return showAdaptiveModal<void>(
    context: context,
    builder: (modalContext) => TransactionGroupScreen(
      groupId: groupId,
      onClose: () => Navigator.of(modalContext).pop(),
    ),
  );
}

/// Edição de um bloco de lançamentos agrupados. Carrega os membros do bloco e
/// abre a mesma tela da inserção em massa ([BulkTransactionScreen]) em modo de
/// edição — o cabeçalho compartilhado e as linhas vêm pré-preenchidos, e salvar
/// substitui o bloco no lugar.
class TransactionGroupScreen extends ConsumerStatefulWidget {
  const TransactionGroupScreen({
    super.key,
    required this.groupId,
    this.onClose,
  });

  final String groupId;

  /// Fecha o modal quando a tela está hospedada em bottom sheet/painel
  /// (mesmo contrato do formulário individual). Nulo quando aberta como rota.
  final VoidCallback? onClose;

  @override
  ConsumerState<TransactionGroupScreen> createState() =>
      _TransactionGroupScreenState();
}

class _TransactionGroupScreenState
    extends ConsumerState<TransactionGroupScreen> {
  /// Membros capturados na primeira carga. Emissões posteriores do stream (ex:
  /// sync) não recriam o editor, para não descartar alterações em andamento.
  List<TransactionModel>? _members;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(
      transactionGroupMembersProvider(widget.groupId),
    );
    _members ??= membersAsync.asData?.value;
    final members = _members;

    if (members == null) {
      return Scaffold(
        backgroundColor: context.colorScheme.surface,
        appBar: widget.onClose != null
            ? null
            : const AppPageAppBar(title: 'Editar Bloco'),
        body: membersAsync.hasError
            ? Center(
                child: Text(
                  'Erro ao carregar o bloco.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
              )
            : const Center(child: AppLoadingIndicator()),
      );
    }

    if (members.isEmpty) {
      return Scaffold(
        backgroundColor: context.colorScheme.surface,
        appBar: widget.onClose != null
            ? null
            : const AppPageAppBar(title: 'Editar Bloco'),
        body: const Center(
          child: EmptyState(
            title: 'Bloco vazio',
            description: 'Todos os lançamentos deste bloco foram removidos.',
            icon: Icons.layers_clear_rounded,
          ),
        ),
      );
    }

    return BulkTransactionScreen(
      initialGroup: members,
      onClose: widget.onClose,
    );
  }
}
