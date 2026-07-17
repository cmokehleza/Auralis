import 'package:flutter/material.dart';

@immutable
class Track {
  static const empty = Track(
    id: '__auralis_empty__',
    title: 'No music selected',
    artist: '',
    album: '',
    duration: Duration(seconds: 1),
    year: 0,
    genre: '',
    colors: [Color(0xFF1A1E24), Color(0xFF111419)],
  );

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.year,
    required this.genre,
    required this.colors,
    this.isLossless = false,
    this.rating = 0,
    this.sourceUri,
    this.filePath,
    this.albumArtId,
    this.trackNumber,
    this.discNumber = 1,
    this.albumArtist,
    this.isCompilation = false,
    this.replayGainDb,
    this.cueStart,
    this.cueEnd,
    this.syncedLyrics = const [],
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final int year;
  final String genre;
  final List<Color> colors;
  final bool isLossless;
  final int rating;
  final String? sourceUri;
  final String? filePath;
  final int? albumArtId;
  final int? trackNumber;
  final int discNumber;
  final String? albumArtist;
  final bool isCompilation;
  final double? replayGainDb;
  final Duration? cueStart;
  final Duration? cueEnd;
  final List<String> syncedLyrics;

  bool get isDeviceTrack => sourceUri != null || filePath != null;
  bool get isEmpty => id == empty.id;

  Track copyWith({
    int? rating,
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    int? trackNumber,
    int? discNumber,
    String? albumArtist,
    bool? isCompilation,
    Duration? cueStart,
    Duration? cueEnd,
    List<String>? syncedLyrics,
  }) => Track(
    id: id ?? this.id,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    duration: duration ?? this.duration,
    year: year,
    genre: genre,
    colors: colors,
    isLossless: isLossless,
    rating: rating ?? this.rating,
    sourceUri: sourceUri,
    filePath: filePath,
    albumArtId: albumArtId,
    trackNumber: trackNumber ?? this.trackNumber,
    discNumber: discNumber ?? this.discNumber,
    albumArtist: albumArtist ?? this.albumArtist,
    isCompilation: isCompilation ?? this.isCompilation,
    replayGainDb: replayGainDb,
    cueStart: cueStart ?? this.cueStart,
    cueEnd: cueEnd ?? this.cueEnd,
    syncedLyrics: syncedLyrics ?? this.syncedLyrics,
  );

  Map<String, Object?> toSessionJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': duration.inMilliseconds,
    'year': year,
    'genre': genre,
    'colors': colors.map((color) => color.toARGB32()).toList(),
    'lossless': isLossless,
    'rating': rating,
    'sourceUri': sourceUri,
    'filePath': filePath,
    'albumArtId': albumArtId,
    'trackNumber': trackNumber,
    'discNumber': discNumber,
    'albumArtist': albumArtist,
    'compilation': isCompilation,
    'replayGainDb': replayGainDb,
    'cueStartMs': cueStart?.inMilliseconds,
    'cueEndMs': cueEnd?.inMilliseconds,
    'syncedLyrics': syncedLyrics,
  };

  factory Track.fromSessionJson(Map<String, Object?> json) {
    final rawColors = (json['colors'] as List?)?.cast<num>() ?? const [];
    return Track(
      id: json['id']! as String,
      title: json['title']! as String,
      artist: json['artist']! as String,
      album: json['album']! as String,
      duration: Duration(milliseconds: (json['durationMs'] as num).toInt()),
      year: (json['year'] as num?)?.toInt() ?? 0,
      genre: json['genre'] as String? ?? 'Unknown genre',
      colors: rawColors.isEmpty
          ? const [Color(0xFF65C8FF), Color(0xFF3155A4)]
          : rawColors.map((value) => Color(value.toInt())).toList(),
      isLossless: json['lossless'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      sourceUri: json['sourceUri'] as String?,
      filePath: json['filePath'] as String?,
      albumArtId: (json['albumArtId'] as num?)?.toInt(),
      trackNumber: (json['trackNumber'] as num?)?.toInt(),
      discNumber: (json['discNumber'] as num?)?.toInt() ?? 1,
      albumArtist: json['albumArtist'] as String?,
      isCompilation: json['compilation'] as bool? ?? false,
      replayGainDb: (json['replayGainDb'] as num?)?.toDouble(),
      cueStart: json['cueStartMs'] == null
          ? null
          : Duration(milliseconds: (json['cueStartMs'] as num).toInt()),
      cueEnd: json['cueEndMs'] == null
          ? null
          : Duration(milliseconds: (json['cueEndMs'] as num).toInt()),
      syncedLyrics: (json['syncedLyrics'] as List?)?.cast<String>() ?? const [],
    );
  }
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
