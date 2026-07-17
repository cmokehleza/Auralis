import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/player_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/track.dart';
import '../services/large_library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/album_artwork.dart';
import '../widgets/motion_icons.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.player,
    required this.phaseTwo,
    required this.library,
    required this.onOpenLibrary,
    required this.onOpenSettings,
  });

  final PlayerController player;
  final PhaseTwoController phaseTwo;
  final LargeLibraryService library;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tracks = library.allTracks;
    final albums = <String, Track>{};
    for (final track in tracks) {
      albums.putIfAbsent(track.album, () => track);
    }

    return CustomScrollView(
      key: const PageStorageKey('home'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverList.list(
            children: [
              _Greeting(onSettings: onOpenSettings),
              const SizedBox(height: 24),
              if (tracks.isEmpty)
                _EmptyLibrary(onScan: onOpenLibrary)
              else ...[
                _ResumeCard(player: player, fallback: tracks.first),
                const SizedBox(height: 32),
                _SectionHeader(
                  title: 'Albums',
                  action: 'View library',
                  onTap: onOpenLibrary,
                ),
              ],
            ],
          ),
        ),
        if (tracks.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: albums.length.clamp(0, 8),
                separatorBuilder: (_, _) => const SizedBox(width: 15),
                itemBuilder: (context, index) {
                  final track = albums.values.elementAt(index);
                  final albumTracks = tracks
                      .where((item) => item.album == track.album)
                      .toList();
                  return _AlbumCard(
                    track: track,
                    onTap: () =>
                        player.playTrack(albumTracks.first, from: albumTracks),
                  );
                },
              ),
            ),
          ),
        if (tracks.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            sliver: SliverList.list(
              children: [
                _SectionHeader(
                  title: 'On this device',
                  action: 'See all',
                  onTap: onOpenLibrary,
                ),
                const SizedBox(height: 8),
                ...tracks
                    .take(6)
                    .map(
                      (track) => TrackTile(
                        track: track,
                        player: player,
                        phaseTwo: phaseTwo,
                        onTap: () => player.playTrack(track, from: tracks),
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).date(DateTime.now()).toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(greeting, style: Theme.of(context).textTheme.displaySmall),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Open settings',
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Icon(
          Icons.library_music_outlined,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(
          'Your library is empty',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Open Library and scan this phone to add local music.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onScan,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Open Library'),
        ),
      ],
    ),
  );
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.player, required this.fallback});

  final PlayerController player;
  final Track fallback;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) {
      final track = player.current.isEmpty ? fallback : player.current;
      final isCurrent = player.current.id == track.id;
      final progress = isCurrent && track.duration.inMilliseconds > 0
          ? player.position.inMilliseconds / track.duration.inMilliseconds
          : 0.0;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: Row(
          children: [
            AlbumArtwork(
              colors: track.colors,
              artworkId: track.albumArtId,
              size: 104,
              radius: 18,
              transitionKey: track.id,
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress > 0 ? 'CONTINUE LISTENING' : 'READY TO PLAY',
                    style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0, 1),
                            minHeight: 3,
                            color: Theme.of(context).colorScheme.primary,
                            backgroundColor: const Color(0xFF32363C),
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      SizedBox.square(
                        dimension: 38,
                        child: IconButton.filled(
                          tooltip: isCurrent && player.isPlaying
                              ? 'Pause'
                              : 'Play',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.ink,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: isCurrent
                              ? player.togglePlay
                              : () => player.playTrack(track),
                          icon: AnimatedPlayPauseIcon(
                            isPlaying: isCurrent && player.isPlaying,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 134,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumArtwork(
            colors: track.colors,
            artworkId: track.albumArtId,
            size: 134,
            radius: 17,
          ),
          const SizedBox(height: 9),
          Text(
            track.album,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
