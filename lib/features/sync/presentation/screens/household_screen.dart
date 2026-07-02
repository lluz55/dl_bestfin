import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/sync/domain/models/household.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final householdsAsync = ref.watch(householdsProvider);
    final identityAsync = ref.watch(currentIdentityProvider);

    final userEmail = identityAsync.value?.publicKey ?? '';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Grupos familiares',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: userEmail.isNotEmpty
                ? () => _showCreateDialog(context, ref, userEmail)
                : null,
            tooltip: 'Criar grupo',
          ),
        ],
      ),
      body: householdsAsync.when(
        data: (households) {
          if (households.isEmpty) {
            return _EmptyState(cs: cs, tt: tt, userEmail: userEmail, ref: ref);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: households.length,
            itemBuilder: (_, i) => _HouseholdCard(
              household: households[i],
              currentUserEmail: userEmail,
              cs: cs,
              tt: tt,
              ref: ref,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
      ),
    );
  }

  void _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    String creatorEmail,
  ) {
    showDialog(
      context: context,
      builder: (_) =>
          _CreateHouseholdDialog(creatorEmail: creatorEmail, ref: ref),
    );
  }
}

class _HouseholdCard extends StatelessWidget {
  const _HouseholdCard({
    required this.household,
    required this.currentUserEmail,
    required this.cs,
    required this.tt,
    required this.ref,
  });

  final HouseholdModel household;
  final String currentUserEmail;
  final ColorScheme cs;
  final TextTheme tt;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        household.createdBy == currentUserEmail ||
        household.members.any(
          (m) => m.email == currentUserEmail && m.role == MemberRole.admin,
        );

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Icons.group_rounded,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        household.name,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${household.members.length} membro${household.members.length == 1 ? '' : 's'}',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'invite')
                        _showInviteDialog(context, ref, household);
                      if (v == 'delete')
                        _confirmDelete(context, ref, household);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'invite',
                        child: ListTile(
                          leading: Icon(Icons.person_add_outlined),
                          title: Text('Convidar membro'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Excluir grupo'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (household.members.isNotEmpty) ...[
              const Divider(height: 20),
              ...household.members.map(
                (m) => _MemberRow(
                  member: m,
                  cs: cs,
                  tt: tt,
                  isAdmin: isAdmin,
                  ref: ref,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(
    BuildContext context,
    WidgetRef ref,
    HouseholdModel household,
  ) {
    showDialog(
      context: context,
      builder: (_) => _InviteDialog(household: household, ref: ref),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HouseholdModel household,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir grupo?'),
        content: Text('O grupo "${household.name}" será removido para todos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(householdRepositoryProvider).deleteHousehold(household.id);
    }
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.cs,
    required this.tt,
    required this.isAdmin,
    required this.ref,
  });

  final HouseholdMemberModel member;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isAdmin;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (member.role) {
      MemberRole.admin => 'Admin',
      MemberRole.editor => 'Editor',
      MemberRole.viewer => 'Leitor',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.surfaceContainerHighest,
            child: Text(
              member.email.isNotEmpty ? member.email[0].toUpperCase() : '?',
              style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.email,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  member.accepted ? roleLabel : 'Convite pendente',
                  style: tt.labelSmall?.copyWith(
                    color: member.accepted ? cs.onSurfaceVariant : cs.tertiary,
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin && member.role != MemberRole.admin)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 18),
              onPressed: () =>
                  ref.read(householdRepositoryProvider).removeMember(member.id),
              tooltip: 'Remover',
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.cs,
    required this.tt,
    required this.userEmail,
    required this.ref,
  });

  final ColorScheme cs;
  final TextTheme tt;
  final String userEmail;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'Nenhum grupo criado',
              style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie um grupo familiar para compartilhar dados com parceiro ou família.',
              style: tt.bodyMedium?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (userEmail.isNotEmpty)
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Criar grupo'),
                onPressed: () => _showCreateDialog(context, ref, userEmail),
              )
            else
              Text(
                'Faça login para criar um grupo.',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, String email) {
    showDialog(
      context: context,
      builder: (_) => _CreateHouseholdDialog(creatorEmail: email, ref: ref),
    );
  }
}

class _CreateHouseholdDialog extends StatefulWidget {
  const _CreateHouseholdDialog({required this.creatorEmail, required this.ref});

  final String creatorEmail;
  final WidgetRef ref;

  @override
  State<_CreateHouseholdDialog> createState() => _CreateHouseholdDialogState();
}

class _CreateHouseholdDialogState extends State<_CreateHouseholdDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo grupo familiar'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nome do grupo',
          hintText: 'Ex: Família Silva, Casal',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            final name = _ctrl.text.trim();
            if (name.isEmpty) return;
            await widget.ref
                .read(householdRepositoryProvider)
                .createHousehold(name, widget.creatorEmail);
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Criar'),
        ),
      ],
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.household, required this.ref});

  final HouseholdModel household;
  final WidgetRef ref;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _emailCtrl = TextEditingController();
  MemberRole _role = MemberRole.editor;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Convidar membro'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-mail do convidado',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<MemberRole>(
            value: _role,
            decoration: const InputDecoration(
              labelText: 'Permissão',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: MemberRole.viewer, child: Text('Leitor')),
              DropdownMenuItem(value: MemberRole.editor, child: Text('Editor')),
              DropdownMenuItem(value: MemberRole.admin, child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => _role = v ?? MemberRole.editor),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            final email = _emailCtrl.text.trim();
            if (email.isEmpty || !email.contains('@')) return;
            await widget.ref
                .read(householdRepositoryProvider)
                .inviteMember(
                  householdId: widget.household.id,
                  email: email,
                  role: _role,
                );
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Convidar'),
        ),
      ],
    );
  }
}
