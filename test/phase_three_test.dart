import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/controllers/phase_three_controller.dart';
import 'package:flutter_application_1/controllers/phase_two_controller.dart';
import 'package:flutter_application_1/controllers/player_controller.dart';
import 'package:flutter_application_1/models/advanced_models.dart';
import 'package:flutter_application_1/models/phase_three_models.dart';
import 'package:flutter_application_1/models/track.dart';
import 'package:flutter_application_1/services/cue_sheet_service.dart';
import 'package:flutter_application_1/services/large_library_service.dart';
import 'package:flutter_application_1/services/library_integrity_service.dart';
import 'package:flutter_application_1/services/playlist_collaboration_service.dart';
import 'package:flutter_application_1/services/report_export_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';

Track track(int index, {String? id, Duration? duration}) => Track(
  id: id ?? 'track-$index',
  title: 'Track $index',
  artist: index.isEven ? 'Northline' : 'Other',
  album: 'Album ${index ~/ 10}',
  duration: duration ?? const Duration(minutes: 3),
  year: 2026,
  genre: 'Test',
  colors: const [Color(0xFF112233), Color(0xFF445566)],
  trackNumber: index,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'large library pages and searches without materializing every row',
    () async {
      final service = LargeLibraryService(pageSize: 100)
        ..replace(List.generate(1200, track));
      expect(service.visibleTracks, hasLength(100));
      service.loadNextPage();
      expect(service.visibleTracks, hasLength(200));
      await service.search('Northline');
      expect(service.totalCount, 600);
      expect(service.visibleTracks, hasLength(100));
      service.dispose();
    },
  );

  test(
    'non-mutating search leaves the paged library state unchanged',
    () async {
      final service = LargeLibraryService(pageSize: 2)
        ..replace(List.generate(6, track));
      final before = service.visibleTracks.map((item) => item.id).toList();

      final results = await service.find('Northline');

      expect(results.map((item) => item.id), ['track-0', 'track-2', 'track-4']);
      expect(service.totalCount, 6);
      expect(service.loadedCount, 2);
      expect(service.visibleTracks.map((item) => item.id), before);
      service.dispose();
    },
  );

  test('cue parser creates bounded track segments', () {
    const cue = '''
PERFORMER "Band"
TRACK 01 AUDIO
  TITLE "Intro"
  INDEX 01 00:00:00
TRACK 02 AUDIO
  TITLE "Live Song"
  INDEX 01 03:15:37
''';
    final segments = const CueSheetService().parse(cue);
    expect(segments, hasLength(2));
    expect(segments.first.end, const Duration(milliseconds: 195493));
    expect(segments.last.title, 'Live Song');
  });

  test('integrity repair removes duplicates and invalid durations', () {
    final report = const LibraryIntegrityService().checkAndRepair([
      track(1, id: 'same'),
      track(2, id: 'same'),
      track(3, duration: Duration.zero),
    ]);
    expect(report.duplicateIds, 1);
    expect(report.invalidTracks, 1);
    expect(report.repairedTracks, hasLength(1));
  });

  test('collaborative playlist merge is stable and duplicate-free', () {
    final older = CollaborativePlaylist(
      id: 'mix',
      name: 'Old name',
      updatedAt: DateTime.utc(2026),
      entries: const ['a', 'b'],
    );
    final newer = CollaborativePlaylist(
      id: 'mix',
      name: 'New name',
      updatedAt: DateTime.utc(2026, 2),
      entries: const ['b', 'c'],
    );
    final merged = const PlaylistCollaborationService().merge(older, newer);
    expect(merged.name, 'New name');
    expect(merged.entries, ['a', 'b', 'c']);
  });

  test('recovery track and report round-trip preserve important fields', () {
    final original = track(7).copyWith(discNumber: 2, isCompilation: true);
    final restored = Track.fromSessionJson(original.toSessionJson());
    expect(restored.discNumber, 2);
    expect(restored.isCompilation, isTrue);
    final csv = const ReportExportService().libraryCsv(
      [restored],
      {'track-7': const TrackListeningStat(playCount: 3, listenedMs: 90000)},
    );
    expect(csv, contains('duration_seconds,plays,listened_seconds'));
    expect(csv, contains('"3","90"'));
  });

  test(
    'lightweight recovery cursor supersedes an older session position',
    () async {
      final controller = PhaseThreeController();
      final library = [track(0), track(1)];
      controller.saveRecoverySession(
        queue: library,
        currentId: 'track-0',
        position: const Duration(seconds: 135),
        screenIndex: 1,
      );

      await controller.saveRecoveryPosition(
        'track-0',
        const Duration(seconds: 80),
      );

      expect(controller.recoveryCurrentId, 'track-0');
      expect(controller.recoveryPosition, const Duration(seconds: 80));
      expect(controller.toJson()['recoveryPositionMs'], 80000);
      controller.dispose();
    },
  );

  test('recovery cursor rejects tracks outside the saved queue', () async {
    final controller = PhaseThreeController();
    controller.saveRecoverySession(
      queue: [track(0)],
      currentId: 'track-0',
      position: const Duration(seconds: 42),
      screenIndex: 0,
    );

    await controller.saveRecoveryPosition(
      'not-in-queue',
      const Duration(seconds: 99),
    );

    expect(controller.recoveryCurrentId, 'track-0');
    expect(controller.recoveryPosition, const Duration(seconds: 42));
    controller.dispose();
  });

  test('manual counters and output profiles remain user-controlled', () {
    final controller = PhaseThreeController();
    controller.recordTrackStarted(track(1));
    controller.recordListening('track-1', const Duration(seconds: 2));
    expect(controller.totalPlays, 1);
    expect(controller.totalListeningMs, 2000);
    controller.selectOutput('usb-dac');
    expect(controller.activeOutput.kind, OutputDeviceKind.usbDac);
    controller.dispose();
  });

  test('changing tracks restores normal playback speed', () {
    final library = [track(0), track(1), track(2)];
    final controller = PlayerController(library);
    controller.setSpeed(1.7);

    controller.next();

    expect(controller.current.id, 'track-1');
    expect(controller.speed, 1);
    controller.dispose();
  });

  test('replacing an empty library selects a real track without autoplay', () {
    final library = [track(0), track(1)];
    final controller = PlayerController(const [Track.empty]);

    controller.replaceLibrary(library);

    expect(controller.current.id, 'track-0');
    expect(controller.queue.map((item) => item.id), ['track-0', 'track-1']);
    expect(controller.position, Duration.zero);
    expect(controller.isPlaying, isFalse);
    controller.dispose();
  });

  test('repeat off stops at the queue end instead of wrapping', () {
    final library = [track(0), track(1)];
    final controller = PlayerController(library);
    controller.playTrack(library.last, from: library);

    controller.next();

    expect(controller.current.id, 'track-1');
    expect(controller.isPlaying, isFalse);
    expect(controller.repeatMode, PlaybackRepeatMode.off);
    controller.dispose();
  });

  test('queue reorder uses ReorderableListView destination semantics', () {
    final controller = PlayerController([
      track(0),
      track(1),
      track(2),
      track(3),
    ]);

    controller.reorderQueue(1, 4);
    expect(controller.queue.map((item) => item.id), [
      'track-0',
      'track-2',
      'track-3',
      'track-1',
    ]);

    controller.reorderQueue(3, 1);
    expect(controller.queue.map((item) => item.id), [
      'track-0',
      'track-1',
      'track-2',
      'track-3',
    ]);
    controller.dispose();
  });

  test(
    'queue recovery revision changes structurally, not on position ticks',
    () {
      final library = [track(0), track(1), track(2)];
      final controller = PlayerController(library);
      final initialRevision = controller.queueRevision;

      controller.seek(const Duration(seconds: 12));
      expect(controller.queueRevision, initialRevision);

      controller.addNext(track(2));
      expect(controller.queueRevision, initialRevision + 1);
      controller.dispose();
    },
  );

  test(
    'user playlist CRUD is duplicate-free and survives JSON persistence',
    () {
      final controller = PhaseTwoController();
      final playlistId = controller.createPlaylist('  Road test  ');

      controller.addTracksToPlaylist(playlistId, const [
        'track-1',
        'track-2',
        'track-1',
      ]);
      controller.addTracksToPlaylist(playlistId, const ['track-2', 'track-3']);

      expect(controller.userPlaylists, hasLength(1));
      expect(controller.userPlaylists.single.name, 'Road test');
      expect(controller.userPlaylists.single.trackIds, [
        'track-1',
        'track-2',
        'track-3',
      ]);

      final persisted = jsonDecode(jsonEncode(controller.toJson()));
      final restored = UserPlaylist.fromJson(
        Map<String, dynamic>.from(
          (persisted['playlists'] as List<dynamic>).single as Map,
        ),
      );
      expect(restored.id, playlistId);
      expect(restored.name, 'Road test');
      expect(restored.trackIds, ['track-1', 'track-2', 'track-3']);

      controller.removeTrackFromPlaylist(playlistId, 'track-2');
      expect(controller.userPlaylists.single.trackIds, ['track-1', 'track-3']);
      controller.deletePlaylist(playlistId);
      expect(controller.userPlaylists, isEmpty);
      controller.dispose();
    },
  );

  test('settings switches serialize and the chosen accent themes controls', () {
    final controller = PhaseTwoController();
    const accent = Color(0xFFFF8C72);
    controller.setAccent(accent);
    controller.setBitPerfect(false);
    controller.setGapless(false);
    controller.setThemeMode(ThemeMode.light);
    controller.setHighContrast(true);
    controller.setWatchFolders(false);

    expect(controller.toJson(), containsPair('bitPerfect', false));
    expect(controller.toJson(), containsPair('gapless', false));
    expect(controller.toJson(), containsPair('themeMode', 'light'));
    expect(controller.toJson(), containsPair('highContrast', true));
    expect(controller.toJson(), containsPair('watchFolders', false));

    final theme = AppTheme.dark(accent: accent, highContrast: true);
    expect(theme.colorScheme.primary, accent);
    expect(theme.colorScheme.onSurface, Colors.white);
    expect(
      theme.navigationBarTheme.indicatorColor,
      accent.withValues(alpha: .13),
    );
    final lightTheme = AppTheme.light(accent: accent, highContrast: true);
    expect(lightTheme.brightness, Brightness.light);
    expect(lightTheme.colorScheme.primary, accent);
    expect(lightTheme.colorScheme.onPrimary, AppTheme.ink);
    controller.dispose();
  });

  test(
    'silence skipping is opt-in and playlist rules evaluate real tracks',
    () {
      final controller = PhaseTwoController();
      expect(controller.silenceCalibration, isFalse);
      expect(controller.toJson(), containsPair('version', 2));

      const jazzAfter2010 = [
        PlaylistRule(
          field: RuleField.genre,
          operator: RuleOperator.equals,
          value: 'jazz',
        ),
        PlaylistRule(
          field: RuleField.year,
          operator: RuleOperator.greaterThan,
          value: '2010',
        ),
      ];
      final matching = track(1).copyWith();
      final actual = Track(
        id: matching.id,
        title: matching.title,
        artist: matching.artist,
        album: matching.album,
        duration: matching.duration,
        year: 2024,
        genre: 'Jazz',
        colors: matching.colors,
      );
      expect(jazzAfter2010.every((rule) => rule.matches(actual)), isTrue);
      expect(
        const PlaylistRule(
          field: RuleField.duration,
          operator: RuleOperator.atLeast,
          value: '10',
        ).matches(actual),
        isFalse,
      );
      controller.dispose();
    },
  );

  test('favorites persist through settings backup state', () {
    final settings = PhaseTwoController();
    final player = PlayerController([track(0), track(1)]);
    player.onFavoritesChanged = settings.setFavoriteIds;

    player.toggleFavorite(player.current);

    expect(settings.favoriteIds, {'track-0'});
    expect(settings.toJson()['favorites'], ['track-0']);
    player.dispose();
    settings.dispose();
  });
}
