import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bestfin/core/utils/byte_formatter.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:bestfin/features/sync/data/services/sync_service.dart'
    show SyncPhaseKind;
import 'package:bestfin/features/sync/domain/models/sync_identity.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';
import 'package:bestfin/features/sync/presentation/widgets/relay_status_section.dart';

class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final identityAsync = ref.watch(currentIdentityProvider);
    final syncState = ref.watch(syncStateProvider);
    final pendingAsync = ref.watch(pendingSyncCountProvider);
    final hasRelayStatuses =
        ref.watch(relayStatusesProvider).value?.isNotEmpty ?? false;

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
              leading: CircleAvatar(child: AppLoadingIndicator()),
              title: Text('Carregando...'),
            ),
            error: (_, __) => _SignInTile(cs: cs, tt: tt),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── Sync status card ───────────────────────────────────────────────
          _SectionHeader(title: 'Status', cs: cs, tt: tt),
          _SyncStatusCard(
            syncState: syncState,
            pendingAsync: pendingAsync,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 12),
          _SyncButton(syncState: syncState, cs: cs),
          const SizedBox(height: 16),

          // ── Relays ─────────────────────────────────────────────────────────
          if (hasRelayStatuses) ...[
            _SectionHeader(title: 'Relays', cs: cs, tt: tt),
            const RelayStatusSection(),
            const SizedBox(height: 16),
          ],

          // ── Households ─────────────────────────────────────────────────────
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

// ── Status card ───────────────────────────────────────────────────────────────

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({
    required this.syncState,
    required this.pendingAsync,
    required this.cs,
    required this.tt,
  });

  final SyncState syncState;
  final AsyncValue<int> pendingAsync;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final isSyncing = syncState.status == SyncStatus.syncing;
    final isError = syncState.status == SyncStatus.error;
    final isSuccess = syncState.status == SyncStatus.success;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Phase / activity indicator ─────────────────────────────────
            if (isSyncing && syncState.currentPhase != null) ...[
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      syncState.currentPhase!,
                      style: tt.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // ── Progress bar ───────────────────────────────────────────
              // Push has a known total (the queue length), so it gets a
              // determinate bar with a percentage. Pull doesn't know how many
              // events the relays will return ahead of time, so it gets an
              // indeterminate bar with a running item/byte counter instead.
              if (syncState.syncKind == SyncPhaseKind.push &&
                  syncState.syncTotal > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: syncState.syncPercent,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${syncState.syncProgress} de ${syncState.syncTotal} itens '
                  '(${(syncState.syncPercent * 100).toStringAsFixed(0)}%) • '
                  '${ByteFormatter.format(syncState.syncBytes)}',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ] else if (syncState.syncKind == SyncPhaseKind.pull) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${syncState.syncProgress} '
                  '${syncState.syncProgress == 1 ? 'item recebido' : 'itens recebidos'} '
                  '• ${ByteFormatter.format(syncState.syncBytes)}',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              const Divider(height: 20),
            ],

            // ── Last sync result ───────────────────────────────────────────
            if ((isSuccess || isError) && !isSyncing)
              _ResultBanner(syncState: syncState, cs: cs, tt: tt),
            if ((isSuccess || isError) && !isSyncing) const Divider(height: 20),

            // ── Pending count ──────────────────────────────────────────────
            _StatusRow(
              label: 'Aguardando envio',
              value: pendingAsync.when(
                data: (n) => n == 0 ? 'Nenhum' : '$n item${n == 1 ? '' : 's'}',
                loading: () => '...',
                error: (_, __) => '?',
              ),
              valueColor: pendingAsync.when(
                data: (n) => n > 0 ? cs.tertiary : null,
                loading: () => null,
                error: (_, __) => null,
              ),
              icon: Icons.upload_rounded,
              cs: cs,
              tt: tt,
            ),
            const Divider(height: 20),

            // ── Last sync time ─────────────────────────────────────────────
            _StatusRow(
              label: 'Último sync',
              value: syncState.lastSyncAt != null
                  ? _formatRelativeTime(syncState.lastSyncAt!)
                  : 'Nunca',
              icon: Icons.history_rounded,
              cs: cs,
              tt: tt,
            ),

            // ── Error message ──────────────────────────────────────────────
            if (isError && syncState.errorMessage != null) ...[
              const Divider(height: 20),
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
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Agora há pouco';
    if (diff.inMinutes < 60) {
      return 'Há ${diff.inMinutes} min';
    }
    return DateFormat('dd/MM HH:mm').format(dt);
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.syncState,
    required this.cs,
    required this.tt,
  });

  final SyncState syncState;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final isSuccess = syncState.status == SyncStatus.success;
    final pushed = syncState.lastPushed ?? 0;
    final pulled = syncState.lastPulled ?? 0;

    if (!isSuccess) {
      return const SizedBox.shrink();
    }

    final parts = <String>[];
    if (pushed > 0) parts.add('$pushed enviado${pushed > 1 ? 's' : ''}');
    if (pulled > 0) parts.add('$pulled recebido${pulled > 1 ? 's' : ''}');

    final label = parts.isEmpty ? 'Nada a sincronizar' : parts.join(' • ');

    return Row(
      children: [
        Icon(Icons.check_circle_outline_rounded, color: cs.primary, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Sync button ───────────────────────────────────────────────────────────────

class _SyncButton extends ConsumerWidget {
  const _SyncButton({required this.syncState, required this.cs});

  final SyncState syncState;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = syncState.status == SyncStatus.syncing;
    return FilledButton.icon(
      onPressed: isSyncing
          ? null
          : () => ref.read(syncStateProvider.notifier).syncNow(),
      icon: isSyncing
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.onPrimary,
              ),
            )
          : const Icon(Icons.sync_rounded),
      label: Text(isSyncing ? 'Sincronizando...' : 'Sincronizar agora'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme cs;
  final TextTheme tt;
  final Color? valueColor;

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
          style: tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
