import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bestfin/features/sync/domain/models/relay_connection_info.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

/// Lets the user manage their Nostr relays: view the configured list (with the
/// live connection status per relay), add a new relay, remove one, or restore
/// the defaults. Changes persist and reconnect through the sync service.
class RelayManagerSection extends ConsumerStatefulWidget {
  const RelayManagerSection({super.key});

  @override
  ConsumerState<RelayManagerSection> createState() =>
      _RelayManagerSectionState();
}

class _RelayManagerSectionState extends ConsumerState<RelayManagerSection> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    setState(() => _busy = true);
    final error = await ref.read(relayListProvider.notifier).addRelay(raw);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _snack(error);
    } else {
      _controller.clear();
    }
  }

  Future<void> _remove(String url) async {
    setState(() => _busy = true);
    final error = await ref.read(relayListProvider.notifier).removeRelay(url);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) _snack(error);
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar relays padrão?'),
        content: const Text(
          'Sua lista de relays personalizada será substituída pela lista '
          'padrão do BestFin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    await ref.read(relayListProvider.notifier).resetToDefaults();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final relaysAsync = ref.watch(relayListProvider);
    final statuses = ref.watch(relayStatusesProvider).value ?? const {};

    return relaysAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        'Erro ao carregar relays: $e',
        style: tt.bodySmall?.copyWith(color: cs.error),
      ),
      data: (relays) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final url in relays)
            _RelayTile(
              url: url,
              status: statuses[url]?.status,
              errorMessage: statuses[url]?.errorMessage,
              canRemove: relays.length > 1 && !_busy,
              onRemove: () => _remove(url),
              cs: cs,
              tt: tt,
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'wss://seu-relay.com',
                    labelText: 'Adicionar relay',
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Adicionar relay',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy ? null : _restoreDefaults,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Restaurar padrões'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelayTile extends StatelessWidget {
  const _RelayTile({
    required this.url,
    required this.status,
    required this.errorMessage,
    required this.canRemove,
    required this.onRemove,
    required this.cs,
    required this.tt,
  });

  final String url;
  final RelayStatus? status;
  final String? errorMessage;
  final bool canRemove;
  final VoidCallback onRemove;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      RelayStatus.connected => (Icons.check_circle_rounded, cs.tertiary),
      RelayStatus.error => (Icons.error_rounded, cs.error),
      RelayStatus.connecting => (Icons.circle_outlined, cs.onSurfaceVariant),
      null => (Icons.circle_outlined, cs.onSurfaceVariant.withValues(alpha: 0.5)),
    };
    final host = url.replaceFirst(RegExp(r'^wss?://'), '');
    final subtitle = status == RelayStatus.error && errorMessage != null
        ? errorMessage
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  host,
                  style: tt.bodySmall?.copyWith(color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: tt.labelSmall?.copyWith(color: cs.error),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: canRemove ? onRemove : null,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Remover relay',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
