import 'package:flutter/foundation.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/track.dart';

/// Builds the metadata consumed by Android's media session and notification.
abstract final class MediaSessionItemFactory {
  static const _androidArtworkAuthority =
      'com.example.flutter_application_1.notification_artwork';

  /// A real PNG copied to app-owned storage during startup. Android uses its
  /// artwork provider instead, while Darwin media controls consume this file
  /// URI directly when no platform-resolved artwork has been registered.
  static Uri? fallbackArtworkUri;

  static final Map<String, Uri> _resolvedArtworkUris = <String, Uri>{};

  static void registerResolvedArtwork(String trackId, Uri artworkUri) {
    _resolvedArtworkUris[trackId] = artworkUri;
  }

  static MediaItem fromTrack(Track track, {TargetPlatform? targetPlatform}) {
    final artworkUri = _artworkUri(
      track,
      targetPlatform: targetPlatform ?? defaultTargetPlatform,
    );
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      genre: track.genre,
      duration: track.duration,
      artUri: artworkUri,
      playable: true,
      displayTitle: track.title,
      displaySubtitle: track.artist,
      displayDescription: track.album,
      extras: <String, dynamic>{
        if (track.filePath != null) 'filePath': track.filePath!,
        if (track.replayGainDb != null) 'replayGainDb': track.replayGainDb!,
        if (track.trackNumber != null) 'trackNumber': track.trackNumber!,
        'discNumber': track.discNumber,
        // The URI is deliberately unique per library track. This prevents
        // native media-session caches from displaying the previous song's art.
        'artworkTrackId': track.id,
      },
    );
  }

  static Uri? _artworkUri(
    Track track, {
    required TargetPlatform targetPlatform,
  }) {
    if (targetPlatform == TargetPlatform.android) {
      return Uri(
        scheme: 'content',
        host: _androidArtworkAuthority,
        pathSegments: <String>['track', track.id],
        queryParameters: <String, String>{
          if (track.albumArtId != null) 'mediaId': track.albumArtId!.toString(),
          'v': '1',
        },
      );
    }
    return _resolvedArtworkUris[track.id] ?? fallbackArtworkUri;
  }
}
