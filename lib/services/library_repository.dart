import 'package:flutter/material.dart';

import '../models/track.dart';

class LibraryRepository {
  LibraryRepository._();

  static const _coral = [Color(0xFFFF8C72), Color(0xFF8B395E)];
  static const _blue = [Color(0xFF65C8FF), Color(0xFF3155A4)];
  static const _lime = [Color(0xFFB9F66A), Color(0xFF39705A)];
  static const _violet = [Color(0xFFC39BFF), Color(0xFF613B91)];
  static const _gold = [Color(0xFFFFCF70), Color(0xFF9A523F)];
  static const _aqua = [Color(0xFF64E6D4), Color(0xFF2E5A7A)];

  static const demoTracks = <Track>[
    Track(
      id: 'glass-horizon',
      title: 'Glass Horizon',
      artist: 'Mira Sol',
      album: 'Afterlight',
      duration: Duration(minutes: 4, seconds: 12),
      year: 2025,
      genre: 'Alternative',
      colors: _coral,
      isLossless: true,
      rating: 5,
    ),
    Track(
      id: 'open-water',
      title: 'Open Water',
      artist: 'Northline',
      album: 'Tidal Memory',
      duration: Duration(minutes: 3, seconds: 46),
      year: 2024,
      genre: 'Electronic',
      colors: _blue,
      isLossless: true,
      rating: 4,
    ),
    Track(
      id: 'quiet-machines',
      title: 'Quiet Machines',
      artist: 'Harbor Lights',
      album: 'Soft Systems',
      duration: Duration(minutes: 5, seconds: 8),
      year: 2023,
      genre: 'Ambient',
      colors: _lime,
      isLossless: true,
      rating: 5,
    ),
    Track(
      id: 'violet-hour',
      title: 'Violet Hour',
      artist: 'Eloise Park',
      album: 'Night Language',
      duration: Duration(minutes: 3, seconds: 29),
      year: 2025,
      genre: 'Indie Pop',
      colors: _violet,
      rating: 4,
    ),
    Track(
      id: 'static-bloom',
      title: 'Static Bloom',
      artist: 'Juniper Vale',
      album: 'Field Notes',
      duration: Duration(minutes: 4, seconds: 37),
      year: 2022,
      genre: 'Folk',
      colors: _gold,
      rating: 3,
    ),
    Track(
      id: 'distant-rooms',
      title: 'Distant Rooms',
      artist: 'Contour',
      album: 'Interior Weather',
      duration: Duration(minutes: 6, seconds: 2),
      year: 2021,
      genre: 'Jazz',
      colors: _aqua,
      isLossless: true,
      rating: 5,
    ),
    Track(
      id: 'low-tide',
      title: 'Low Tide',
      artist: 'Northline',
      album: 'Tidal Memory',
      duration: Duration(minutes: 4, seconds: 4),
      year: 2024,
      genre: 'Electronic',
      colors: _blue,
      rating: 4,
    ),
    Track(
      id: 'paper-moons',
      title: 'Paper Moons',
      artist: 'Eloise Park',
      album: 'Night Language',
      duration: Duration(minutes: 3, seconds: 54),
      year: 2025,
      genre: 'Indie Pop',
      colors: _violet,
      rating: 4,
    ),
  ];

  static final tracks = <Track>[];

  static void loadDemoLibrary() {
    tracks
      ..clear()
      ..addAll(demoTracks);
  }

  static void replaceWithDeviceTracks(List<Track> deviceTracks) {
    tracks
      ..clear()
      ..addAll(deviceTracks);
  }

  static List<String> get artists =>
      tracks.map((track) => track.artist).toSet().toList()..sort();

  static List<String> get albums =>
      tracks.map((track) => track.album).toSet().toList()..sort();

  static List<Track> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return tracks;
    return tracks.where((track) {
      return track.title.toLowerCase().contains(needle) ||
          track.artist.toLowerCase().contains(needle) ||
          track.album.toLowerCase().contains(needle) ||
          track.genre.toLowerCase().contains(needle);
    }).toList();
  }
}
