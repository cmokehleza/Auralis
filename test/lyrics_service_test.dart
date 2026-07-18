import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/track.dart';
import 'package:flutter_application_1/services/lyrics_service.dart';
import 'package:flutter_application_1/widgets/synced_lyrics_view.dart';

Track _track(
  String id, {
  String? filePath,
  List<String> syncedLyrics = const [],
}) => Track(
  id: id,
  title: 'Song $id',
  artist: 'Artist',
  album: 'Album',
  duration: const Duration(minutes: 4),
  year: 2026,
  genre: 'Test',
  colors: const [Color(0xFF112233), Color(0xFF445566)],
  filePath: filePath,
  syncedLyrics: syncedLyrics,
);

class _ControlledLyricsService extends LyricsService {
  final Map<String, Completer<LyricsDocument?>> requests = {};

  @override
  Future<LyricsDocument?> loadFor(Track track) =>
      requests.putIfAbsent(track.id, Completer<LyricsDocument?>.new).future;
}

List<int> _bigEndian32(int value) => [
  (value >> 24) & 0xFF,
  (value >> 16) & 0xFF,
  (value >> 8) & 0xFF,
  value & 0xFF,
];

List<int> _synchsafe32(int value) => [
  (value >> 21) & 0x7F,
  (value >> 14) & 0x7F,
  (value >> 7) & 0x7F,
  value & 0x7F,
];

List<int> _id3v23Frame(String id, List<int> payload) => [
  ...ascii.encode(id),
  ..._bigEndian32(payload.length),
  0,
  0,
  ...payload,
];

List<int> _id3v23File(List<List<int>> frames) {
  final payload = frames.expand((frame) => frame).toList();
  return [
    ...ascii.encode('ID3'),
    3,
    0,
    0,
    ..._synchsafe32(payload.length),
    ...payload,
    0,
    0,
    0,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'LRC parser handles offsets, multiple timestamps, and long durations',
    () {
      const raw = '''
[ar:Example]
[offset:+250]
[00:01.5][00:02.50]First <00:02.60>line
[01:00:03.125]Long mix line
''';
      final document = const LyricsService().parse(raw);

      expect(document, isNotNull);
      expect(document!.isSynced, isTrue);
      expect(document.lines, hasLength(3));
      expect(document.lines[0].timestamp, const Duration(milliseconds: 1750));
      expect(document.lines[0].text, 'First line');
      expect(document.lines[1].timestamp, const Duration(milliseconds: 2750));
      expect(
        document.lines[2].timestamp,
        const Duration(hours: 1, seconds: 3, milliseconds: 375),
      );
      expect(document.activeIndexAt(const Duration(seconds: 2)), 0);
      expect(document.activeIndexAt(const Duration(seconds: 3)), 1);
    },
  );

  test('matching sidecar LRC is loaded from the audio directory', () async {
    final directory = await Directory.systemTemp.createTemp('auralis-lyrics-');
    addTearDown(() => directory.delete(recursive: true));
    final audio = File(
      '${directory.path}${Platform.pathSeparator}recording.mp3',
    );
    final sidecar = File(
      '${directory.path}${Platform.pathSeparator}recording.LRC',
    );
    final embeddedUslt = <int>[
      3,
      ...ascii.encode('eng'),
      0,
      ...utf8.encode('Unsynchronized embedded lyric'),
    ];
    await audio.writeAsBytes(_id3v23File([_id3v23Frame('USLT', embeddedUslt)]));
    await sidecar.writeAsString('[00:01.00]Sidecar lyric');

    final document = await const LyricsService().loadFor(
      _track('sidecar', filePath: audio.path),
    );

    expect(document, isNotNull);
    expect(document!.source, LyricsSource.sidecar);
    expect(document.isSynced, isTrue);
    expect(document.lines.single.text, 'Sidecar lyric');
  });

  test(
    'attached lyrics take priority and retain synchronized timestamps',
    () async {
      final document = await const LyricsService().loadFor(
        _track('embedded', syncedLyrics: const ['[00:02.25]Embedded lyric']),
      );

      expect(document, isNotNull);
      expect(document!.source, LyricsSource.embedded);
      expect(
        document.lines.single.timestamp,
        const Duration(milliseconds: 2250),
      );
    },
  );

  test('ID3v2 USLT embedded tag is extracted from a readable file', () async {
    final directory = await Directory.systemTemp.createTemp('auralis-uslt-');
    addTearDown(() => directory.delete(recursive: true));
    final audio = File('${directory.path}${Platform.pathSeparator}tagged.mp3');
    final uslt = <int>[
      3,
      ...ascii.encode('eng'),
      0,
      ...utf8.encode('Embedded first line\nEmbedded second line'),
    ];
    await audio.writeAsBytes(_id3v23File([_id3v23Frame('USLT', uslt)]));

    final document = await const LyricsService().loadFor(
      _track('uslt', filePath: audio.path),
    );

    expect(document, isNotNull);
    expect(document!.source, LyricsSource.embedded);
    expect(document.isSynced, isFalse);
    expect(document.lines.map((line) => line.text), [
      'Embedded first line',
      'Embedded second line',
    ]);
  });

  test('ID3v2 SYLT embedded tag supplies synchronized timestamps', () async {
    final directory = await Directory.systemTemp.createTemp('auralis-sylt-');
    addTearDown(() => directory.delete(recursive: true));
    final audio = File('${directory.path}${Platform.pathSeparator}tagged.mp3');
    final sylt = <int>[
      3,
      ...ascii.encode('eng'),
      2,
      1,
      0,
      ...utf8.encode('First embedded line'),
      0,
      ..._bigEndian32(1000),
      ...utf8.encode('Second embedded line'),
      0,
      ..._bigEndian32(5000),
    ];
    await audio.writeAsBytes(_id3v23File([_id3v23Frame('SYLT', sylt)]));

    final document = await const LyricsService().loadFor(
      _track('sylt', filePath: audio.path),
    );

    expect(document, isNotNull);
    expect(document!.isSynced, isTrue);
    expect(document.lines, hasLength(2));
    expect(document.activeIndexAt(const Duration(seconds: 4)), 0);
    expect(document.activeIndexAt(const Duration(seconds: 6)), 1);
    expect(document.lines.last.text, 'Second embedded line');
  });

  testWidgets('track changes clear old lyrics and reject stale loads', (
    tester,
  ) async {
    final service = _ControlledLyricsService();
    final first = _track('first');
    final second = _track('second');

    Widget view(Track track) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 220,
          child: SyncedLyricsView(
            track: track,
            position: Duration.zero,
            lyricsService: service,
          ),
        ),
      ),
    );

    await tester.pumpWidget(view(first));
    service.requests['first']!.complete(
      const LyricsDocument(
        source: LyricsSource.embedded,
        lines: [LyricLine(timestamp: Duration.zero, text: 'First track lyric')],
      ),
    );
    await tester.pump();
    expect(find.text('First track lyric'), findsOneWidget);

    await tester.pumpWidget(view(second));
    expect(find.text('First track lyric'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.requests['second']!.complete(null);
    await tester.pump();
    expect(find.text('Lyrics not found for this song'), findsOneWidget);
    expect(find.text('First track lyric'), findsNothing);
  });

  testWidgets('synced view advances the current lyric with playback position', (
    tester,
  ) async {
    final track = _track(
      'sync',
      syncedLyrics: const ['[00:01.00]First line', '[00:05.00]Second line'],
    );
    final semantics = tester.ensureSemantics();

    Widget view(Duration position) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 220,
          child: SyncedLyricsView(track: track, position: position),
        ),
      ),
    );

    await tester.pumpWidget(view(const Duration(seconds: 2)));
    await tester.pump();
    expect(find.bySemanticsLabel('Current lyric: First line'), findsOneWidget);

    await tester.pumpWidget(view(const Duration(seconds: 6)));
    await tester.pump();
    expect(find.bySemanticsLabel('Current lyric: Second line'), findsOneWidget);
    semantics.dispose();
  });
}
