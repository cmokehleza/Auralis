import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../models/phase_three_models.dart';

class PlaylistCollaborationService {
  const PlaylistCollaborationService();

  CollaborativePlaylist merge(
    CollaborativePlaylist local,
    CollaborativePlaylist incoming,
  ) {
    final entries = <String>[];
    final seen = <String>{};
    for (final id in [...local.entries, ...incoming.entries]) {
      if (seen.add(id)) entries.add(id);
    }
    final newest = incoming.updatedAt.isAfter(local.updatedAt)
        ? incoming
        : local;
    return CollaborativePlaylist(
      id: local.id,
      name: newest.name,
      updatedAt: DateTime.now().toUtc(),
      entries: entries,
    );
  }

  Future<String?> exportFile(CollaborativePlaylist playlist) async {
    const type = XTypeGroup(
      label: 'Auralis collaborative playlist',
      extensions: ['auralis-playlist'],
    );
    final location = await getSaveLocation(
      suggestedName: '${_safeName(playlist.name)}.auralis-playlist',
      acceptedTypeGroups: const [type],
    );
    if (location == null) return null;
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(playlist.encode())),
      name: '${_safeName(playlist.name)}.auralis-playlist',
      mimeType: 'application/json',
    );
    await file.saveTo(location.path);
    return location.path;
  }

  Future<CollaborativePlaylist?> importFile() async {
    const type = XTypeGroup(
      label: 'Auralis collaborative playlist',
      extensions: ['auralis-playlist', 'json'],
    );
    final file = await openFile(acceptedTypeGroups: const [type]);
    if (file == null) return null;
    return CollaborativePlaylist.decode(await file.readAsString());
  }

  String _safeName(String value) => value
      .replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '')
      .trim()
      .replaceAll(' ', '-');
}
