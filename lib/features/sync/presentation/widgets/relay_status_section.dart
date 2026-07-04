import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/features/sync/domain/models/relay_connection_info.dart';
import 'package:bestfin/features/sync/presentation/providers/sync_provider.dart';

/// Compact list of configured Nostr relays with a live connected/error/
/// connecting status per relay. Renders nothing until the first sync attempt
/// opens the relay websockets and starts reporting statuses.
class RelayStatusSection extends ConsumerWidget {
  const RelayStatusSection({super.key, this.maxListHeight = 200});

  final double maxListHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final statusesAsync = ref.watch(relayStatusesProvider);

    return statusesAsync.maybeWhen(
      data: (statuses) {
        if (statuses.isEmpty) return const SizedBox.shrink();

        final sorted = statuses.values.toList()
          ..sort((a, b) => _rank(a.status).compareTo(_rank(b.status)));
        final connected = sorted
            .where((r) => r.status == RelayStatus.connected)
            .length;
        final errored = sorted
            .where((r) => r.status == RelayStatus.error)
            .length;
        final connecting = sorted
            .where((r) => r.status == RelayStatus.connecting)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _StatusSummary(
                  color: cs.tertiary,
                  label: '$connected conectado${connected == 1 ? '' : 's'}',
                ),
                if (errored > 0)
                  _StatusSummary(
                    color: cs.error,
                    label: '$errored com erro',
                  ),
                if (connecting > 0)
                  _StatusSummary(
                    color: cs.onSurfaceVariant,
                    label: '$connecting conectando...',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sorted.length,
                itemBuilder: (context, i) =>
                    _RelayRow(info: sorted[i], cs: cs, tt: tt),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  static int _rank(RelayStatus status) => switch (status) {
    RelayStatus.error => 0,
    RelayStatus.connecting => 1,
    RelayStatus.connected => 2,
  };
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RelayRow extends StatelessWidget {
  const _RelayRow({required this.info, required this.cs, required this.tt});

  final RelayConnectionInfo info;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (info.status) {
      RelayStatus.connected => (Icons.check_circle_rounded, cs.tertiary),
      RelayStatus.error => (Icons.error_rounded, cs.error),
      RelayStatus.connecting => (Icons.circle_outlined, cs.onSurfaceVariant),
    };
    final host = info.url.replaceFirst(RegExp(r'^wss?://'), '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              info.status == RelayStatus.error && info.errorMessage != null
                  ? '$host — ${info.errorMessage}'
                  : host,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
