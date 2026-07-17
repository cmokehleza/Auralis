import 'package:flutter/material.dart';

import 'track.dart';

@immutable
class MusicPlaylist {
  const MusicPlaylist({
    required this.name,
    required this.description,
    required this.tracks,
    required this.colors,
  });

  final String name;
  final String description;
  final List<Track> tracks;
  final List<Color> colors;
}
