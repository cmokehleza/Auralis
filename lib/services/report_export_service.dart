import 'dart:convert';
import 'dart:typed_data';

import '../models/phase_three_models.dart';
import '../models/track.dart';
import 'platform_file_service.dart';

class ReportExportService {
  const ReportExportService();

  String libraryCsv(List<Track> tracks, Map<String, TrackListeningStat> stats) {
    final rows = <String>[
      'id,title,artist,album,disc,track,genre,year,duration_seconds,plays,listened_seconds,path',
    ];
    for (final track in tracks) {
      final stat = stats[track.id] ?? const TrackListeningStat();
      rows.add(
        [
          track.id,
          track.title,
          track.artist,
          track.album,
          track.discNumber,
          track.trackNumber ?? '',
          track.genre,
          track.year,
          track.duration.inSeconds,
          stat.playCount,
          stat.listenedMs ~/ 1000,
          track.filePath ?? track.sourceUri ?? '',
        ].map((value) => _csv(value.toString())).join(','),
      );
    }
    return rows.join('\r\n');
  }

  Future<String?> exportLibrary(
    List<Track> tracks,
    Map<String, TrackListeningStat> stats,
  ) async {
    return PlatformFileService.saveBytes(
      bytes: Uint8List.fromList(utf8.encode(libraryCsv(tracks, stats))),
      suggestedName: 'auralis-library-report.csv',
      mimeType: 'text/csv',
      extensions: const ['csv'],
    );
  }

  String _csv(String value) =>
      '"${value.replaceAll('"', '""').replaceAll(RegExp(r'[\r\n]+'), ' ')}"';
}
