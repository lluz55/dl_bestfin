import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/utils/adaptive_modal.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/notifications/domain/models/notification_pattern.dart';
import 'package:bestfin/features/notifications/presentation/providers/notification_provider.dart';
import 'package:bestfin/features/notifications/presentation/widgets/pattern_editor.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final patternsAsync = ref.watch(allPatternsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppPageAppBar(
        title: 'Captura de notificações',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Adicionar padrão',
            onPressed: () => _openEditor(context, ref, null),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (Platform.isAndroid) ...[
                  _PermissionBanner(ref: ref, cs: cs, tt: tt),
                  const Divider(height: 1),
                ] else if (Platform.isLinux) ...[
                  _LinuxInfoBanner(cs: cs, tt: tt),
                  const Divider(height: 1),
                ],
                _PrivacyNote(cs: cs, tt: tt),
                const Divider(height: 1),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                'PADRÕES DE BANCOS',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          patternsAsync.when(
            data: (patterns) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _PatternTile(
                  pattern: patterns[i],
                  cs: cs,
                  tt: tt,
                  onToggle: (enabled) =>
                      ref.read(togglePatternProvider)(patterns[i].id, enabled),
                  onEdit: () => _openEditor(context, ref, patterns[i]),
                  onDelete: () => _deletePattern(context, ref, patterns[i]),
                ),
                childCount: patterns.length,
              ),
            ),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: AppLoadingIndicator()),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro: $err'),
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  void _openEditor(
    BuildContext context,
    WidgetRef ref,
    NotificationPatternModel? existing,
  ) {
    showAdaptiveModal(
      context: context,
      builder: (_) => PatternEditor(
        existing: existing,
        onSave: (pattern) => ref.read(savePatternProvider)(pattern),
      ),
    );
  }

  Future<void> _deletePattern(
    BuildContext context,
    WidgetRef ref,
    NotificationPatternModel pattern,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir padrão?'),
        content: Text(
          'O padrão "${pattern.bankName}" será removido permanentemente.',
        ),
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
    if (confirmed == true) {
      await ref.read(deletePatternProvider)(pattern.id);
    }
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({
    required this.ref,
    required this.cs,
    required this.tt,
  });

  final WidgetRef ref;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final permAsync = ref.watch(notificationPermissionProvider);

    return permAsync.when(
      data: (granted) => Container(
        padding: const EdgeInsets.all(16),
        color: granted
            ? cs.primaryContainer.withValues(alpha: 0.3)
            : cs.errorContainer.withValues(alpha: 0.3),
        child: Row(
          children: [
            Icon(
              granted ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: granted ? cs.primary : cs.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    granted
                        ? 'Acesso a notificações ativo'
                        : 'Permissão necessária',
                    style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: granted ? cs.primary : cs.error,
                    ),
                  ),
                  Text(
                    granted
                        ? 'O app pode capturar notificações bancárias.'
                        : 'Conceda acesso para capturar notificações bancárias.',
                    style: tt.bodySmall?.copyWith(
                      color: granted
                          ? cs.onPrimaryContainer
                          : cs.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (!granted)
              FilledButton(
                onPressed: () => ref
                    .read(androidNotificationServiceProvider)
                    .requestPermission(),
                child: const Text('Permitir'),
              ),
          ],
        ),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LinuxInfoBanner extends StatelessWidget {
  const _LinuxInfoBanner({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: cs.secondaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: cs.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No Linux, as notificações são capturadas via D-Bus '
              '(org.freedesktop.Notifications). Requer gdbus instalado.',
              style: tt.bodySmall?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Privacidade: todo o processamento é local. Nenhum dado de '
              'notificação é enviado para servidores externos.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternTile extends StatelessWidget {
  const _PatternTile({
    required this.pattern,
    required this.cs,
    required this.tt,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final NotificationPatternModel pattern;
  final ColorScheme cs;
  final TextTheme tt;
  final void Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Text(
          pattern.bankName.isNotEmpty ? pattern.bankName[0].toUpperCase() : '?',
          style: tt.labelMedium?.copyWith(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        pattern.bankName.isEmpty ? '(sem nome)' : pattern.bankName,
        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        pattern.regexPattern,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tt.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontFamily: 'monospace',
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: pattern.isEnabled, onChanged: onToggle),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              const PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ],
      ),
    );
  }
}
