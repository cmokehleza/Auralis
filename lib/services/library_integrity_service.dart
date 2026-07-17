import '../models/phase_three_models.dart';
import '../models/track.dart';

class LibraryIntegrityService {
  const LibraryIntegrityService();

  LibraryIntegrityReport checkAndRepair(List<Track> source) {
    final seen = <String>{};
    var duplicateIds = 0;
    var invalid = 0;
    final repaired = <Track>[];
    for (final track in source) {
      if (!seen.add(track.id)) {
        duplicateIds++;
        continue;
      }
      if (track.title.trim().isEmpty || track.duration <= Duration.zero) {
        invalid++;
        if (track.duration <= Duration.zero) continue;
      }
      repaired.add(
        track.title.trim().isEmpty
            ? track.copyWith(
                title:
                    track.filePath?.split(RegExp(r'[/\\]')).last ?? 'Untitled',
              )
            : track,
      );
    }
    return LibraryIntegrityReport(
      duplicateIds: duplicateIds,
      invalidTracks: invalid,
      repairedTracks: repaired,
    );
  }
}
