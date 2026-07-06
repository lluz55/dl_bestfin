import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
import 'package:bestfin/core/widgets/loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/features/onboarding/presentation/providers/onboarding_provider.dart';

class SecurityStep extends ConsumerStatefulWidget {
  const SecurityStep({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  ConsumerState<SecurityStep> createState() => _SecurityStepState();
}

class _SecurityStepState extends ConsumerState<SecurityStep> {
  final _auth = LocalAuthentication();
  bool _biometricsAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      setState(() {
        _biometricsAvailable = canCheck && isSupported;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _biometricsAvailable = false;
        _loading = false;
      });
    }
  }

  Future<void> _setupPin() async {
    final result = await context.push<bool>('/security/pin-setup');
    if (result != true || !mounted) return;
    widget.onFinish();
  }

  Future<void> _enableBiometrics() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Confirme sua identidade para ativar o BestFin',
      );
      if (!authenticated || !mounted) return;

      final result = await context.push<bool>('/security/pin-setup');
      if (result != true || !mounted) return;

      await OnboardingActions.setBiometrics(ref, true);
      widget.onFinish();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao configurar biometria: $e')),
        );
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
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.fingerprint_rounded,
              size: 52,
              color: cs.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Segurança',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _biometricsAvailable
                ? 'Proteja seus dados financeiros com biometria e PIN de fallback.'
                : 'Biometria não disponível. Configure um PIN para proteger seus dados.',
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const Spacer(),
          if (_loading)
            const AppLoadingIndicator()
          else if (_biometricsAvailable)
            Column(
              children: [
                AppButton(
                  label: 'Ativar Biometria e PIN',
                  icon: Icons.fingerprint_rounded,
                  expanded: true,
                  onPressed: _enableBiometrics,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Pular por enquanto',
                  variant: AppButtonVariant.text,
                  color: cs.onSurfaceVariant,
                  expanded: true,
                  onPressed: widget.onFinish,
                ),
              ],
            )
          else
            Column(
              children: [
                AppButton(
                  label: 'Configurar PIN',
                  icon: Icons.pin_outlined,
                  expanded: true,
                  onPressed: _setupPin,
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Continuar sem segurança',
                  variant: AppButtonVariant.text,
                  color: cs.onSurfaceVariant,
                  expanded: true,
                  onPressed: widget.onFinish,
                ),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
