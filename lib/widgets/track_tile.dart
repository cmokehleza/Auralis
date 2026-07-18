import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../controllers/phase_two_controller.dart';
import '../models/track.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'album_artwork.dart';
import 'playlist_picker.dart';
import 'spectrum_visualizer.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.player,
    required this.onTap,
    this.showIndex,
    this.dense = false,
    this.phaseTwo,
  });

  final Track track;
  final PlayerController player;
  final VoidCallback onTap;
  final int? showIndex;
  final bool dense;
  final PhaseTwoController? phaseTwo;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return _TrackPlaybackState(
      player: player,
      trackId: track.id,
      builder: (context, active, playing) => Semantics(
        button: true,
        label: 'Play ${track.title} by ${track.artist}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8),
            child: Row(
              children: [
                if (showIndex != null)
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${showIndex! + 1}',
                      style: TextStyle(
                        color: active ? accent : AppTheme.mutedOf(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  AlbumArtwork(
                    colors: track.colors,
                    artworkId: track.albumArtId,
                    size: dense ? 48 : 56,
                    radius: 12,
                  ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: active ? accent : null,
                              ),
                            ),
                          ),
                          if (track.isLossless) ...[
                            const SizedBox(width: 7),
                            const _LosslessBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${track.artist}  •  ${track.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.mutedOf(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.duration(context, AppMotion.fast),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: active
                          ? Semantics(
                              key: ValueKey('track-state-${track.id}-$playing'),
                              label: playing
                                  ? 'Currently playing'
                                  : 'Currently paused',
                              child: playing
                                  ? SpectrumVisualizer(
                                      player: player,
                                      width: 20,
                                      height: 20,
                                      barCount: 3,
                                    )
                                  : Icon(
                                      Icons.pause_circle_outline_rounded,
                                      size: 20,
                                      color: accent,
                                    ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('track-state-hidden'),
                            ),
                    ),
                    IconButton(
                      tooltip: 'Track options',
                      onPressed: () => _showOptions(context),
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: AppTheme.mutedOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHighOf(context),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AlbumArtwork(
                  colors: track.colors,
                  artworkId: track.albumArtId,
                  size: 52,
                  radius: 11,
                ),
                title: Text(
                  track.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(track.artist),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.queue_play_next_rounded),
                title: const Text('Play next'),
                onTap: () {
                  player.addNext(track);
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${track.title} will play next')),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  player.isFavorite(track)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                title: Text(
                  player.isFavorite(track)
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                ),
                onTap: () {
                  final adding = !player.isFavorite(track);
                  player.toggleFavorite(track);
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          adding
                              ? '${track.title} added to favorites'
                              : '${track.title} removed from favorites',
                        ),
                      ),
                    );
                },
              ),
              if (phaseTwo != null)
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded),
                  title: const Text('Add to playlist'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      showAddTracksToPlaylist(
                        context,
                        phaseTwo: phaseTwo!,
                        tracks: [track],
                      );
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _TrackPlaybackBuilder =
    Widget Function(BuildContext context, bool active, bool playing);

/// Rebuilds a tile only when its relevant playback state changes. Position
/// updates are intentionally ignored so large track lists remain inexpensive.
class _TrackPlaybackState extends StatefulWidget {
  const _TrackPlaybackState({
    required this.player,
    required this.trackId,
    required this.builder,
  });

  final PlayerController player;
  final String trackId;
  final _TrackPlaybackBuilder builder;

  @override
  State<_TrackPlaybackState> createState() => _TrackPlaybackStateState();
}

class _TrackPlaybackStateState extends State<_TrackPlaybackState> {
  late bool _active;
  late bool _playing;

  @override
  void initState() {
    super.initState();
    _readState();
    widget.player.addListener(_handlePlayerChange);
  }

  @override
  void didUpdateWidget(covariant _TrackPlaybackState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      oldWidget.player.removeListener(_handlePlayerChange);
      widget.player.addListener(_handlePlayerChange);
    }
    if (oldWidget.player != widget.player ||
        oldWidget.trackId != widget.trackId) {
      _readState();
    }
  }

  void _readState() {
    _active = widget.player.current.id == widget.trackId;
    _playing = _active && widget.player.isPlaying;
  }

  void _handlePlayerChange() {
    final active = widget.player.current.id == widget.trackId;
    final playing = active && widget.player.isPlaying;
    if (active == _active && playing == _playing) return;
    setState(() {
      _active = active;
      _playing = playing;
    });
  }

  @override
  void dispose() {
    widget.player.removeListener(_handlePlayerChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _active, _playing);
}

class _LosslessBadge extends StatelessWidget {
  const _LosslessBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.mutedOf(context).withValues(alpha: .5),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'HI-RES',
        style: TextStyle(
          fontSize: 8,
          letterSpacing: .5,
          color: AppTheme.mutedOf(context),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
