import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final setupAsync = ref.watch(supabaseSetupProvider);
    final userAsync = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncStateProvider);
    final pendingAsync = ref.watch(pendingSyncCountProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Sincronização'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Supabase configuration ──────────────────────────────────────
          setupAsync.when(
            data: (setup) => _ConfigSection(
              setup: setup,
              cs: cs,
              tt: tt,
              onConfigure: () => _showConfigDialog(context, ref, setup),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // ── Auth section ───────────────────────────────────────────────
          _SectionHeader(title: 'Conta', cs: cs, tt: tt),
          userAsync.when(
            data: (user) => user != null
                ? _AccountTile(
                    user: user,
                    cs: cs,
                    tt: tt,
                    onSignOut: () => _signOut(context, ref),
                  )
                : _SignInTile(cs: cs, tt: tt),
            loading: () => const ListTile(
              leading: CircleAvatar(child: CircularProgressIndicator()),
              title: Text('Carregando...'),
            ),
            error: (_, __) => _SignInTile(cs: cs, tt: tt),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── Sync status ────────────────────────────────────────────────
          _SectionHeader(title: 'Status', cs: cs, tt: tt),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatusRow(
                    label: 'Alterações pendentes',
                    value: pendingAsync.when(
                      data: (n) => '$n item${n == 1 ? '' : 's'}',
                      loading: () => '...',
                      error: (_, __) => '?',
                    ),
                    icon: Icons.pending_rounded,
                    cs: cs,
                    tt: tt,
                  ),
                  const Divider(height: 24),
                  _StatusRow(
                    label: 'Último sync',
                    value: syncState.lastSyncAt != null
                        ? DateFormat(
                            'dd/MM/yy HH:mm',
                          ).format(syncState.lastSyncAt!)
                        : 'Nunca',
                    icon: Icons.history_rounded,
                    cs: cs,
                    tt: tt,
                  ),
                  if (syncState.errorMessage != null) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: cs.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            syncState.errorMessage!,
                            style: tt.bodySmall?.copyWith(color: cs.error),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: syncState.status == SyncStatus.syncing
                ? null
                : () => ref.read(syncStateProvider.notifier).syncNow(),
            icon: syncState.status == SyncStatus.syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: Text(
              syncState.status == SyncStatus.syncing
                  ? 'Sincronizando...'
                  : 'Sincronizar agora',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 16),

          // ── Households ─────────────────────────────────────────────────
          _SectionHeader(title: 'Colaboração', cs: cs, tt: tt),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.secondaryContainer,
              child: Icon(Icons.group_rounded, color: cs.onSecondaryContainer),
            ),
            title: const Text('Grupos familiares'),
            subtitle: const Text('Compartilhe contas com parceiro/família'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/sync/household'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Seus dados locais serão mantidos. Você precisará fazer login novamente para sincronizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(supabaseServiceProvider).signOut();
    }
  }

  void _showConfigDialog(
    BuildContext context,
    WidgetRef ref,
    SupabaseSetup setup,
  ) {
    showDialog(
      context: context,
      builder: (_) => _SupabaseConfigDialog(current: setup, ref: ref),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  const _ConfigSection({
    required this.setup,
    required this.cs,
    required this.tt,
    required this.onConfigure,
  });

  final SupabaseSetup setup;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    if (setup.isConfigured) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Supabase configurado',
                style: tt.bodySmall?.copyWith(color: cs.primary),
              ),
            ),
            TextButton(onPressed: onConfigure, child: const Text('Editar')),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.settings_outlined, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Configure o servidor Supabase para ativar o sync',
              style: tt.bodySmall?.copyWith(color: cs.error),
            ),
          ),
          TextButton(onPressed: onConfigure, child: const Text('Configurar')),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.cs,
    required this.tt,
  });

  final String title;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.user,
    required this.cs,
    required this.tt,
    required this.onSignOut,
  });

  final dynamic user;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Text(
          (user.email as String).isNotEmpty
              ? (user.email as String)[0].toUpperCase()
              : '?',
          style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer),
        ),
      ),
      title: Text(
        user.displayName ?? user.email,
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: user.displayName != null
          ? Text(
              user.email,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            )
          : null,
      trailing: TextButton(
        onPressed: onSignOut,
        child: Text('Sair', style: TextStyle(color: cs.error)),
      ),
    );
  }
}

class _SignInTile extends StatelessWidget {
  const _SignInTile({required this.cs, required this.tt});

  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.surfaceContainerHighest,
        child: Icon(Icons.person_outline, color: cs.onSurfaceVariant),
      ),
      title: const Text('Não conectado'),
      subtitle: const Text('Entre para sincronizar seus dados'),
      trailing: FilledButton(
        onPressed: () => context.push('/sync/login'),
        child: const Text('Entrar'),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.cs,
    required this.tt,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(
          value,
          style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SupabaseConfigDialog extends StatefulWidget {
  const _SupabaseConfigDialog({required this.current, required this.ref});

  final SupabaseSetup current;
  final WidgetRef ref;

  @override
  State<_SupabaseConfigDialog> createState() => _SupabaseConfigDialogState();
}

class _SupabaseConfigDialogState extends State<_SupabaseConfigDialog> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.current.url);
    _keyCtrl = TextEditingController(text: widget.current.anonKey);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar Supabase'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Crie um projeto em supabase.com e cole as credenciais abaixo.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Project URL',
                hintText: 'https://xxx.supabase.co',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Anon Key',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            await widget.ref
                .read(supabaseSetupProvider.notifier)
                .save(_urlCtrl.text.trim(), _keyCtrl.text.trim());
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
