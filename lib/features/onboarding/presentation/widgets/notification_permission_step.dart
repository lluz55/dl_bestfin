import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/features/notifications/presentation/providers/notification_provider.dart';

class NotificationPermissionStep extends ConsumerStatefulWidget {
  const NotificationPermissionStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  ConsumerState<NotificationPermissionStep> createState() =>
      _NotificationPermissionStepState();
}

class _NotificationPermissionStepState
    extends ConsumerState<NotificationPermissionStep> {
  bool _requesting = false;

  Future<void> _enableNotifications() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      if (Platform.isAndroid) {
        await ref.read(androidNotificationServiceProvider).requestPermission();
      }
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
        widget.onNext();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              size: 48,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Notificações',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            Platform.isAndroid
                ? 'Capture transações automaticamente a partir de notificações do seu banco.'
                : 'Receba lembretes de contas a vencer, alertas de gastos e resumos financeiros.',
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          _NotifFeatureRow(
            icon: Icons.alarm_rounded,
            label: 'Lembretes de vencimento',
            description: 'Avisamos antes das contas vencerem',
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 12),
          _NotifFeatureRow(
            icon: Icons.trending_down_rounded,
            label: 'Alertas de gastos',
            description: 'Quando você ultrapassar seu orçamento',
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 12),
          _NotifFeatureRow(
            icon: Icons.summarize_rounded,
            label: 'Resumo semanal',
            description: 'Seu desempenho financeiro da semana',
            cs: cs,
            tt: tt,
          ),
          const Spacer(),
          if (Platform.isLinux)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Captura de notificações disponível apenas no Android.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            )
          else
            FilledButton.icon(
              onPressed: _requesting ? null : _enableNotifications,
              icon: _requesting
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.notifications_rounded),
              label: Text(
                'Habilitar Notificações',
                style: tt.titleMedium?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onNext,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(
              Platform.isAndroid ? 'Agora não' : 'Continuar',
              style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _NotifFeatureRow extends StatelessWidget {
  const _NotifFeatureRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.cs,
    required this.tt,
  });

  final IconData icon;
  final String label;
  final String description;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
