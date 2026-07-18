import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:flutter_application_1/controllers/phase_three_controller.dart';
import 'package:flutter_application_1/controllers/phase_two_controller.dart';
import 'package:flutter_application_1/controllers/player_controller.dart';
import 'package:flutter_application_1/models/phase_three_models.dart';
import 'package:flutter_application_1/models/track.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/phase_three_services.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/album_artwork.dart';
import 'package:flutter_application_1/widgets/app_background.dart';

const _tracks = <Track>[
  Track(
    id: 'one',
    title: 'One',
    artist: 'Artist',
    album: 'Album',
    duration: Duration(minutes: 3),
    year: 2026,
    genre: 'Test',
    colors: [Color(0xFF123456), Color(0xFF345678)],
  ),
  Track(
    id: 'two',
    title: 'Two',
    artist: 'Artist',
    album: 'Album',
    duration: Duration(minutes: 3),
    year: 2026,
    genre: 'Test',
    colors: [Color(0xFF765432), Color(0xFF543210)],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('background choices serialize and reset without stale custom data', () {
    final controller = PhaseThreeController();

    controller.setDynamicBackground();
    expect(controller.toJson()['backgroundMode'], 'dynamic');

    controller.setThemeBackground(AppBackgroundTheme.sunset);
    expect(controller.toJson(), containsPair('backgroundMode', 'theme'));
    expect(controller.toJson(), containsPair('backgroundTheme', 'sunset'));

    controller.setCustomBackground('/app/auralis_background_photo.jpg');
    expect(controller.backgroundMode, AppBackgroundMode.customImage);
    expect(
      controller.toJson()['customBackgroundPath'],
      '/app/auralis_background_photo.jpg',
    );

    controller.resetBackground();
    expect(controller.backgroundMode, AppBackgroundMode.defaultTheme);
    expect(controller.customBackgroundPath, isNull);
    expect(controller.toJson()['customBackgroundPath'], isNull);
    controller.dispose();
  });

  test('selected background restores from persisted settings', () async {
    final original = PhaseThreeController();
    await original.restore();
    original.setCustomBackground('/app/auralis_background_saved.jpg');
    await original.flushSettings();

    final restored = PhaseThreeController();
    await restored.restore();
    expect(restored.backgroundMode, AppBackgroundMode.customImage);
    expect(restored.customBackgroundPath, '/app/auralis_background_saved.jpg');
    original.dispose();
    restored.dispose();
  });

  testWidgets(
    'dynamic background follows track changes without position churn',
    (tester) async {
      final player = PlayerController(_tracks);
      final controller = PhaseThreeController()..setDynamicBackground();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: AppBackground(
            player: player,
            controller: controller,
            child: const Scaffold(
              backgroundColor: Colors.transparent,
              body: Text('content'),
            ),
          ),
        ),
      );

      var backdrop = tester.widget<AlbumArtworkBackdrop>(
        find.byType(AlbumArtworkBackdrop),
      );
      expect(backdrop.colors, _tracks.first.colors);

      player.next();
      await tester.pump();
      backdrop = tester.widget<AlbumArtworkBackdrop>(
        find.byType(AlbumArtworkBackdrop).last,
      );
      expect(backdrop.colors, _tracks.last.colors);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      player.dispose();
      controller.dispose();
    },
  );

  testWidgets('settings exposes working dynamic and curated background modes', (
    tester,
  ) async {
    final player = PlayerController(_tracks);
    final phaseTwo = PhaseTwoController();
    final phaseThree = PhaseThreeController();
    final services = PhaseThreeServices()..largeLibrary.replace(_tracks);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SettingsScreen(
            player: player,
            phaseTwo: phaseTwo,
            phaseThree: phaseThree,
            services: services,
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Background'));
    await tester.pump();
    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();
    expect(find.text('App background'), findsOneWidget);

    await tester.tap(find.text('Dynamic'));
    await tester.pump();
    expect(phaseThree.backgroundMode, AppBackgroundMode.dynamic);

    await tester.tap(
      find.byKey(const ValueKey('background-theme-choice-midnight')),
    );
    await tester.pump();
    expect(phaseThree.backgroundMode, AppBackgroundMode.theme);
    expect(phaseThree.backgroundTheme, AppBackgroundTheme.midnight);
    expect(find.text('Reset to Default'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    player.dispose();
    phaseTwo.dispose();
    phaseThree.dispose();
    services.dispose();
  });
}
