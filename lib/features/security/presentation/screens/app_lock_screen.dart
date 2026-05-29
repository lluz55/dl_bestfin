import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/features/security/presentation/providers/security_provider.dart';
import 'package:bestfin/features/security/presentation/widgets/pin_input_widget.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  final _auth = LocalAuthentication();
  final _pinKey = GlobalKey<PinInputWidgetState>();
  bool _showPin = false;
  String? _pinError;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), _authenticate);
    });
  }

  Future<void> _authenticate() async {
    if (!mounted || _authenticating) return;
    setState(() => _authenticating = true);
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Confirme sua identidade para acessar o BestFin',
      );
      if (authenticated && mounted) {
        ref.read(isLockedProvider.notifier).unlock();
      }
    } catch (_) {
      if (mounted) setState(() => _showPin = true);
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _onPinComplete(String pin) async {
    final correct = await SecurityActions.verifyPin(pin);
    if (!mounted) return;
    if (correct) {
      ref.read(isLockedProvider.notifier).unlock();
    } else {
      setState(() => _pinError = 'PIN incorreto. Tente novamente.');
      _pinKey.currentState?.shake();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 40,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'BestFin',
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _showPin ? 'Digite seu PIN' : 'App bloqueado',
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              if (_showPin)
                PinInputWidget(
                  key: _pinKey,
                  onComplete: _onPinComplete,
                  errorMessage: _pinError,
                )
              else ...[
                FilledButton.icon(
                  onPressed: _authenticating ? null : _authenticate,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Usar Biometria'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _showPin = true;
                    _pinError = null;
                  }),
                  child: Text(
                    'Usar PIN',
                    style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
