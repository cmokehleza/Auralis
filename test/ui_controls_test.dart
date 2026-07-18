import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/controllers/phase_three_controller.dart';
import 'package:flutter_application_1/controllers/phase_two_controller.dart';
import 'package:flutter_application_1/controllers/player_controller.dart';
import 'package:flutter_application_1/models/track.dart';
import 'package:flutter_application_1/services/library_repository.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/album_artwork.dart';
import 'package:flutter_application_1/widgets/mini_player.dart';
import 'package:flutter_application_1/widgets/spectrum_visualizer.dart';
import 'package:flutter_application_1/widgets/track_tile.dart';

void main() {
  late PlayerController player;
  late PhaseTwoController phaseTwo;
  late PhaseThreeController phaseThree;

  setUp(() {
    LibraryRepository.loadDemoLibrary();
    player = PlayerController(LibraryRepository.tracks);
    phaseTwo = PhaseTwoController();
    phaseThree = PhaseThreeController();
  });

  tearDown(() {
    player.dispose();
    phaseTwo.dispose();
    phaseThree.dispose();
  });

  Future<void> disposePlayingPlayer(WidgetTester tester) async {
    player.dispose();
    player = PlayerController(const [Track.empty]);
    await tester.pumpWidget(const SizedBox.shrink());
  }

  Widget miniPlayerHarness({bool reduceMotion = false}) => MaterialApp(
    theme: AppTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        bottomNavigationBar: MiniPlayer(
          player: player,
          phaseTwo: phaseTwo,
          phaseThree: phaseThree,
        ),
      ),
    ),
  );

  testWidgets('mini player reflects the next track immediately', (
    tester,
  ) async {
    final tracks = LibraryRepository.tracks;
    player.playTrack(tracks.first, from: tracks);
    await tester.pumpWidget(miniPlayerHarness(reduceMotion: true));

    expect(find.text(tracks.first.title), findsOneWidget);
    await tester.tap(find.byTooltip('Next track'));
    await tester.pump();

    expect(find.text(tracks[1].title), findsOneWidget);
    expect(find.text(tracks.first.title), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);
    await disposePlayingPlayer(tester);
  });

  testWidgets('track tile updates only relevant playback state', (
    tester,
  ) async {
    final track = LibraryRepository.tracks.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: TrackTile(
            track: track,
            player: player,
            onTap: player.togglePlay,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.pause_circle_outline_rounded), findsOneWidget);
    await tester.tap(find.text(track.title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.byType(SpectrumVisualizer), findsOneWidget);
    expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
    await disposePlayingPlayer(tester);
  });

  testWidgets('mini player hides cleanly when no track exists', (tester) async {
    player.dispose();
    player = PlayerController(const [Track.empty]);
    await tester.pumpWidget(miniPlayerHarness());

    expect(find.byKey(const ValueKey('mini-player-empty')), findsOneWidget);
    expect(find.text('Unknown title'), findsNothing);
  });

  testWidgets(
    'missing MediaStore artwork keeps a full-size designed fallback',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlbumArtwork(
              colors: const [Color(0xFF2D8CFF), Color(0xFF172554)],
              artworkId: 999999,
              size: 72,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fallback = find.byKey(const ValueKey('fallback-999999'));
      expect(fallback, findsOneWidget);
      expect(tester.getSize(fallback), const Size.square(72));
    },
  );
}
