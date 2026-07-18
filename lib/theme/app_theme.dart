import 'package:flutter/material.dart';

import 'app_motion.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF090B0E);
  static const surface = Color(0xFF111419);
  static const surfaceHigh = Color(0xFF1A1E24);
  static const mint = Color(0xFF95F3C7);
  static const muted = Color(0xFF949AA5);

  static const _lightBackground = Color(0xFFF4F6F7);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceHigh = Color(0xFFE9EDEF);

  static Color backgroundOf(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;

  static Color surfaceHighOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  static Color mutedOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color outlineOf(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static ThemeData light({Color accent = mint, bool highContrast = false}) {
    final generated = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: _lightSurface,
    );
    final scheme = generated.copyWith(
      primary: accent,
      onPrimary: ink,
      surface: _lightSurface,
      surfaceContainerLowest: _lightSurface,
      surfaceContainerLow: const Color(0xFFFAFBFB),
      surfaceContainer: _lightSurface,
      surfaceContainerHigh: _lightSurfaceHigh,
      surfaceContainerHighest: const Color(0xFFDDE3E5),
      onSurface: highContrast ? Colors.black : const Color(0xFF171A1D),
      onSurfaceVariant: highContrast
          ? const Color(0xFF252A2E)
          : const Color(0xFF515960),
      outlineVariant: const Color(0xFFD7DCDE),
    );
    return _build(scheme: scheme, scaffoldBackground: _lightBackground);
  }

  static ThemeData dark({Color accent = mint, bool highContrast = false}) {
    final generated = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );
    final scheme = generated.copyWith(
      primary: accent,
      onPrimary: ink,
      surface: surface,
      surfaceContainerLowest: ink,
      surfaceContainerLow: const Color(0xFF0D1014),
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: const Color(0xFF242930),
      onSurface: highContrast ? Colors.white : const Color(0xFFF6F7F8),
      onSurfaceVariant: highContrast ? const Color(0xFFE2E5E9) : muted,
      outlineVariant: const Color(0xFF343941),
    );
    return _build(scheme: scheme, scaffoldBackground: ink);
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffoldBackground,
  }) {
    final accent = scheme.primary;
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          height: 1.15,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: scheme.outlineVariant,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: .14),
        trackHeight: 3,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface.withValues(alpha: .98),
        indicatorColor: accent.withValues(alpha: .13),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? accent
                : scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? accent
                : scheme.onSurfaceVariant,
            size: 23,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _PolishedPageTransitionsBuilder(),
          TargetPlatform.iOS: _PolishedPageTransitionsBuilder(),
          TargetPlatform.macOS: _PolishedPageTransitionsBuilder(),
          TargetPlatform.windows: _PolishedPageTransitionsBuilder(),
          TargetPlatform.linux: _PolishedPageTransitionsBuilder(),
        },
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surfaceContainerHigh,
        modalBackgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: AppMotion.fast,
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? accent.withValues(alpha: .16)
                : null,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(animationDuration: AppMotion.fast),
      ),
    );
  }
}

class _PolishedPageTransitionsBuilder extends PageTransitionsBuilder {
  const _PolishedPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst || AppMotion.reduced(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(.025, .018),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}
