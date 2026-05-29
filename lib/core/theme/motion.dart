import 'package:flutter/material.dart';

Duration _lerpDuration(Duration a, Duration b, double t) => Duration(
  microseconds: (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t)
      .round(),
);

@immutable
class ExpressiveMotion extends ThemeExtension<ExpressiveMotion> {
  const ExpressiveMotion({
    required this.spatialBouncy,
    required this.effectSmooth,
    required this.buttonSquish,
    required this.pageSpring,
    required this.fastDuration,
    required this.mediumDuration,
    required this.slowDuration,
    required this.morphDuration,
    required this.staggerInterval,
    required this.pageTransition,
    required this.morphCurve,
  });

  /// Springs para movimentos espaciais (stiffness alta, damping baixo — efeito elástico)
  final SpringDescription spatialBouncy;

  /// Springs para fades e mudanças de cor (stiffness moderada, damping alto — suave)
  final SpringDescription effectSmooth;

  /// Spring para squish de botão ao pressionar (MD3 Expressive button press)
  final SpringDescription buttonSquish;

  /// Spring para transições de página (moderado — natural)
  final SpringDescription pageSpring;

  final Duration fastDuration;
  final Duration mediumDuration;
  final Duration slowDuration;

  /// Duração para shape morphing (FAB collapse/expand, chip select)
  final Duration morphDuration;

  /// Intervalo de delay entre itens de lista em stagger
  final Duration staggerInterval;

  /// Duração para transições de página completas
  final Duration pageTransition;

  /// Curva para shape morphing — Material 3 emphasized
  final Curve morphCurve;

  @override
  ExpressiveMotion copyWith({
    SpringDescription? spatialBouncy,
    SpringDescription? effectSmooth,
    SpringDescription? buttonSquish,
    SpringDescription? pageSpring,
    Duration? fastDuration,
    Duration? mediumDuration,
    Duration? slowDuration,
    Duration? morphDuration,
    Duration? staggerInterval,
    Duration? pageTransition,
    Curve? morphCurve,
  }) {
    return ExpressiveMotion(
      spatialBouncy: spatialBouncy ?? this.spatialBouncy,
      effectSmooth: effectSmooth ?? this.effectSmooth,
      buttonSquish: buttonSquish ?? this.buttonSquish,
      pageSpring: pageSpring ?? this.pageSpring,
      fastDuration: fastDuration ?? this.fastDuration,
      mediumDuration: mediumDuration ?? this.mediumDuration,
      slowDuration: slowDuration ?? this.slowDuration,
      morphDuration: morphDuration ?? this.morphDuration,
      staggerInterval: staggerInterval ?? this.staggerInterval,
      pageTransition: pageTransition ?? this.pageTransition,
      morphCurve: morphCurve ?? this.morphCurve,
    );
  }

  @override
  ExpressiveMotion lerp(ThemeExtension<ExpressiveMotion>? other, double t) {
    if (other is! ExpressiveMotion) {
      return this;
    }
    return ExpressiveMotion(
      spatialBouncy: spatialBouncy,
      effectSmooth: effectSmooth,
      buttonSquish: buttonSquish,
      pageSpring: pageSpring,
      fastDuration: _lerpDuration(fastDuration, other.fastDuration, t),
      mediumDuration: _lerpDuration(mediumDuration, other.mediumDuration, t),
      slowDuration: _lerpDuration(slowDuration, other.slowDuration, t),
      morphDuration: _lerpDuration(morphDuration, other.morphDuration, t),
      staggerInterval: _lerpDuration(staggerInterval, other.staggerInterval, t),
      pageTransition: _lerpDuration(pageTransition, other.pageTransition, t),
      morphCurve: t < 0.5 ? morphCurve : other.morphCurve,
    );
  }

  static const defaultMotion = ExpressiveMotion(
    spatialBouncy: SpringDescription(
      mass: 1.0,
      stiffness: 200.0,
      damping: 15.0,
    ),
    effectSmooth: SpringDescription(mass: 1.0, stiffness: 100.0, damping: 20.0),
    buttonSquish: SpringDescription(mass: 0.5, stiffness: 400.0, damping: 12.0),
    pageSpring: SpringDescription(mass: 1.0, stiffness: 150.0, damping: 18.0),
    fastDuration: Duration(milliseconds: 200),
    mediumDuration: Duration(milliseconds: 400),
    slowDuration: Duration(milliseconds: 600),
    morphDuration: Duration(milliseconds: 350),
    staggerInterval: Duration(milliseconds: 60),
    pageTransition: Duration(milliseconds: 500),
    morphCurve: Curves.easeInOutCubicEmphasized,
  );
}
