import 'dart:math';

import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/track.dart';

class DeviceLibraryResult {
  const DeviceLibraryResult({
    required this.tracks,
    required this.permissionGranted,
    this.error,
  });

  final List<Track> tracks;
  final bool permissionGranted;
  final String? error;
}

class DeviceLibraryService {
  DeviceLibraryService({OnAudioQuery? query})
    : _query = query ?? OnAudioQuery();

  final OnAudioQuery _query;

  Future<DeviceLibraryResult> scan({
    bool retryPermission = false,
    bool requestPermission = true,
  }) async {
    var granted = false;
    try {
      granted = requestPermission
          ? await _query.checkAndRequest(retryRequest: retryPermission)
          : await _query.permissionsStatus();
      if (!granted) {
        return const DeviceLibraryResult(tracks: [], permissionGranted: false);
      }
      final songs = await _query.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      final tracks = songs
          .where((song) => (song.duration ?? 0) > 1000 && song.isMusic != false)
          .map(_mapSong)
          .toList(growable: false);
      return DeviceLibraryResult(tracks: tracks, permissionGranted: true);
    } catch (error) {
      return DeviceLibraryResult(
        tracks: const [],
        permissionGranted: granted,
        error: error.toString(),
      );
    }
  }

  Track _mapSong(SongModel song) {
    final hue = (song.id * 47) % 360;
    final first = HSVColor.fromAHSV(1, hue.toDouble(), .48, .94).toColor();
    final second = HSVColor.fromAHSV(1, (hue + 48) % 360, .68, .42).toColor();
    final extension = song.fileExtension.toLowerCase();
    final encodedTrack = song.track ?? 0;
    final discNumber = encodedTrack >= 1000 ? encodedTrack ~/ 1000 : 1;
    final trackNumber = encodedTrack >= 1000
        ? encodedTrack.remainder(1000)
        : song.track;
    return Track(
      id: 'device-${song.id}',
      title: song.title.trim().isEmpty ? song.displayNameWOExt : song.title,
      artist: _clean(song.artist, 'Unknown artist'),
      album: _clean(song.album, 'Unknown album'),
      duration: Duration(milliseconds: max(0, song.duration ?? 0)),
      year: 0,
      genre: _clean(song.genre, 'Unknown genre'),
      colors: [first, second],
      isLossless: const {'flac', 'wav', 'alac', 'aiff'}.contains(extension),
      sourceUri: song.uri,
      filePath: song.data,
      albumArtId: song.id,
      trackNumber: trackNumber,
      discNumber: discNumber,
      isCompilation: _clean(song.artist, '').toLowerCase() == 'various artists',
    );
  }

  String _clean(String? value, String fallback) {
    if (value == null || value.trim().isEmpty || value == '<unknown>') {
      return fallback;
    }
    return value.trim();
  }
}
