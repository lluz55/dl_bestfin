import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/notifications/notification_service.dart';
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
        // Permissão de EXIBIR notificações (POST_NOTIFICATIONS, Android 13+)
        // — diálogo do sistema, necessário para lembretes e alertas.
        await requestAndroidNotificationPermission();
        // Acesso de LEITURA de notificações (captura de transações) — abre
        // a tela de configurações do sistema.
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
            AppButton(
              label: 'Habilitar Notificações',
              icon: Icons.notifications_rounded,
              expanded: true,
              loading: _requesting,
              onPressed: _enableNotifications,
            ),
          const SizedBox(height: 12),
          AppButton(
            label: Platform.isAndroid ? 'Agora não' : 'Continuar',
            variant: AppButtonVariant.text,
            color: cs.onSurfaceVariant,
            expanded: true,
            onPressed: widget.onNext,
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
