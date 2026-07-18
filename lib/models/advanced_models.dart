import 'package:flutter/material.dart';

import 'track.dart';

@immutable
class TrackBookmark {
  const TrackBookmark({
    required this.id,
    required this.trackId,
    required this.label,
    required this.position,
  });

  final String id;
  final String trackId;
  final String label;
  final Duration position;

  Map<String, Object> toJson() => {
    'id': id,
    'trackId': trackId,
    'label': label,
    'positionMs': position.inMilliseconds,
  };

  factory TrackBookmark.fromJson(Map<String, dynamic> json) => TrackBookmark(
    id: json['id'] as String,
    trackId: json['trackId'] as String,
    label: json['label'] as String,
    position: Duration(milliseconds: json['positionMs'] as int),
  );
}

enum SleepTimerMode { off, minutes, endOfTrack, endOfQueue }

enum RuleField { genre, year, rating, artist, duration }

enum RuleOperator { equals, contains, greaterThan, lessThan, atLeast }

@immutable
class UserPlaylist {
  const UserPlaylist({
    required this.id,
    required this.name,
    required this.trackIds,
  });

  final String id;
  final String name;
  final List<String> trackIds;

  UserPlaylist copyWith({String? name, List<String>? trackIds}) => UserPlaylist(
    id: id,
    name: name ?? this.name,
    trackIds: trackIds ?? this.trackIds,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'trackIds': trackIds,
  };

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
    id: json['id'] as String,
    name: json['name'] as String,
    trackIds: (json['trackIds'] as List? ?? const []).cast<String>(),
  );
}

@immutable
class PlaylistRule {
  const PlaylistRule({
    required this.field,
    required this.operator,
    required this.value,
  });

  final RuleField field;
  final RuleOperator operator;
  final String value;

  bool matches(Track track) {
    final actual = switch (field) {
      RuleField.genre => track.genre,
      RuleField.artist => track.artist,
      RuleField.year => track.year.toString(),
      RuleField.rating => track.rating.toString(),
      RuleField.duration => (track.duration.inSeconds / 60).toStringAsFixed(2),
    };
    final expected = value.trim();
    final actualLower = actual.toLowerCase();
    final expectedLower = expected.toLowerCase();
    if (operator == RuleOperator.equals) {
      return actualLower == expectedLower;
    }
    if (operator == RuleOperator.contains) {
      return actualLower.contains(expectedLower);
    }

    final actualNumber = switch (field) {
      RuleField.year => track.year.toDouble(),
      RuleField.rating => track.rating.toDouble(),
      RuleField.duration => track.duration.inSeconds / 60,
      _ => null,
    };
    final expectedNumber = double.tryParse(expected);
    if (actualNumber == null || expectedNumber == null) return false;
    return switch (operator) {
      RuleOperator.greaterThan => actualNumber > expectedNumber,
      RuleOperator.lessThan => actualNumber < expectedNumber,
      RuleOperator.atLeast => actualNumber >= expectedNumber,
      _ => false,
    };
  }

  Map<String, Object> toJson() => {
    'field': field.name,
    'operator': operator.name,
    'value': value,
  };

  factory PlaylistRule.fromJson(Map<String, dynamic> json) => PlaylistRule(
    field: RuleField.values.byName(json['field'] as String),
    operator: RuleOperator.values.byName(json['operator'] as String),
    value: json['value'] as String,
  );
}

@immutable
class DuplicateGroup {
  const DuplicateGroup({
    required this.fingerprint,
    required this.trackIds,
    required this.savedBytes,
  });

  final String fingerprint;
  final List<String> trackIds;
  final int savedBytes;
}
