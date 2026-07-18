import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../theme/app_motion.dart';

class AlbumArtwork extends StatelessWidget {
  const AlbumArtwork({
    super.key,
    required this.colors,
    this.size = 64,
    this.radius = 14,
    this.artworkId,
    this.heroTag,
    this.transitionKey,
  });

  final List<Color> colors;
  final double size;
  final double radius;
  final int? artworkId;
  final String? heroTag;
  final Object? transitionKey;

  static void clearMemoryCache() => _ArtworkCache.clear();

  @override
  Widget build(BuildContext context) {
    final art = SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.standard),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .985, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: RepaintBoundary(
            key: ValueKey(transitionKey ?? artworkId ?? Object.hashAll(colors)),
            child: _ArtworkContent(
              artworkId: artworkId,
              colors: colors,
              size: size,
            ),
          ),
        ),
      ),
    );
    if (heroTag == null) return art;
    return Hero(tag: heroTag!, child: art);
  }
}

/// A soft-focus, low-resolution version of real album art for large backdrops.
///
/// Decoding at a deliberately small size creates the visual softness once the
/// image is scaled up, without a live GPU blur that would cost frames while
/// scrolling or animating the player.
class AlbumArtworkBackdrop extends StatelessWidget {
  const AlbumArtworkBackdrop({
    super.key,
    required this.colors,
    required this.artworkId,
  });

  final List<Color> colors;
  final int? artworkId;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      key: const ValueKey('artwork-backdrop-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
    final id = artworkId;
    if (id == null) return fallback;
    return FutureBuilder<Uint8List?>(
      future: _ArtworkCache.load(id, 256),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.standard),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: bytes == null || bytes.isEmpty
              ? fallback
              : Transform.scale(
                  key: ValueKey('artwork-backdrop-$id'),
                  scale: 1.08,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    cacheWidth: 72,
                    cacheHeight: 72,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => fallback,
                  ),
                ),
        );
      },
    );
  }
}

class _ArtworkContent extends StatelessWidget {
  const _ArtworkContent({
    required this.artworkId,
    required this.colors,
    required this.size,
  });

  final int? artworkId;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox.square(
      key: ValueKey('fallback-${artworkId ?? Object.hashAll(colors)}'),
      dimension: size,
      child: CustomPaint(painter: _ArtworkPainter(colors)),
    );
    final id = artworkId;
    if (id == null) return fallback;

    final pixelSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return FutureBuilder<Uint8List?>(
      future: _ArtworkCache.load(id, pixelSize),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.standard),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: bytes == null || bytes.isEmpty
              ? fallback
              : Image.memory(
                  bytes,
                  key: ValueKey('artwork-$id'),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => fallback,
                ),
        );
      },
    );
  }
}

abstract final class _ArtworkCache {
  static const _maximumEntries = 96;
  static final OnAudioQuery _query = OnAudioQuery();
  static final LinkedHashMap<String, Future<Uint8List?>> _entries =
      LinkedHashMap<String, Future<Uint8List?>>();

  static Future<Uint8List?> load(int id, int requestedSize) {
    final querySize = requestedSize <= 256
        ? 256
        : requestedSize <= 512
        ? 512
        : 768;
    final key = '$id@$querySize';
    final cached = _entries.remove(key);
    if (cached != null) {
      _entries[key] = cached;
      return cached;
    }

    late final Future<Uint8List?> future;
    future = _load(id, querySize).then((bytes) {
      if ((bytes == null || bytes.isEmpty) &&
          identical(_entries[key], future)) {
        _entries.remove(key);
      }
      return bytes;
    });
    _entries[key] = future;
    if (_entries.length > _maximumEntries) {
      _entries.remove(_entries.keys.first);
    }
    return future;
  }

  static Future<Uint8List?> _load(int id, int size) async {
    try {
      return await _query.queryArtwork(
        id,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: size,
        quality: 82,
      );
    } catch (_) {
      return null;
    }
  }

  static void clear() => _entries.clear();
}

class _ArtworkPainter extends CustomPainter {
  const _ArtworkPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );

    final haze = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.white.withValues(alpha: .54), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .72, size.height * .22),
              radius: size.width * .7,
            ),
          );
    canvas.drawRect(rect, haze);

    final wave = Path()..moveTo(-size.width * .1, size.height * .68);
    for (var x = -10.0; x <= size.width + 10; x += 4) {
      final y =
          size.height * .64 +
          math.sin(x / size.width * math.pi * 3) * size.height * .1;
      wave.lineTo(x, y);
    }
    wave.lineTo(size.width, size.height);
    wave.lineTo(0, size.height);
    wave.close();
    canvas.drawPath(wave, Paint()..color = Colors.black.withValues(alpha: .23));

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: .34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * .012);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(size.width * (.16 + i * .2), size.height * (.42 + i * .055)),
        size.width * (.18 + i * .035),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArtworkPainter oldDelegate) =>
      oldDelegate.colors != colors;
}
