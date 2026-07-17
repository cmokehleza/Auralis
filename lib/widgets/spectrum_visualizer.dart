import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

class SpectrumVisualizer extends StatefulWidget {
  const SpectrumVisualizer({
    super.key,
    required this.player,
    this.height = 54,
    this.width = double.infinity,
    this.barCount = 20,
    this.continuous = true,
  });

  final PlayerController player;
  final double height;
  final double width;
  final int barCount;
  final bool continuous;

  @override
  State<SpectrumVisualizer> createState() => _SpectrumVisualizerState();
}

class _SpectrumVisualizerState extends State<SpectrumVisualizer>
    with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  late final AnimationController _activity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 460),
  );
  late final AnimationController _trackBlend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );
  late final Animation<double> _activityCurve = CurvedAnimation(
    parent: _activity,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );
  late final Listenable _repaint = Listenable.merge([
    _clock,
    _activity,
    _trackBlend,
  ]);

  late int _seed;
  late int _previousSeed;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _seed = widget.player.current.id.hashCode;
    _previousSeed = _seed;
    _activity.value = widget.player.isPlaying ? 1 : 0;
    widget.player.addListener(_handlePlayerChange);
    if (widget.player.isPlaying && widget.continuous) _clock.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AppMotion.reduced(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    _syncPlaybackAnimation();
  }

  @override
  void didUpdateWidget(covariant SpectrumVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player == widget.player) return;
    oldWidget.player.removeListener(_handlePlayerChange);
    widget.player.addListener(_handlePlayerChange);
    _seed = widget.player.current.id.hashCode;
    _previousSeed = _seed;
    _trackBlend.value = 1;
    _syncPlaybackAnimation();
  }

  void _handlePlayerChange() {
    final nextSeed = widget.player.current.id.hashCode;
    if (nextSeed != _seed) {
      _previousSeed = _seed;
      _seed = nextSeed;
      if (_reduceMotion) {
        _trackBlend.value = 1;
      } else {
        _trackBlend.forward(from: 0);
      }
    }
    _syncPlaybackAnimation();
  }

  void _syncPlaybackAnimation() {
    if (_reduceMotion) {
      _clock.stop();
      _activity.value = widget.player.isPlaying ? .55 : 0;
      return;
    }
    if (widget.player.isPlaying) {
      if (widget.continuous && !_clock.isAnimating) _clock.repeat();
      if (!widget.continuous) _clock.stop();
      _activity.forward();
    } else {
      _clock.stop();
      _activity.reverse();
    }
  }

  @override
  void dispose() {
    widget.player.removeListener(_handlePlayerChange);
    _clock.dispose();
    _activity.dispose();
    _trackBlend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: widget.player.isPlaying ? 'Song is playing' : 'Song is paused',
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: widget.width,
          child: CustomPaint(
            painter: _SpectrumPainter(
              repaint: _repaint,
              progress: _clock,
              activity: _activityCurve,
              seedBlend: _trackBlend,
              seed: () => _seed,
              previousSeed: () => _previousSeed,
              barCount: widget.barCount,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({
    required Listenable repaint,
    required this.progress,
    required this.activity,
    required this.seedBlend,
    required this.seed,
    required this.previousSeed,
    required this.barCount,
    required this.color,
  }) : super(repaint: repaint);

  final Animation<double> progress;
  final Animation<double> activity;
  final Animation<double> seedBlend;
  final int Function() seed;
  final int Function() previousSeed;
  final int barCount;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final energy = activity.value.clamp(0.0, 1.0);
    final paint = Paint()
      ..color = Color.lerp(
        AppTheme.muted.withValues(alpha: .34),
        color,
        .2 + energy * .8,
      )!;
    final gap = size.width / barCount;
    final barWidth = (gap * .52).clamp(2.0, 7.0);
    final blend = Curves.easeInOutCubic.transform(seedBlend.value.clamp(0, 1));

    for (var index = 0; index < barCount; index++) {
      final previous = _heightFor(previousSeed(), index, energy);
      final current = _heightFor(seed(), index, energy);
      final normalizedHeight = _lerp(previous, current, blend);
      final barHeight = math.max(barWidth, size.height * normalizedHeight);
      final left = index * gap + (gap - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  double _heightFor(int seed, int index, double energy) {
    final random = _unitHash(seed, index);
    final secondary = _unitHash(seed ^ 0x5bd1e995, index + 17);
    final phase = random * math.pi * 2;
    final primaryCycles = 2 + (secondary * 3).floor();
    final detailCycles = 1 + (random * 3).floor();
    final timeline = progress.value * math.pi * 2;
    final primaryWave = .5 + .5 * math.sin(timeline * primaryCycles + phase);
    final detailWave =
        .5 + .5 * math.sin(timeline * detailCycles + phase * 1.73);
    final bandShape =
        .72 + .28 * math.sin((index / math.max(1, barCount - 1)) * math.pi);
    final moving = (.66 * primaryWave + .34 * detailWave) * bandShape;
    final idle = .12 + secondary * .055;
    return idle + energy * (.18 + moving * .65);
  }

  double _unitHash(int seed, int index) {
    var value = seed ^ (index * 0x45d9f3b);
    value = ((value >> 16) ^ value) * 0x45d9f3b;
    value = ((value >> 16) ^ value) * 0x45d9f3b;
    value = (value >> 16) ^ value;
    return (value & 0xffff) / 0xffff;
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) =>
      oldDelegate.barCount != barCount || oldDelegate.color != color;
}
