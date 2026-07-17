import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/phase_three_controller.dart';
import '../controllers/player_controller.dart';
import '../models/advanced_models.dart';
import '../models/track.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/album_artwork.dart';
import '../widgets/motion_icons.dart';
import '../widgets/playlist_picker.dart';
import '../widgets/spectrum_visualizer.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({
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
        return Scaffold(
          backgroundColor: AppTheme.ink,
          body: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(child: _Atmosphere(colors: track.colors)),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final landscape =
                        constraints.maxWidth > constraints.maxHeight &&
                        constraints.maxWidth >= 700;
                    if (landscape) {
                      return _LandscapePlayer(
                        player: player,
                        phaseTwo: phaseTwo,
                        phaseThree: phaseThree,
                        track: track,
                        onArtLongPress: () => _showQuickActions(context, track),
                      );
                    }
                    final compact = constraints.maxHeight < 720;
                    final artSize = (constraints.maxWidth - 56).clamp(
                      220.0,
                      compact ? 300.0 : 360.0,
                    );
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 32,
                        ),
                        child: Column(
                          children: [
                            _TopBar(
                              player: player,
                              onMore: () => _showQuickActions(context, track),
                            ),
                            SizedBox(height: compact ? 16 : 28),
                            GestureDetector(
                              onLongPress: () =>
                                  _showQuickActions(context, track),
                              child: AlbumArtwork(
                                colors: track.colors,
                                artworkId: track.albumArtId,
                                size: artSize,
                                radius: 28,
                                heroTag: 'current-art-${track.id}',
                                transitionKey: track.id,
                              ),
                            ),
                            SizedBox(height: compact ? 22 : 34),
                            _TrackHeading(track: track, player: player),
                            const SizedBox(height: 8),
                            SpectrumVisualizer(player: player),
                            if (phaseThree.showLyrics) ...[
                              const SizedBox(height: 12),
                              _SyncedLyrics(
                                player: player,
                                phaseThree: phaseThree,
                              ),
                            ],
                            SizedBox(height: compact ? 14 : 24),
                            _Progress(player: player),
                            SizedBox(height: compact ? 8 : 16),
                            _Transport(player: player),
                            const SizedBox(height: 8),
                            _PracticeTools(player: player, phaseTwo: phaseTwo),
                            SizedBox(height: compact ? 10 : 18),
                            _BottomActions(player: player),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQuickActions(BuildContext context, Track track) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(sheetContext);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  showAddTracksToPlaylist(
                    context,
                    phaseTwo: phaseTwo,
                    tracks: [track],
                  );
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share track details'),
              onTap: () {
                Navigator.pop(sheetContext);
                ShareService.shareText(
                  '${track.title} — ${track.artist} • ${track.album}',
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Track information'),
              subtitle: Text(
                '${track.genre} • ${formatDuration(track.duration)} • ${track.isLossless ? 'Lossless' : 'Standard'}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandscapePlayer extends StatelessWidget {
  const _LandscapePlayer({
    required this.player,
    required this.phaseTwo,
    required this.phaseThree,
    required this.track,
    required this.onArtLongPress,
  });

  final PlayerController player;
  final PhaseTwoController phaseTwo;
  final PhaseThreeController phaseThree;
  final Track track;
  final VoidCallback onArtLongPress;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 28, 18),
    child: Column(
      children: [
        _TopBar(player: player, onMore: onArtLongPress),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Center(
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final size = constraints.biggest.shortestSide.clamp(
                        230.0,
                        430.0,
                      );
                      return GestureDetector(
                        onLongPress: onArtLongPress,
                        child: AlbumArtwork(
                          colors: track.colors,
                          artworkId: track.albumArtId,
                          size: size,
                          radius: 26,
                          heroTag: 'current-art-${track.id}',
                          transitionKey: track.id,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 34),
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _TrackHeading(track: track, player: player),
                      const SizedBox(height: 8),
                      SpectrumVisualizer(player: player, height: 46),
                      if (phaseThree.showLyrics)
                        _SyncedLyrics(player: player, phaseThree: phaseThree),
                      const SizedBox(height: 10),
                      _Progress(player: player),
                      const SizedBox(height: 4),
                      _Transport(player: player),
                      const SizedBox(height: 8),
                      _PracticeTools(player: player, phaseTwo: phaseTwo),
                      const SizedBox(height: 10),
                      _BottomActions(player: player),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SyncedLyrics extends StatelessWidget {
  const _SyncedLyrics({required this.player, required this.phaseThree});

  final PlayerController player;
  final PhaseThreeController phaseThree;

  @override
  Widget build(BuildContext context) {
    final lines = player.current.syncedLyrics;
    var active = 'No synchronized lyrics loaded for this track.';
    if (lines.isNotEmpty) {
      for (final line in lines) {
        final match = RegExp(
          r'^\[(\d+):(\d+)(?:\.(\d+))?\](.*)$',
        ).firstMatch(line);
        if (match == null) continue;
        final at = Duration(
          minutes: int.parse(match.group(1)!),
          seconds: int.parse(match.group(2)!),
          milliseconds:
              int.tryParse((match.group(3) ?? '0').padRight(3, '0')) ?? 0,
        );
        if (at <= player.position) active = match.group(4)!.trim();
      }
    }
    final foreground = phaseThree.highContrastLyrics
        ? Colors.white
        : AppTheme.muted;
    return Semantics(
      liveRegion: true,
      label: 'Current lyric: $active',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: phaseThree.highContrastLyrics
              ? Colors.black
              : AppTheme.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(14),
          border: phaseThree.highContrastLyrics
              ? Border.all(color: Colors.white)
              : null,
        ),
        child: Text(
          active,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground,
            fontSize: 16 * phaseThree.lyricsFontScale,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Atmosphere extends StatelessWidget {
  const _Atmosphere({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -100,
            right: -100,
            height: 520,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      colors.first.withValues(alpha: .44),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppTheme.ink],
                stops: [.25, .82],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.player, required this.onMore});

  final PlayerController player;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Close now playing',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
        ),
        const Expanded(
          child: Column(
            children: [
              Text(
                'NOW PLAYING',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'On this device',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'More options',
          onPressed: onMore,
          icon: const Icon(Icons.more_horiz_rounded),
        ),
      ],
    );
  }
}

class _TrackHeading extends StatelessWidget {
  const _TrackHeading({required this.track, required this.player});

  final Track track;
  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              Text(
                '${track.artist}  •  ${track.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 15),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: player.isFavorite(track)
              ? 'Remove from favorites'
              : 'Add to favorites',
          onPressed: () => player.toggleFavorite(track),
          icon: AnimatedFavoriteIcon(
            selected: player.isFavorite(track),
            selectedColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final max = player.current.duration.inMilliseconds.toDouble();
    final value = player.position.inMilliseconds
        .clamp(0, max.toInt())
        .toDouble();
    return Column(
      children: [
        Slider(
          value: value,
          max: max,
          onChanged: (value) =>
              player.seek(Duration(milliseconds: value.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(player.position),
                style: const TextStyle(color: AppTheme.muted, fontSize: 11),
              ),
              Text(
                '-${formatDuration(player.current.duration - player.position)}',
                style: const TextStyle(color: AppTheme.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Shuffle',
          onPressed: player.toggleShuffle,
          icon: Icon(
            Icons.shuffle_rounded,
            color: player.shuffle
                ? Theme.of(context).colorScheme.primary
                : AppTheme.muted,
          ),
        ),
        IconButton(
          tooltip: 'Previous',
          onPressed: player.previous,
          icon: const Icon(Icons.skip_previous_rounded, size: 38),
        ),
        SizedBox.square(
          dimension: 68,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.ink,
            ),
            onPressed: player.togglePlay,
            child: AnimatedPlayPauseIcon(isPlaying: player.isPlaying, size: 38),
          ),
        ),
        IconButton(
          tooltip: 'Next',
          onPressed: player.next,
          icon: const Icon(Icons.skip_next_rounded, size: 38),
        ),
        IconButton(
          tooltip: 'Repeat mode',
          onPressed: player.cycleRepeat,
          icon: Icon(
            player.repeatMode == PlaybackRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: player.repeatMode == PlaybackRepeatMode.off
                ? AppTheme.muted
                : Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _PracticeTools extends StatelessWidget {
  const _PracticeTools({required this.player, required this.phaseTwo});

  final PlayerController player;
  final PhaseTwoController phaseTwo;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.looks_one_outlined, size: 17),
          label: Text(
            player.loopA == null ? 'Set A' : formatDuration(player.loopA!),
          ),
          onPressed: player.markLoopA,
        ),
        ActionChip(
          avatar: const Icon(Icons.looks_two_outlined, size: 17),
          label: Text(
            player.loopB == null ? 'Set B' : formatDuration(player.loopB!),
          ),
          onPressed: player.loopA == null ? null : player.markLoopB,
        ),
        if (player.loopA != null)
          ActionChip(
            avatar: const Icon(Icons.close_rounded, size: 17),
            label: const Text('Clear A/B'),
            onPressed: player.clearLoop,
          ),
        ActionChip(
          avatar: const Icon(Icons.bookmark_add_outlined, size: 17),
          label: const Text('Bookmark'),
          onPressed: () => _bookmarks(context),
        ),
        ActionChip(
          avatar: const Icon(Icons.bedtime_outlined, size: 17),
          label: const Text('Sleep'),
          onPressed: () => _sleepTimer(context),
        ),
      ],
    );
  }

  void _bookmarks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      builder: (context) => AnimatedBuilder(
        animation: phaseTwo,
        builder: (context, _) {
          final items = phaseTwo.bookmarksFor(player.current.id);
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Track bookmarks',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => phaseTwo.addBookmark(
                        player.current.id,
                        player.position,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Save here'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Center(
                      child: Text(
                        'No bookmarks in this track yet',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    ),
                  )
                else
                  ...items.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.bookmark_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(item.label),
                      subtitle: Text(formatDuration(item.position)),
                      onTap: () {
                        player.seek(item.position);
                        Navigator.pop(context);
                      },
                      trailing: IconButton(
                        onPressed: () => phaseTwo.removeBookmark(item.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _sleepTimer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep timer', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Stop in 30 minutes'),
              onTap: () {
                phaseTwo.configureSleepTimer(
                  SleepTimerMode.minutes,
                  minutes: 30,
                  onElapsed: player.pause,
                );
                player.configureSleepStop(
                  afterCurrentTrack: false,
                  afterQueue: false,
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next_rounded),
              title: const Text('Stop after current track'),
              onTap: () {
                phaseTwo.configureSleepTimer(SleepTimerMode.endOfTrack);
                player.configureSleepStop(
                  afterCurrentTrack: true,
                  afterQueue: false,
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Stop after current queue'),
              onTap: () {
                phaseTwo.configureSleepTimer(SleepTimerMode.endOfQueue);
                player.configureSleepStop(
                  afterCurrentTrack: false,
                  afterQueue: true,
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Turn off'),
              onTap: () {
                phaseTwo.configureSleepTimer(SleepTimerMode.off);
                player.configureSleepStop(
                  afterCurrentTrack: false,
                  afterQueue: false,
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Action(
          icon: Icons.speed_rounded,
          label: '${player.speed.toStringAsFixed(1)}×',
          onTap: () => _showSpeed(context),
        ),
        _Action(
          icon: Icons.lyrics_outlined,
          label: 'Lyrics',
          onTap: () => _showLyrics(context),
        ),
        _Action(
          icon: Icons.queue_music_rounded,
          label: 'Queue',
          onTap: () => _showQueue(context),
        ),
        _Action(
          icon: Icons.graphic_eq_rounded,
          label: 'Audio',
          onTap: () => _showAudio(context),
        ),
      ],
    );
  }

  void _showSpeed(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Playback speed',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              Text(
                '${player.speed.toStringAsFixed(1)}×',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Slider(
                min: .5,
                max: 2,
                divisions: 15,
                value: player.speed,
                onChanged: (value) {
                  player.setSpeed(value);
                  setModalState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLyrics(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .68,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lyrics', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                player.current.title,
                style: const TextStyle(color: AppTheme.muted),
              ),
              const Spacer(),
              Text(
                'Light moves across the open floor',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.muted),
              ),
              const SizedBox(height: 22),
              Text(
                'Every quiet shape becomes a door',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 22),
              Text(
                'We follow where the evening goes',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppTheme.muted),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
        animation: player,
        builder: (context, _) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
                child: Row(
                  children: [
                    Text(
                      'Up next',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text(
                      '${player.queue.length} tracks',
                      style: const TextStyle(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: player.queue.length,
                  onReorderItem: player.reorderQueue,
                  itemBuilder: (context, index) {
                    final track = player.queue[index];
                    final active = track.id == player.current.id;
                    return ListTile(
                      key: ValueKey(track.id),
                      leading: AlbumArtwork(
                        colors: track.colors,
                        artworkId: track.albumArtId,
                        size: 46,
                        radius: 10,
                      ),
                      title: Text(
                        track.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        track.artist,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      trailing: active
                          ? Icon(
                              Icons.graphic_eq_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const Icon(
                              Icons.drag_handle_rounded,
                              color: AppTheme.muted,
                            ),
                      onTap: () => player.playTrack(track),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAudio(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audio output', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_android_rounded),
              title: const Text('This device'),
              subtitle: Text(
                player.current.isLossless
                    ? 'Lossless source • Android-managed output'
                    : 'Standard source • Android-managed output',
              ),
              trailing: Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.volume_down_rounded, color: AppTheme.muted),
                Expanded(
                  child: Slider(
                    value: player.volume,
                    onChanged: player.setVolume,
                  ),
                ),
                const Icon(Icons.volume_up_rounded, color: AppTheme.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 21, color: AppTheme.muted),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
