import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 320);
  static const emphasized = Duration(milliseconds: 480);

  static bool reduced(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
  }

  static Duration duration(BuildContext context, Duration preferred) =>
      reduced(context) ? Duration.zero : preferred;

  static Route<T> playerRoute<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    final reduceMotion = reduced(context);
    return PageRouteBuilder<T>(
      transitionDuration: reduceMotion ? Duration.zero : emphasized,
      reverseTransitionDuration: reduceMotion ? Duration.zero : standard,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (reduceMotion) return child;
        final entrance = CurvedAnimation(
          parent: animation,
          curve: const _DampedSpringCurve(),
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .08),
              end: Offset.zero,
            ).animate(entrance),
            child: ScaleTransition(
              scale: Tween<double>(begin: .985, end: 1).animate(entrance),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _DampedSpringCurve extends Curve {
  const _DampedSpringCurve();

  @override
  double transformInternal(double t) {
    if (t == 0 || t == 1) return t;
    final value = 1 - math.exp(-8 * t) * math.cos(10 * t);
    return value.clamp(0, 1.025);
  }
}
