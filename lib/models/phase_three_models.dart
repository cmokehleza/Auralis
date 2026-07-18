import 'dart:convert';

import 'track.dart';

enum AudioFocusBehavior { pause, duck, ignore }

enum OutputDeviceKind { phone, wired, bluetooth, car, usbDac, optical, network }

enum AuralisDisplayMode { full, simplified }

enum AppIconTheme { system, light, dark, seasonal }

/// User-controlled wallpaper source for the app's shared visual backdrop.
enum AppBackgroundMode { defaultTheme, dynamic, customImage, theme }

/// Curated backgrounds that remain readable in both light and dark themes.
enum AppBackgroundTheme { aurora, midnight, sunset, graphite }

class OutputProfile {
  const OutputProfile({
    required this.id,
    required this.name,
    required this.kind,
    this.eqPreset = 'Flat',
    this.volume = .8,
    this.delayMs = 0,
    this.monoDownmix = false,
    this.bitPerfectRequested = false,
  });

  final String id;
  final String name;
  final OutputDeviceKind kind;
  final String eqPreset;
  final double volume;
  final int delayMs;
  final bool monoDownmix;
  final bool bitPerfectRequested;

  bool get isDigital =>
      kind == OutputDeviceKind.usbDac || kind == OutputDeviceKind.optical;

  OutputProfile copyWith({
    String? eqPreset,
    double? volume,
    int? delayMs,
    bool? monoDownmix,
    bool? bitPerfectRequested,
  }) => OutputProfile(
    id: id,
    name: name,
    kind: kind,
    eqPreset: eqPreset ?? this.eqPreset,
    volume: volume ?? this.volume,
    delayMs: delayMs ?? this.delayMs,
    monoDownmix: monoDownmix ?? this.monoDownmix,
    bitPerfectRequested: bitPerfectRequested ?? this.bitPerfectRequested,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'eq': eqPreset,
    'volume': volume,
    'delayMs': delayMs,
    'mono': monoDownmix,
    'bitPerfect': bitPerfectRequested,
  };

  factory OutputProfile.fromJson(Map<String, Object?> json) => OutputProfile(
    id: json['id']! as String,
    name: json['name']! as String,
    kind: OutputDeviceKind.values.byName(json['kind'] as String),
    eqPreset: json['eq'] as String? ?? 'Flat',
    volume: (json['volume'] as num?)?.toDouble() ?? .8,
    delayMs: (json['delayMs'] as num?)?.toInt() ?? 0,
    monoDownmix: json['mono'] as bool? ?? false,
    bitPerfectRequested: json['bitPerfect'] as bool? ?? false,
  );
}

class LinkedTrackGroup {
  const LinkedTrackGroup({
    required this.id,
    required this.label,
    required this.trackIds,
    required this.preferredTrackId,
  });

  final String id;
  final String label;
  final List<String> trackIds;
  final String preferredTrackId;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'trackIds': trackIds,
    'preferred': preferredTrackId,
  };

  factory LinkedTrackGroup.fromJson(Map<String, Object?> json) =>
      LinkedTrackGroup(
        id: json['id']! as String,
        label: json['label']! as String,
        trackIds: (json['trackIds'] as List).cast<String>(),
        preferredTrackId: json['preferred']! as String,
      );
}

class TrackListeningStat {
  const TrackListeningStat({this.playCount = 0, this.listenedMs = 0});

  final int playCount;
  final int listenedMs;

  TrackListeningStat add({int plays = 0, int milliseconds = 0}) =>
      TrackListeningStat(
        playCount: playCount + plays,
        listenedMs: listenedMs + milliseconds,
      );

  Map<String, int> toJson() => {'plays': playCount, 'ms': listenedMs};

  factory TrackListeningStat.fromJson(Map<String, Object?> json) =>
      TrackListeningStat(
        playCount: (json['plays'] as num?)?.toInt() ?? 0,
        listenedMs: (json['ms'] as num?)?.toInt() ?? 0,
      );
}

class CueSegment {
  const CueSegment({
    required this.number,
    required this.title,
    required this.performer,
    required this.start,
    this.end,
  });

  final int number;
  final String title;
  final String performer;
  final Duration start;
  final Duration? end;

  Track applyTo(Track source) => source.copyWith(
    id: '${source.id}-cue-$number',
    title: title,
    artist: performer,
    trackNumber: number,
    cueStart: start,
    cueEnd: end,
    duration: (end ?? source.duration) - start,
  );
}

class LibraryIntegrityReport {
  const LibraryIntegrityReport({
    required this.duplicateIds,
    required this.invalidTracks,
    required this.repairedTracks,
  });

  final int duplicateIds;
  final int invalidTracks;
  final List<Track> repairedTracks;
  bool get healthy => duplicateIds == 0 && invalidTracks == 0;
}

class RemotePeer {
  const RemotePeer({
    required this.name,
    required this.host,
    required this.port,
  });

  final String name;
  final String host;
  final int port;
  Uri get baseUri => Uri(scheme: 'http', host: host, port: port);
}

class CollaborativePlaylist {
  const CollaborativePlaylist({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.entries,
  });

  final String id;
  final String name;
  final DateTime updatedAt;
  final List<String> entries;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'id': id,
    'name': name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'entries': entries,
  };

  String encode() => jsonEncode(toJson());

  factory CollaborativePlaylist.decode(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return CollaborativePlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      entries: (json['entries'] as List).cast<String>(),
    );
  }
}
