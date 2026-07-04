import 'package:flutter/material.dart';
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
                FilledButton.icon(
                  onPressed: _enableBiometrics,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(
                    'Ativar Biometria e PIN',
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
                  onPressed: widget.onFinish,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    'Pular por enquanto',
                    style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                FilledButton.icon(
                  onPressed: _setupPin,
                  icon: const Icon(Icons.pin_outlined),
                  label: Text(
                    'Configurar PIN',
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
                  onPressed: widget.onFinish,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    'Continuar sem segurança',
                    style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
