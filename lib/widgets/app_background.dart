import 'dart:io';

import 'package:flutter/material.dart';

import '../controllers/phase_three_controller.dart';
import '../controllers/player_controller.dart';
import '../models/phase_three_models.dart';
import '../theme/app_motion.dart';
import 'album_artwork.dart';

/// A single persisted background surface shared by the shell and player.
///
/// Player position notifications are filtered by [_BackgroundSnapshot], so the
/// expensive image subtree rebuilds only when the track or appearance source
/// actually changes.
class AppBackground extends StatefulWidget {
  const AppBackground({
    super.key,
    required this.player,
    required this.controller,
    required this.child,
    this.defaultLayer,
    this.baseColor,
  });

  final PlayerController player;
  final PhaseThreeController controller;
  final Widget child;
  final Widget? defaultLayer;
  final Color? baseColor;

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  late _BackgroundSnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _readSnapshot();
    widget.player.addListener(_onSourceChanged);
    widget.controller.addListener(_onSourceChanged);
  }

  @override
  void didUpdateWidget(covariant AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.player, widget.player)) {
      oldWidget.player.removeListener(_onSourceChanged);
      widget.player.addListener(_onSourceChanged);
    }
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_onSourceChanged);
      widget.controller.addListener(_onSourceChanged);
    }
    final next = _readSnapshot();
    if (next != _snapshot) _snapshot = next;
  }

  @override
  void dispose() {
    widget.player.removeListener(_onSourceChanged);
    widget.controller.removeListener(_onSourceChanged);
    super.dispose();
  }

  void _onSourceChanged() {
    final next = _readSnapshot();
    if (next == _snapshot || !mounted) return;
    setState(() => _snapshot = next);
  }

  _BackgroundSnapshot _readSnapshot() {
    final mode = widget.controller.backgroundMode;
    final track = widget.player.current;
    return _BackgroundSnapshot(
      mode: mode,
      theme: widget.controller.backgroundTheme,
      customPath: widget.controller.customBackgroundPath,
      trackId: mode == AppBackgroundMode.dynamic ? track.id : '',
      artworkId: mode == AppBackgroundMode.dynamic ? track.albumArtId : null,
      colors: mode == AppBackgroundMode.dynamic
          ? List<Color>.of(track.colors)
          : const <Color>[],
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final layer = _BackgroundLayer(
      key: ValueKey(_snapshot.key),
      snapshot: _snapshot,
      defaultLayer: widget.defaultLayer,
      baseColor: widget.baseColor,
      brightness: brightness,
    );
    return ColoredBox(
      color: widget.baseColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.emphasized),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                child: layer,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _BackgroundLayer extends StatelessWidget {
  const _BackgroundLayer({
    super.key,
    required this.snapshot,
    required this.defaultLayer,
    required this.baseColor,
    required this.brightness,
  });

  final _BackgroundSnapshot snapshot;
  final Widget? defaultLayer;
  final Color? baseColor;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    if (snapshot.mode == AppBackgroundMode.defaultTheme) {
      return defaultLayer ??
          ColoredBox(
            color: baseColor ?? Theme.of(context).scaffoldBackgroundColor,
          );
    }

    final source = switch (snapshot.mode) {
      AppBackgroundMode.dynamic => AlbumArtworkBackdrop(
        colors: snapshot.colors.isEmpty
            ? const [Color(0xFF24313C), Color(0xFF101419)]
            : snapshot.colors,
        artworkId: snapshot.artworkId,
      ),
      AppBackgroundMode.customImage => _CustomImageLayer(
        path: snapshot.customPath,
      ),
      AppBackgroundMode.theme => _ThemeLayer(theme: snapshot.theme),
      AppBackgroundMode.defaultTheme => const SizedBox.shrink(),
    };
    final isLight = brightness == Brightness.light;
    final baseOpacity = switch (snapshot.mode) {
      AppBackgroundMode.customImage => isLight ? .82 : .68,
      AppBackgroundMode.dynamic => isLight ? .80 : .63,
      AppBackgroundMode.theme => isLight ? .72 : .54,
      AppBackgroundMode.defaultTheme => 0.0,
    };
    final veil = isLight ? Colors.white : const Color(0xFF080A0D);
    return Stack(
      fit: StackFit.expand,
      children: [
        source,
        ColoredBox(color: veil.withValues(alpha: baseOpacity)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                veil.withValues(alpha: isLight ? .02 : .08),
                veil.withValues(alpha: isLight ? .16 : .34),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomImageLayer extends StatelessWidget {
  const _CustomImageLayer({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final value = path;
    if (value == null || value.isEmpty) return const _ThemeLayer();
    final media = MediaQuery.of(context);
    final cacheWidth = (media.size.width * media.devicePixelRatio)
        .round()
        .clamp(1, 2048)
        .toInt();
    final cacheHeight = (media.size.height * media.devicePixelRatio)
        .round()
        .clamp(1, 2048)
        .toInt();
    return Image.file(
      File(value),
      key: const ValueKey('background-custom-image'),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const _ThemeLayer(),
    );
  }
}

class _ThemeLayer extends StatelessWidget {
  const _ThemeLayer({this.theme = AppBackgroundTheme.aurora});

  final AppBackgroundTheme theme;

  @override
  Widget build(BuildContext context) {
    final colors = backgroundThemeColors(theme);
    return DecoratedBox(
      key: ValueKey('background-theme-${theme.name}'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0, .48, 1],
        ),
      ),
    );
  }
}

List<Color> backgroundThemeColors(AppBackgroundTheme theme) => switch (theme) {
  AppBackgroundTheme.aurora => const [
    Color(0xFF173F4B),
    Color(0xFF194137),
    Color(0xFF181B2A),
  ],
  AppBackgroundTheme.midnight => const [
    Color(0xFF11192D),
    Color(0xFF202343),
    Color(0xFF090B12),
  ],
  AppBackgroundTheme.sunset => const [
    Color(0xFF5A2733),
    Color(0xFF673D2D),
    Color(0xFF19131D),
  ],
  AppBackgroundTheme.graphite => const [
    Color(0xFF343A40),
    Color(0xFF24282D),
    Color(0xFF101216),
  ],
};

class _BackgroundSnapshot {
  const _BackgroundSnapshot({
    required this.mode,
    required this.theme,
    required this.customPath,
    required this.trackId,
    required this.artworkId,
    required this.colors,
  });

  final AppBackgroundMode mode;
  final AppBackgroundTheme theme;
  final String? customPath;
  final String trackId;
  final int? artworkId;
  final List<Color> colors;

  Object get key => Object.hash(
    mode,
    theme,
    customPath,
    trackId,
    artworkId,
    Object.hashAll(colors),
  );

  @override
  bool operator ==(Object other) =>
      other is _BackgroundSnapshot &&
      mode == other.mode &&
      theme == other.theme &&
      customPath == other.customPath &&
      trackId == other.trackId &&
      artworkId == other.artworkId &&
      _sameColors(colors, other.colors);

  @override
  int get hashCode => key.hashCode;
}

bool _sameColors(List<Color> a, List<Color> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
