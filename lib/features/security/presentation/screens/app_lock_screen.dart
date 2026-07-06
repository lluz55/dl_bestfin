import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bestfin/core/widgets/app_button.dart';
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
  DateTime? _lockedUntil;
  Timer? _lockoutTicker;

  @override
  void initState() {
    super.initState();
    _checkLockout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), _authenticate);
    });
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    super.dispose();
  }

  Future<void> _checkLockout() async {
    final until = await SecurityActions.pinLockedUntil();
    if (until != null && mounted) {
      _enterLockout(until);
    }
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
    if (_lockedUntil != null) return;
    final result = await SecurityActions.verifyPinAttempt(pin);
    if (!mounted) return;
    switch (result.status) {
      case PinVerifyStatus.success:
        ref.read(isLockedProvider.notifier).unlock();
      case PinVerifyStatus.invalidPin:
        setState(() => _pinError = 'PIN incorreto. Tente novamente.');
        _pinKey.currentState?.shake();
      case PinVerifyStatus.lockedOut:
        _enterLockout(result.lockedUntil!);
    }
  }

  void _enterLockout(DateTime until) {
    _lockoutTicker?.cancel();
    setState(() {
      _showPin = true;
      _lockedUntil = until;
      _pinError = _lockoutMessage(until.difference(DateTime.now()));
    });
    _lockoutTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = until.difference(DateTime.now());
      if (!mounted) return;
      if (remaining <= Duration.zero) {
        _lockoutTicker?.cancel();
        setState(() {
          _lockedUntil = null;
          _pinError = null;
        });
      } else {
        setState(() => _pinError = _lockoutMessage(remaining));
      }
    });
  }

  String _lockoutMessage(Duration remaining) {
    final seconds = remaining.inSeconds.clamp(0, 999999);
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return 'Muitas tentativas. Tente novamente em $mm:$ss.';
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
                  enabled: _lockedUntil == null,
                )
              else ...[
                AppButton(
                  label: 'Usar Biometria',
                  icon: Icons.fingerprint_rounded,
                  expanded: true,
                  onPressed: _authenticating ? null : _authenticate,
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
