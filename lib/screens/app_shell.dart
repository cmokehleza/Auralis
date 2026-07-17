import 'package:flutter/material.dart';

import '../controllers/phase_two_controller.dart';
import '../controllers/phase_three_controller.dart';
import '../controllers/player_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/phase_three_services.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/album_artwork.dart';
import '../widgets/mini_player.dart';
import '../widgets/motion_icons.dart';
import '../widgets/spectrum_visualizer.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.player,
    required this.phaseTwo,
    required this.phaseThree,
    required this.services,
  });

  final PlayerController player;
  final PhaseTwoController phaseTwo;
  final PhaseThreeController phaseThree;
  final PhaseThreeServices services;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.phaseThree.lastScreenIndex;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      widget.phaseTwo.saveResumePosition(
        widget.player.current.id,
        widget.player.position,
      );
      widget.phaseThree.saveRecoverySession(
        queue: widget.player.queue,
        currentId: widget.player.current.id,
        position: widget.player.position,
        screenIndex: _index,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        player: widget.player,
        phaseTwo: widget.phaseTwo,
        library: widget.services.largeLibrary,
        onOpenLibrary: () => _selectIndex(1),
        onOpenSettings: () => _selectIndex(3),
      ),
      LibraryScreen(
        player: widget.player,
        phaseTwo: widget.phaseTwo,
        phaseThree: widget.phaseThree,
        largeLibrary: widget.services.largeLibrary,
      ),
      SearchScreen(
        player: widget.player,
        phaseTwo: widget.phaseTwo,
        library: widget.services.largeLibrary,
      ),
      SettingsScreen(
        player: widget.player,
        phaseTwo: widget.phaseTwo,
        phaseThree: widget.phaseThree,
        services: widget.services,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 900;
        final simplified = widget.phaseThree.displayMode.name == 'simplified';
        final l10n = AppLocalizations.of(context);
        if (expanded) {
          return Scaffold(
            backgroundColor: AppTheme.ink,
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    backgroundColor: AppTheme.ink,
                    selectedIndex: _index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: _selectIndex,
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text(l10n.text('home')),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music_rounded),
                        label: Text(l10n.text('library')),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.search_rounded),
                        label: Text(l10n.text('search')),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.tune_rounded),
                        label: Text(l10n.text('settings')),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: RepaintBoundary(
                      child: _TabStage(index: _index, children: pages),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 370,
                    child: _NowPlayingSidePanel(player: widget.player),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: RepaintBoundary(
              child: _TabStage(index: _index, children: pages),
            ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: widget.player,
                builder: (context, _) => widget.player.current.isEmpty
                    ? const SizedBox.shrink()
                    : MiniPlayer(
                        player: widget.player,
                        phaseTwo: widget.phaseTwo,
                        phaseThree: widget.phaseThree,
                      ),
              ),
              if (simplified)
                RepaintBoundary(
                  child: NavigationBar(
                    selectedIndex: [0, 1, 3].indexOf(_index).clamp(0, 2),
                    onDestinationSelected: (index) =>
                        _selectIndex([0, 1, 3][index]),
                    destinations: [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: l10n.text('home'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music_rounded),
                        label: l10n.text('library'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.tune_rounded),
                        label: l10n.text('settings'),
                      ),
                    ],
                  ),
                )
              else
                RepaintBoundary(
                  child: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: _selectIndex,
                    destinations: [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: l10n.text('home'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music_rounded),
                        label: l10n.text('library'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.search_rounded),
                        label: l10n.text('search'),
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.tune_rounded),
                        label: l10n.text('settings'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          backgroundColor: AppTheme.ink,
        );
      },
    );
  }

  void _selectIndex(int index) {
    setState(() => _index = index);
    widget.phaseThree.setLastScreen(index);
  }
}

class _NowPlayingSidePanel extends StatelessWidget {
  const _NowPlayingSidePanel({required this.player});
  final PlayerController player;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) {
      final track = player.current;
      if (track.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Scan music in Library to start listening.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NOW PLAYING',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.7,
                color: AppTheme.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            LayoutBuilder(
              builder: (_, constraints) => AlbumArtwork(
                colors: track.colors,
                artworkId: track.albumArtId,
                size: constraints.maxWidth,
                radius: 24,
                transitionKey: track.id,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${track.artist} • ${track.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 14),
            SpectrumVisualizer(player: player, height: 48),
            Slider(
              value: player.position.inMilliseconds.toDouble().clamp(
                0,
                track.duration.inMilliseconds.toDouble(),
              ),
              max: track.duration.inMilliseconds.toDouble(),
              onChanged: (value) =>
                  player.seek(Duration(milliseconds: value.round())),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: player.previous,
                  icon: const Icon(Icons.skip_previous_rounded, size: 34),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: player.togglePlay,
                  icon: AnimatedPlayPauseIcon(isPlaying: player.isPlaying),
                  iconSize: 34,
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: player.next,
                  icon: const Icon(Icons.skip_next_rounded, size: 34),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      );
    },
  );
}

class _TabStage extends StatefulWidget {
  const _TabStage({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_TabStage> createState() => _TabStageState();
}

class _TabStageState extends State<_TabStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.fast,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _TabStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = IndexedStack(index: widget.index, children: widget.children);
    if (AppMotion.reduced(context)) return stack;
    return FadeTransition(
      opacity: Tween<double>(begin: .78, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      ),
      child: stack,
    );
  }
}
