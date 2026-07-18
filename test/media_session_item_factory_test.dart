import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/track.dart';
import 'package:flutter_application_1/services/media_session_item_factory.dart';

void main() {
  test('publishes complete lock-screen metadata and MediaStore artwork', () {
    const track = Track(
      id: 'device-42',
      title: 'Midnight Signal',
      artist: 'Northline',
      album: 'Blue Hour',
      duration: Duration(minutes: 4, seconds: 12),
      year: 2026,
      genre: 'Electronic',
      colors: [Color(0xFF112233), Color(0xFF445566)],
      sourceUri: 'content://media/external/audio/media/42',
      filePath: '/storage/emulated/0/Music/signal.flac',
      albumArtId: 42,
      trackNumber: 3,
      discNumber: 2,
      replayGainDb: -2.5,
    );

    final item = MediaSessionItemFactory.fromTrack(
      track,
      targetPlatform: TargetPlatform.android,
    );

    expect(item.id, track.id);
    expect(item.title, track.title);
    expect(item.artist, track.artist);
    expect(item.album, track.album);
    expect(item.genre, track.genre);
    expect(item.duration, track.duration);
    expect(
      item.artUri,
      Uri.parse(
        'content://com.example.flutter_application_1.notification_artwork/'
        'track/device-42?mediaId=42&v=1',
      ),
    );
    expect(item.displaySubtitle, track.artist);
    expect(item.displayDescription, track.album);
    expect(item.extras?['artworkTrackId'], track.id);
    expect(item.extras?['trackNumber'], 3);
    expect(item.extras?['discNumber'], 2);
  });

  test('publishes designed Android fallback even when a track has no art', () {
    const track = Track(
      id: 'file-1',
      title: 'Local file',
      artist: 'Artist',
      album: 'Album',
      duration: Duration(minutes: 2),
      year: 2026,
      genre: 'Test',
      colors: [Color(0xFF112233), Color(0xFF445566)],
      filePath: '/music/song.mp3',
      albumArtId: 1,
    );

    final item = MediaSessionItemFactory.fromTrack(
      track,
      targetPlatform: TargetPlatform.android,
    );

    expect(
      item.artUri,
      Uri.parse(
        'content://com.example.flutter_application_1.notification_artwork/'
        'track/file-1?mediaId=1&v=1',
      ),
    );
    expect(item.extras, isNot(contains('loadThumbnailUri')));
  });

  test('publishes the prepared PNG fallback for Darwin media controls', () {
    const track = Track(
      id: 'ios-file-1',
      title: 'Local file',
      artist: 'Artist',
      album: 'Album',
      duration: Duration(minutes: 2),
      year: 2026,
      genre: 'Test',
      colors: [Color(0xFF112233), Color(0xFF445566)],
      filePath: '/music/song.mp3',
    );
    final fallback = Uri.file('/support/auralis_notification_art_v1.png');
    MediaSessionItemFactory.fallbackArtworkUri = fallback;

    final item = MediaSessionItemFactory.fromTrack(
      track,
      targetPlatform: TargetPlatform.iOS,
    );

    expect(item.artUri, fallback);
  });

  test('uses distinct artwork URIs so next track cannot retain stale art', () {
    Track track(String id, int mediaId) => Track(
      id: id,
      title: id,
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 2),
      year: 2026,
      genre: 'Test',
      colors: const [Color(0xFF112233), Color(0xFF445566)],
      sourceUri: 'content://media/external/audio/media/$mediaId',
      albumArtId: mediaId,
    );

    final first = MediaSessionItemFactory.fromTrack(
      track('first', 11),
      targetPlatform: TargetPlatform.android,
    );
    final next = MediaSessionItemFactory.fromTrack(
      track('next', 12),
      targetPlatform: TargetPlatform.android,
    );

    expect(first.artUri, isNot(next.artUri));
    expect(first.extras?['artworkTrackId'], 'first');
    expect(next.extras?['artworkTrackId'], 'next');
  });
}
