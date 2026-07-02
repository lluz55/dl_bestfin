import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/sync/domain/models/sync_identity.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final identityAsync = ref.watch(currentIdentityProvider);
    final syncState = ref.watch(syncStateProvider);
    final pendingAsync = ref.watch(pendingSyncCountProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Sincronização'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Identity section ───────────────────────────────────────────────
          _SectionHeader(title: 'Identidade', cs: cs, tt: tt),
          identityAsync.when(
            data: (identity) => identity != null
                ? _IdentityTile(
                    identity: identity,
                    cs: cs,
                    tt: tt,
                    onSignOut: () => _signOut(context, ref),
                    onShowQr: () => _showQr(context, ref),
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

          // ── Sync status ────────────────────────────────────────────────────
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
                        ? DateFormat('dd/MM/yy HH:mm').format(
                            syncState.lastSyncAt!)
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

          // ── Households ─────────────────────────────────────────────────────
          _SectionHeader(title: 'Colaboração', cs: cs, tt: tt),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.secondaryContainer,
              child: Icon(
                Icons.group_rounded,
                color: cs.onSecondaryContainer,
              ),
            ),
            title: const Text('Grupos familiares'),
            subtitle:
                const Text('Compartilhe contas com parceiro/família'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/sync/household'),
          ),
        ],
      ),
    );
  }

  void _showQr(BuildContext context, WidgetRef ref) {
    final masterKey = ref.read(nostrSyncServiceProvider).masterKey;
    if (masterKey == null) return;
    context.push('/sync/qr', extra: masterKey as List<int>);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover identidade?'),
        content: const Text(
          'Seus dados locais serão mantidos. Você precisará importar '
          'o mnemônico novamente para sincronizar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(nostrSyncServiceProvider).signOut();
    }
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

class _IdentityTile extends StatelessWidget {
  const _IdentityTile({
    required this.identity,
    required this.cs,
    required this.tt,
    required this.onSignOut,
    required this.onShowQr,
  });

  final SyncIdentity identity;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onSignOut;
  final VoidCallback onShowQr;

  String get _shortKey =>
      '${identity.publicKey.substring(0, 8)}...${identity.publicKey.substring(56)}';

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Text(
          identity.publicKey[0].toUpperCase(),
          style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer),
        ),
      ),
      title: Text(
        identity.displayName ?? 'Identidade Nostr',
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: identity.publicKey));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chave pública copiada')),
          );
        },
        child: Text(
          _shortKey,
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: 'Compartilhar via QR',
            onPressed: onShowQr,
          ),
          TextButton(
            onPressed: onSignOut,
            child: Text('Sair', style: TextStyle(color: cs.error)),
          ),
        ],
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
      title: const Text('Sem identidade'),
      subtitle: const Text('Configure para sincronizar seus dados'),
      trailing: FilledButton(
        onPressed: () => context.push('/sync/login'),
        child: const Text('Configurar'),
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
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const Spacer(),
        Text(
          value,
          style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
