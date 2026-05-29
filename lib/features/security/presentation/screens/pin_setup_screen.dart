import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bestfin/core/extensions/context_extensions.dart';
import 'package:bestfin/core/widgets/app_page_appbar.dart';
import 'package:bestfin/features/security/presentation/providers/security_provider.dart';
import 'package:bestfin/features/security/presentation/widgets/pin_input_widget.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pinKey = GlobalKey<PinInputWidgetState>();
  String? _firstPin;
  String? _errorMessage;

  bool get _isConfirmStep => _firstPin != null;

  void _onPinComplete(String pin) {
    if (_firstPin == null) {
      setState(() => _firstPin = pin);
    } else {
      if (pin == _firstPin) {
        _savePin(pin);
      } else {
        setState(() {
          _errorMessage = 'PINs não coincidem. Tente novamente.';
          _firstPin = null;
        });
        _pinKey.currentState?.shake();
      }
    }
  }

  Future<void> _savePin(String pin) async {
    await SecurityActions.setPin(pin);
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final tt = context.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const AppPageAppBar(title: 'Configurar PIN'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.pin_outlined,
                  size: 32,
                  color: cs.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isConfirmStep
                    ? 'Confirme seu PIN'
                    : 'Crie um PIN de 4 dígitos',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirmStep
                    ? 'Digite o PIN novamente para confirmar'
                    : 'Usado como alternativa à biometria',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              PinInputWidget(
                key: _pinKey,
                onComplete: _onPinComplete,
                errorMessage: _errorMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
