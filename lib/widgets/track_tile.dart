import 'package:flutter/material.dart';

import '../controllers/player_controller.dart';
import '../controllers/phase_two_controller.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import 'album_artwork.dart';
import 'playlist_picker.dart';

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
    final active = player.current.id == track.id;
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
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
                    style: TextStyle(color: active ? accent : AppTheme.muted),
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
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Track options',
                onPressed: () => _showOptions(context),
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
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
                  player.toggleFavorite(track);
                  Navigator.pop(sheetContext);
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

class _LosslessBadge extends StatelessWidget {
  const _LosslessBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.muted.withValues(alpha: .5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'HI-RES',
        style: TextStyle(
          fontSize: 8,
          letterSpacing: .5,
          color: AppTheme.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
