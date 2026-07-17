import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class AnimatedPlayPauseIcon extends StatelessWidget {
  const AnimatedPlayPauseIcon({
    super.key,
    required this.isPlaying,
    this.size,
    this.color,
  });

  final bool isPlaying;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, AppMotion.fast),
    switchInCurve: Curves.easeOutBack,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: animation, child: child),
    ),
    child: Icon(
      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
      key: ValueKey(isPlaying),
      size: size,
      color: color,
    ),
  );
}

class AnimatedFavoriteIcon extends StatelessWidget {
  const AnimatedFavoriteIcon({
    super.key,
    required this.selected,
    this.selectedColor,
  });

  final bool selected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, AppMotion.standard),
    switchInCurve: Curves.easeOutBack,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: animation, child: child),
    ),
    child: Icon(
      selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      key: ValueKey(selected),
      color: selected ? selectedColor : null,
    ),
  );
}
