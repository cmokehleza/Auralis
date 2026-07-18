import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/phase_three_controller.dart';
import '../controllers/player_controller.dart';
import '../screens/now_playing_screen.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'album_artwork.dart';
import 'motion_icons.dart';
import 'spectrum_visualizer.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.player,
    required this.phaseTwo,
    required this.phaseThree,
  });

  final PlayerController player;
  final PhaseTwoController phaseTwo;
  final PhaseThreeController phaseThree;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final track = player.current;
        if (track.isEmpty) {
          return const SizedBox.shrink(key: ValueKey('mini-player-empty'));
        }
        if (player.playbackError != null) {
          return Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              title: Text(
                'Could not play ${track.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Tap retry or choose another track.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              trailing: IconButton(
                tooltip: 'Retry playback',
                onPressed: player.retryCurrent,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          );
        }
        final durationMs = track.duration.inMilliseconds;
        final progress = durationMs <= 0
            ? 0.0
            : player.position.inMilliseconds / durationMs;
        return Material(
          key: const ValueKey('mini-player-content'),
          color: phaseThree.backgroundMode.name == 'defaultTheme'
              ? AppTheme.surfaceHighOf(context)
              : AppTheme.surfaceHighOf(context).withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? .76
                      : .88,
                ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              AppMotion.playerRoute<void>(
                context: context,
                builder: (_) => NowPlayingScreen(
                  player: player,
                  phaseTwo: phaseTwo,
                  phaseThree: phaseThree,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 11, 8),
                      child: AlbumArtwork(
                        colors: track.colors,
                        artworkId: track.albumArtId,
                        size: 48,
                        radius: 10,
                        heroTag: 'current-art-${track.id}',
                        transitionKey: track.id,
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.duration(
                          context,
                          AppMotion.standard,
                        ),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(.025, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Column(
                          key: ValueKey('mini-metadata-${track.id}'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${track.artist}  •  ${track.isLossless ? 'Hi-Res' : 'AAC'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.mutedOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SpectrumVisualizer(
                        player: player,
                        width: 26,
                        height: 22,
                        barCount: 3,
                        continuous: true,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next track',
                      onPressed: player.next,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton.filled(
                        tooltip: player.isPlaying ? 'Pause' : 'Play',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                        ),
                        onPressed: player.togglePlay,
                        icon: AnimatedPlayPauseIcon(
                          isPlaying: player.isPlaying,
                        ),
                      ),
                    ),
                  ],
                ),
                LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 2,
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: AppTheme.outlineOf(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
