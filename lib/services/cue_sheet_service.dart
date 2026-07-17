import '../models/phase_three_models.dart';

class CueSheetService {
  const CueSheetService();

  List<CueSegment> parse(String source) {
    final raw =
        <({int number, String title, String performer, Duration start})>[];
    var albumPerformer = 'Unknown artist';
    int? number;
    String? title;
    String? performer;
    Duration? start;

    void flush() {
      if (number == null || start == null) return;
      final trackNumber = number;
      final trackStart = start;
      raw.add((
        number: trackNumber,
        title: title ?? 'Track ${trackNumber.toString().padLeft(2, '0')}',
        performer: performer ?? albumPerformer,
        start: trackStart,
      ));
    }

    for (final original in source.split(RegExp(r'\r?\n'))) {
      final line = original.trim();
      final trackMatch = RegExp(
        r'^TRACK\s+(\d+)\s+AUDIO$',
        caseSensitive: false,
      ).firstMatch(line);
      if (trackMatch != null) {
        flush();
        number = int.parse(trackMatch.group(1)!);
        title = null;
        performer = null;
        start = null;
        continue;
      }
      final titleMatch = RegExp(
        r'^TITLE\s+"?(.*?)"?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (titleMatch != null && number != null) title = titleMatch.group(1);
      final performerMatch = RegExp(
        r'^PERFORMER\s+"?(.*?)"?$',
        caseSensitive: false,
      ).firstMatch(line);
      if (performerMatch != null) {
        if (number == null) {
          albumPerformer = performerMatch.group(1)!;
        } else {
          performer = performerMatch.group(1);
        }
      }
      final indexMatch = RegExp(
        r'^INDEX\s+01\s+(\d+):(\d+):(\d+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (indexMatch != null) {
        final minutes = int.parse(indexMatch.group(1)!);
        final seconds = int.parse(indexMatch.group(2)!);
        final frames = int.parse(indexMatch.group(3)!);
        start = Duration(
          milliseconds:
              ((minutes * 60 + seconds) * 1000) + (frames * 1000 ~/ 75),
        );
      }
    }
    flush();
    return [
      for (var index = 0; index < raw.length; index++)
        CueSegment(
          number: raw[index].number,
          title: raw[index].title,
          performer: raw[index].performer,
          start: raw[index].start,
          end: index + 1 < raw.length ? raw[index + 1].start : null,
        ),
    ];
  }
}
