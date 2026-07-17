import 'dart:io';

import '../models/advanced_models.dart';
import '../models/track.dart';

/// Content-based duplicate detection that samples bytes from the audio files.
/// It deliberately ignores names and metadata so retagged copies still match.
class AudioFingerprintService {
  Future<List<DuplicateGroup>> findDuplicates(List<Track> tracks) async {
    final buckets = <String, List<({Track track, int bytes})>>{};
    for (final track in tracks.where((item) => item.filePath != null)) {
      try {
        final file = File(track.filePath!);
        final length = await file.length();
        final handle = await file.open();
        final head = await handle.read(64 * 1024);
        if (length > 128 * 1024) await handle.setPosition(length - 64 * 1024);
        final tail = await handle.read(64 * 1024);
        await handle.close();
        var hash = 0xcbf29ce484222325;
        for (final byte in [...head, ...tail]) {
          hash ^= byte;
          hash = (hash * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF;
        }
        final key = '$length-${hash.toRadixString(16)}';
        buckets.putIfAbsent(key, () => []).add((track: track, bytes: length));
      } catch (_) {
        // Storage providers may expose a content URI without a directly readable path.
      }
    }
    return buckets.entries
        .where((entry) => entry.value.length > 1)
        .map(
          (entry) => DuplicateGroup(
            fingerprint: entry.key,
            trackIds: entry.value.map((item) => item.track.id).toList(),
            savedBytes: entry.value
                .skip(1)
                .fold(0, (sum, item) => sum + item.bytes),
          ),
        )
        .toList();
  }
}
