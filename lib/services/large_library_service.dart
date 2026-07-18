import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../models/track.dart';
import 'device_library_service.dart';

class LargeLibraryService extends ChangeNotifier {
  LargeLibraryService({this.pageSize = 250});

  final int pageSize;
  final List<Track> _tracks = [];
  List<int> _filteredIndices = [];
  int _loadedPages = 1;
  bool _scanning = false;
  int _generation = 0;

  bool get scanning => _scanning;
  int get totalCount => _filteredIndices.length;
  int get loadedCount => (_loadedPages * pageSize).clamp(0, totalCount);
  bool get hasMore => loadedCount < totalCount;
  List<Track> get visibleTracks => List.unmodifiable(
    _filteredIndices.take(loadedCount).map((index) => _tracks[index]),
  );
  List<Track> get allTracks => List.unmodifiable(_tracks);

  void replace(List<Track> tracks) {
    _tracks
      ..clear()
      ..addAll(tracks);
    _filteredIndices = List<int>.generate(_tracks.length, (index) => index);
    _loadedPages = 1;
    notifyListeners();
  }

  void loadNextPage() {
    if (!hasMore) return;
    _loadedPages++;
    notifyListeners();
  }

  Future<void> search(String query) async {
    final generation = ++_generation;
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      _filteredIndices = List<int>.generate(_tracks.length, (index) => index);
    } else {
      final snapshots = _tracks
          .map(
            (track) =>
                '${track.title}\u0000${track.artist}\u0000${track.album}\u0000${track.genre}'
                    .toLowerCase(),
          )
          .toList(growable: false);
      final result = snapshots.length < 5000
          ? <int>[
              for (var index = 0; index < snapshots.length; index++)
                if (snapshots[index].contains(needle)) index,
            ]
          : await Isolate.run(
              () => <int>[
                for (var index = 0; index < snapshots.length; index++)
                  if (snapshots[index].contains(needle)) index,
              ],
            );
      if (generation != _generation) return;
      _filteredIndices = result;
    }
    _loadedPages = 1;
    notifyListeners();
  }

  Future<List<Track>> find(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final snapshots = _tracks
        .map(
          (track) =>
              '${track.title}\u0000${track.artist}\u0000${track.album}\u0000${track.genre}'
                  .toLowerCase(),
        )
        .toList(growable: false);
    final indices = snapshots.length < 5000
        ? <int>[
            for (var index = 0; index < snapshots.length; index++)
              if (snapshots[index].contains(needle)) index,
          ]
        : await Isolate.run(
            () => <int>[
              for (var index = 0; index < snapshots.length; index++)
                if (snapshots[index].contains(needle)) index,
            ],
          );
    return indices.map((index) => _tracks[index]).toList(growable: false);
  }

  Future<DeviceLibraryResult> rescanInBackground() async {
    if (_scanning) {
      return DeviceLibraryResult(tracks: allTracks, permissionGranted: true);
    }
    _scanning = true;
    notifyListeners();
    final result = await DeviceLibraryService().scan(retryPermission: true);
    if (result.permissionGranted && result.error == null) {
      replace(result.tracks);
    }
    _scanning = false;
    notifyListeners();
    return result;
  }
}
