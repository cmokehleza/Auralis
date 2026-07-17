import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/track.dart';

class HomeWidgetService {
  static const _channel = MethodChannel('com.auralis.player/widget');
  static String? _artworkTrackId;

  static void clearArtworkCache() => _artworkTrackId = null;

  static Future<void> update({
    required Track track,
    required Duration position,
    required bool playing,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      Uint8List? artwork;
      final needsArtwork = _artworkTrackId != track.id;
      if (needsArtwork && track.albumArtId != null) {
        artwork = await OnAudioQuery().queryArtwork(
          track.albumArtId!,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: 256,
          quality: 82,
        );
      }
      _artworkTrackId = track.id;
      final payload = <String, Object?>{
        'title': track.title,
        'artist': track.artist,
        'positionMs': position.inMilliseconds,
        'durationMs': track.duration.inMilliseconds,
        'playing': playing,
      };
      if (needsArtwork) payload['artwork'] = artwork;
      await _channel.invokeMethod<void>('update', payload);
    } on PlatformException {
      // Playback remains available if a launcher does not support widgets.
    } on MissingPluginException {
      // Widget tests run without an Android host.
    }
  }
}
