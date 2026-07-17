import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key});

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 780),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, .72, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: .88,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final background = dark ? const Color(0xFF0B1020) : const Color(0xFFF7F4EE);
    final foreground = dark ? const Color(0xFFF6F7FA) : const Color(0xFF111827);
    return ColoredBox(
      color: background,
      child: Center(
        child: Semantics(
          label: 'Auralis is starting',
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/auralis_mark_512.png',
                    width: 144,
                    height: 144,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'AURALIS',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'YOUR MUSIC, IN FOCUS',
                    style: TextStyle(
                      color: foreground.withValues(alpha: .54),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.8,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
