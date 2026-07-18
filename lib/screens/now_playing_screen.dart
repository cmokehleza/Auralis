import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/phase_three_controller.dart';
import '../controllers/player_controller.dart';
import '../models/advanced_models.dart';
import '../models/track.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/album_artwork.dart';
import '../widgets/app_background.dart';
import '../widgets/motion_icons.dart';
import '../widgets/playlist_picker.dart';
import '../widgets/spectrum_visualizer.dart';
import '../widgets/synced_lyrics_view.dart';

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
    return Theme(
      data: AppTheme.dark(
        accent: phaseTwo.accent,
        highContrast: phaseTwo.highContrast,
      ),
      child: _ValueSelector<Track>(
        listenable: player,
        select: () => player.current,
        builder: (context, track) {
          return AppBackground(
            player: player,
            controller: phaseThree,
            baseColor: AppTheme.ink,
            defaultLayer: RepaintBoundary(
              child: _Atmosphere(colors: track.colors),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                fit: StackFit.expand,
                children: [
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
                            onArtLongPress: () =>
                                _showQuickActions(context, track),
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
                                  onMore: () =>
                                      _showQuickActions(context, track),
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
                                _ValueSelector<bool>(
                                  listenable: player,
                                  select: () => player.isPlaying,
                                  builder: (context, _) =>
                                      SpectrumVisualizer(player: player),
                                ),
                                _InlineLyrics(
                                  player: player,
                                  phaseThree: phaseThree,
                                  track: track,
                                  topSpacing: 12,
                                ),
                                SizedBox(height: compact ? 14 : 24),
                                _Progress(player: player),
                                SizedBox(height: compact ? 8 : 16),
                                _Transport(player: player),
                                const SizedBox(height: 8),
                                _PracticeTools(
                                  player: player,
                                  phaseTwo: phaseTwo,
                                ),
                                SizedBox(height: compact ? 10 : 18),
                                _BottomActions(
                                  player: player,
                                  phaseThree: phaseThree,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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

/// Rebuilds only when the selected value changes, instead of on every
/// notification emitted by a broad controller.
class _ValueSelector<T> extends StatefulWidget {
  const _ValueSelector({
    required this.listenable,
    required this.select,
    required this.builder,
  });

  final Listenable listenable;
  final T Function() select;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<_ValueSelector<T>> createState() => _ValueSelectorState<T>();
}

class _ValueSelectorState<T> extends State<_ValueSelector<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.select();
    widget.listenable.addListener(_handleChange);
  }

  @override
  void didUpdateWidget(covariant _ValueSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_handleChange);
      widget.listenable.addListener(_handleChange);
    }
    // The selector can close over a new track after the shell changes.
    _value = widget.select();
  }

  void _handleChange() {
    final next = widget.select();
    if (next == _value || !mounted) return;
    setState(() => _value = next);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_handleChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

class _InlineLyrics extends StatelessWidget {
  const _InlineLyrics({
    required this.player,
    required this.phaseThree,
    required this.track,
    this.topSpacing = 0,
  });

  final PlayerController player;
  final PhaseThreeController phaseThree;
  final Track track;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return _ValueSelector<(bool, double, bool)>(
      listenable: phaseThree,
      select: () => (
        phaseThree.showLyrics,
        phaseThree.lyricsFontScale,
        phaseThree.highContrastLyrics,
      ),
      builder: (context, lyricsSettings) {
        if (!lyricsSettings.$1) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: topSpacing),
          child: _ValueSelector<Duration>(
            listenable: player,
            select: () => player.position,
            builder: (context, position) => SyncedLyricsView(
              track: track,
              position: position,
              fontScale: lyricsSettings.$2,
              highContrast: lyricsSettings.$3,
            ),
          ),
        );
      },
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
        _TopBar(onMore: onArtLongPress),
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
                      _ValueSelector<bool>(
                        listenable: player,
                        select: () => player.isPlaying,
                        builder: (context, _) =>
                            SpectrumVisualizer(player: player, height: 46),
                      ),
                      _InlineLyrics(
                        player: player,
                        phaseThree: phaseThree,
                        track: track,
                      ),
                      const SizedBox(height: 10),
                      _Progress(player: player),
                      const SizedBox(height: 4),
                      _Transport(player: player),
                      const SizedBox(height: 8),
                      _PracticeTools(player: player, phaseTwo: phaseTwo),
                      const SizedBox(height: 10),
                      _BottomActions(player: player, phaseThree: phaseThree),
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

class _Atmosphere extends StatelessWidget {
  const _Atmosphere({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-.55, -.92),
                radius: 1.08,
                colors: [
                  colors.first.withValues(alpha: .4),
                  colors.last.withValues(alpha: .16),
                  Colors.transparent,
                ],
                stops: const [0, .46, 1],
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
  const _TopBar({required this.onMore});

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
        _ValueSelector<bool>(
          listenable: player,
          select: () => player.isFavorite(track),
          builder: (context, isFavorite) => IconButton(
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () => player.toggleFavorite(track),
            icon: AnimatedFavoriteIcon(
              selected: isFavorite,
              selectedColor: Theme.of(context).colorScheme.primary,
            ),
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
    return _ValueSelector<(Duration, Duration)>(
      listenable: player,
      select: () => (player.position, player.current.duration),
      builder: (context, timeline) {
        final position = timeline.$1;
        final duration = timeline.$2;
        final durationMs = duration.inMilliseconds;
        final max = durationMs <= 0 ? 1.0 : durationMs.toDouble();
        final value = position.inMilliseconds
            .clamp(0, durationMs <= 0 ? 1 : durationMs)
            .toDouble();
        final remaining = position >= duration
            ? Duration.zero
            : duration - position;
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
                    formatDuration(position),
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                  Text(
                    '-${formatDuration(remaining)}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    return _ValueSelector<(bool, bool, PlaybackRepeatMode)>(
      listenable: player,
      select: () => (player.shuffle, player.isPlaying, player.repeatMode),
      builder: (context, transport) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Shuffle',
            onPressed: player.toggleShuffle,
            icon: Icon(
              Icons.shuffle_rounded,
              color: transport.$1
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
              child: AnimatedPlayPauseIcon(isPlaying: transport.$2, size: 38),
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
              transport.$3 == PlaybackRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: transport.$3 == PlaybackRepeatMode.off
                  ? AppTheme.muted
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeTools extends StatelessWidget {
  const _PracticeTools({required this.player, required this.phaseTwo});

  final PlayerController player;
  final PhaseTwoController phaseTwo;

  @override
  Widget build(BuildContext context) {
    return _ValueSelector<(Duration?, Duration?)>(
      listenable: player,
      select: () => (player.loopA, player.loopB),
      builder: (context, loop) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.looks_one_outlined, size: 17),
            label: Text(loop.$1 == null ? 'Set A' : formatDuration(loop.$1!)),
            onPressed: player.markLoopA,
          ),
          ActionChip(
            avatar: const Icon(Icons.looks_two_outlined, size: 17),
            label: Text(loop.$2 == null ? 'Set B' : formatDuration(loop.$2!)),
            onPressed: loop.$1 == null ? null : player.markLoopB,
          ),
          if (loop.$1 != null)
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
      ),
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
  const _BottomActions({required this.player, required this.phaseThree});

  final PlayerController player;
  final PhaseThreeController phaseThree;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _ValueSelector<double>(
          listenable: player,
          select: () => player.speed,
          builder: (context, speed) => _Action(
            icon: Icons.speed_rounded,
            label: '${speed.toStringAsFixed(1)}×',
            onTap: () => _showSpeed(context),
          ),
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
      builder: (context) => _ValueSelector<Track>(
        listenable: player,
        select: () => player.current,
        builder: (context, track) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lyrics', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _ValueSelector<(double, bool)>(
                    listenable: phaseThree,
                    select: () => (
                      phaseThree.lyricsFontScale,
                      phaseThree.highContrastLyrics,
                    ),
                    builder: (context, lyricsSettings) =>
                        _ValueSelector<Duration>(
                          listenable: player,
                          select: () => player.position,
                          builder: (context, position) => SyncedLyricsView(
                            track: track,
                            position: position,
                            fontScale: lyricsSettings.$1,
                            highContrast: lyricsSettings.$2,
                            compact: false,
                          ),
                        ),
                  ),
                ),
              ],
            ),
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
      builder: (context) => _ValueSelector<(String, int, int)>(
        listenable: player,
        select: () {
          final queue = player.queue;
          return (
            player.current.id,
            queue.length,
            Object.hashAll(
              queue.map(
                (track) => Object.hash(
                  track.id,
                  track.title,
                  track.artist,
                  track.albumArtId,
                ),
              ),
            ),
          );
        },
        builder: (context, queueState) {
          final queue = player.queue;
          final currentId = queueState.$1;
          return SizedBox(
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
                        '${queue.length} tracks',
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: queue.length,
                    onReorderItem: player.reorderQueue,
                    itemBuilder: (context, index) {
                      final track = queue[index];
                      final active = track.id == currentId;
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
          );
        },
      ),
    );
  }

  void _showAudio(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      showDragHandle: true,
      builder: (context) => _ValueSelector<(double, String, String, bool)>(
        listenable: player,
        select: () => (
          player.volume,
          player.outputProfileName,
          player.current.id,
          player.current.isLossless,
        ),
        builder: (context, audioState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audio output',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_android_rounded),
                title: Text(audioState.$2),
                subtitle: Text(
                  audioState.$4
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
                      value: audioState.$1,
                      onChanged: player.setVolume,
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, color: AppTheme.muted),
                ],
              ),
            ],
          ),
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
