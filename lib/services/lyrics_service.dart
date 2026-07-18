import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/track.dart';

enum LyricsSource { embedded, sidecar }

@immutable
class LyricLine {
  const LyricLine({required this.text, this.timestamp});

  final String text;
  final Duration? timestamp;
}

@immutable
class LyricsDocument {
  const LyricsDocument({required this.lines, required this.source});

  final List<LyricLine> lines;
  final LyricsSource source;

  bool get isSynced => lines.any((line) => line.timestamp != null);

  int activeIndexAt(Duration position) {
    if (!isSynced || lines.isEmpty) return -1;
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final middle = low + ((high - low) ~/ 2);
      final timestamp = lines[middle].timestamp;
      if (timestamp == null || timestamp > position) {
        high = middle - 1;
      } else {
        result = middle;
        low = middle + 1;
      }
    }
    return result;
  }

  List<String> toLrcLines() => lines
      .where((line) => line.timestamp != null)
      .map((line) {
        final at = line.timestamp!;
        final minutes = at.inMinutes.toString().padLeft(2, '0');
        final seconds = at.inSeconds.remainder(60).toString().padLeft(2, '0');
        final milliseconds = at.inMilliseconds
            .remainder(1000)
            .toString()
            .padLeft(3, '0');
        return '[$minutes:$seconds.$milliseconds]${line.text}';
      })
      .toList(growable: false);
}

/// Resolves lyrics attached to a track, embedded in ID3v2 USLT/SYLT frames, or
/// stored in a matching `.lrc` file next to the audio file.
class LyricsService {
  const LyricsService();

  static const _maximumSidecarBytes = 2 * 1024 * 1024;
  static const _maximumId3TagBytes = 8 * 1024 * 1024;
  static final RegExp _timestampPattern = RegExp(
    r'\[(?:(\d{1,2}):)?(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]',
  );
  static final RegExp _enhancedTimestampPattern = RegExp(
    r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>',
  );
  static final RegExp _metadataPattern = RegExp(
    r'^\[(?:ar|al|au|by|length|re|ti|ve):',
    caseSensitive: false,
  );

  Future<LyricsDocument?> loadFor(Track track) async {
    if (track.syncedLyrics.isNotEmpty) {
      final embedded = parse(
        track.syncedLyrics.join('\n'),
        source: LyricsSource.embedded,
      );
      if (embedded != null) return embedded;
    }

    final sidecar = await _findSidecar(track);
    if (sidecar != null) {
      try {
        final size = await sidecar.length();
        if (size > 0 && size <= _maximumSidecarBytes) {
          final bytes = await sidecar.readAsBytes();
          final raw = utf8.decode(bytes, allowMalformed: true);
          final resolved = parse(raw, source: LyricsSource.sidecar);
          if (resolved != null) return resolved;
        }
      } on FileSystemException {
        // Fall through to embedded metadata when the sidecar is unreadable.
      }
    }

    return _readEmbeddedId3(track);
  }

  LyricsDocument? parse(
    String raw, {
    LyricsSource source = LyricsSource.embedded,
  }) {
    final input = raw.replaceFirst('\uFEFF', '');
    final rawLines = input.split(RegExp(r'\r?\n'));
    var offsetMilliseconds = 0;
    for (final line in rawLines) {
      final offset = RegExp(
        r'\[offset\s*:\s*([+-]?\d+)\s*\]',
        caseSensitive: false,
      ).firstMatch(line);
      if (offset != null) {
        offsetMilliseconds = int.tryParse(offset.group(1)!) ?? 0;
      }
    }

    final timed = <LyricLine>[];
    final plain = <LyricLine>[];
    for (final rawLine in rawLines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final matches = _timestampPattern.allMatches(line).toList();
      if (matches.isNotEmpty) {
        final text = line
            .replaceAll(_timestampPattern, '')
            .replaceAll(_enhancedTimestampPattern, '')
            .trim();
        for (final match in matches) {
          final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
          final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
          final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
          if (seconds >= 60) continue;
          final fraction = match.group(4) ?? '';
          final milliseconds = fraction.isEmpty
              ? 0
              : int.parse(fraction.padRight(3, '0').substring(0, 3));
          final rawMilliseconds =
              Duration(
                hours: hours,
                minutes: minutes,
                seconds: seconds,
                milliseconds: milliseconds,
              ).inMilliseconds +
              offsetMilliseconds;
          timed.add(
            LyricLine(
              timestamp: Duration(
                milliseconds: rawMilliseconds < 0 ? 0 : rawMilliseconds,
              ),
              text: text,
            ),
          );
        }
      } else if (!_metadataPattern.hasMatch(line) &&
          !line.toLowerCase().startsWith('[offset:')) {
        plain.add(LyricLine(text: line));
      }
    }

    if (timed.isNotEmpty) {
      timed.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
      final unique = <LyricLine>[];
      for (final line in timed) {
        final duplicate =
            unique.isNotEmpty &&
            unique.last.timestamp == line.timestamp &&
            unique.last.text == line.text;
        if (!duplicate) unique.add(line);
      }
      return LyricsDocument(lines: List.unmodifiable(unique), source: source);
    }
    if (plain.isEmpty) return null;
    return LyricsDocument(lines: List.unmodifiable(plain), source: source);
  }

  Future<LyricsDocument?> _readEmbeddedId3(Track track) async {
    final path = _audioPath(track);
    if (path == null) return null;
    RandomAccessFile? handle;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      handle = await file.open();
      final header = await handle.read(10);
      if (header.length != 10 ||
          header[0] != 0x49 ||
          header[1] != 0x44 ||
          header[2] != 0x33) {
        return null;
      }
      final version = header[3];
      if (version < 2 || version > 4) return null;
      final tagSize = _synchsafeInteger(header, 6);
      if (tagSize <= 0 || tagSize > _maximumId3TagBytes) return null;
      final fileLength = await handle.length();
      if (tagSize > fileLength - 10) return null;
      final payload = await handle.read(tagSize);
      if (payload.length != tagSize) return null;
      return _parseId3Frames(payload, version: version, flags: header[5]);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } finally {
      await handle?.close();
    }
  }

  LyricsDocument? _parseId3Frames(
    List<int> payload, {
    required int version,
    required int flags,
  }) {
    var cursor = 0;
    if (version >= 3 && flags & 0x40 != 0) {
      if (payload.length < 4) return null;
      final extendedSize = version == 4
          ? _synchsafeInteger(payload, 0)
          : _bigEndianInteger(payload, 0, 4) + 4;
      if (extendedSize < 4 || extendedSize > payload.length) return null;
      cursor = extendedSize;
    }

    LyricsDocument? unsynchronizedFallback;
    final headerSize = version == 2 ? 6 : 10;
    while (cursor + headerSize <= payload.length) {
      final idLength = version == 2 ? 3 : 4;
      if (payload.skip(cursor).take(idLength).every((byte) => byte == 0)) {
        break;
      }
      final frameId = ascii.decode(
        payload.sublist(cursor, cursor + idLength),
        allowInvalid: true,
      );
      if (!_validFrameId(frameId)) break;
      final frameSize = version == 2
          ? _bigEndianInteger(payload, cursor + 3, 3)
          : version == 4
          ? _synchsafeInteger(payload, cursor + 4)
          : _bigEndianInteger(payload, cursor + 4, 4);
      if (frameSize <= 0 || cursor + headerSize + frameSize > payload.length) {
        break;
      }

      final secondFlag = version == 2 ? 0 : payload[cursor + 9];
      final unsupportedEncoding = version == 3
          ? secondFlag & 0xC0 != 0
          : version == 4
          ? secondFlag & 0x0C != 0
          : false;
      var frame = payload.sublist(
        cursor + headerSize,
        cursor + headerSize + frameSize,
      );
      if (!unsupportedEncoding) {
        final frameUnsynchronized =
            flags & 0x80 != 0 || (version == 4 && secondFlag & 0x02 != 0);
        if (frameUnsynchronized) frame = _removeUnsynchronization(frame);
        if (frameId == 'SYLT' || frameId == 'SLT') {
          final synchronized = _parseSyltFrame(frame);
          if (synchronized != null) return synchronized;
        } else if (frameId == 'USLT' || frameId == 'ULT') {
          unsynchronizedFallback ??= _parseUsltFrame(frame);
        }
      }
      cursor += headerSize + frameSize;
    }
    return unsynchronizedFallback;
  }

  LyricsDocument? _parseUsltFrame(List<int> frame) {
    if (frame.length < 5) return null;
    final encoding = frame[0];
    final descriptorEnd = _findTextTerminator(frame, 4, encoding);
    if (descriptorEnd < 0) return null;
    final textStart = descriptorEnd + _terminatorWidth(encoding);
    if (textStart >= frame.length) return null;
    final lyrics = _decodeId3Text(frame.sublist(textStart), encoding);
    if (lyrics.trim().isEmpty) return null;
    return parse(lyrics, source: LyricsSource.embedded);
  }

  LyricsDocument? _parseSyltFrame(List<int> frame) {
    if (frame.length < 8 || frame[4] != 2) return null;
    final encoding = frame[0];
    final descriptorEnd = _findTextTerminator(frame, 6, encoding);
    if (descriptorEnd < 0) return null;
    var cursor = descriptorEnd + _terminatorWidth(encoding);
    final lines = <LyricLine>[];
    while (cursor < frame.length && lines.length < 20000) {
      final textEnd = _findTextTerminator(frame, cursor, encoding);
      if (textEnd < 0) break;
      final timestampOffset = textEnd + _terminatorWidth(encoding);
      if (timestampOffset + 4 > frame.length) break;
      final text = _decodeId3Text(
        frame.sublist(cursor, textEnd),
        encoding,
      ).trim();
      final milliseconds = _bigEndianInteger(frame, timestampOffset, 4);
      if (text.isNotEmpty) {
        lines.add(
          LyricLine(
            text: text,
            timestamp: Duration(milliseconds: milliseconds),
          ),
        );
      }
      cursor = timestampOffset + 4;
    }
    if (lines.isEmpty) return null;
    lines.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
    return LyricsDocument(
      lines: List.unmodifiable(lines),
      source: LyricsSource.embedded,
    );
  }

  static int _findTextTerminator(List<int> bytes, int start, int encoding) {
    if (encoding == 0 || encoding == 3) {
      for (var index = start; index < bytes.length; index++) {
        if (bytes[index] == 0) return index;
      }
      return -1;
    }
    if (encoding != 1 && encoding != 2) return -1;
    for (var index = start; index + 1 < bytes.length; index += 2) {
      if (bytes[index] == 0 && bytes[index + 1] == 0) return index;
    }
    return -1;
  }

  static int _terminatorWidth(int encoding) =>
      encoding == 1 || encoding == 2 ? 2 : 1;

  static String _decodeId3Text(List<int> bytes, int encoding) {
    if (bytes.isEmpty) return '';
    String decoded;
    if (encoding == 0) {
      decoded = latin1.decode(bytes, allowInvalid: true);
    } else if (encoding == 3) {
      decoded = utf8.decode(bytes, allowMalformed: true);
    } else if (encoding == 1 || encoding == 2) {
      var littleEndian = false;
      var cursor = 0;
      if (encoding == 1 && bytes.length >= 2) {
        if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
          littleEndian = true;
          cursor = 2;
        } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
          cursor = 2;
        }
      }
      final codeUnits = <int>[];
      while (cursor + 1 < bytes.length) {
        codeUnits.add(
          littleEndian
              ? bytes[cursor] | (bytes[cursor + 1] << 8)
              : (bytes[cursor] << 8) | bytes[cursor + 1],
        );
        cursor += 2;
      }
      decoded = String.fromCharCodes(codeUnits);
    } else {
      return '';
    }
    return decoded
        .replaceAll('\u0000', '')
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .trim();
  }

  static int _synchsafeInteger(List<int> bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) return -1;
    if (bytes.skip(offset).take(4).any((byte) => byte < 0 || byte > 0x7F)) {
      return -1;
    }
    return (bytes[offset] << 21) |
        (bytes[offset + 1] << 14) |
        (bytes[offset + 2] << 7) |
        bytes[offset + 3];
  }

  static int _bigEndianInteger(List<int> bytes, int offset, int length) {
    if (offset < 0 || length <= 0 || offset + length > bytes.length) return -1;
    var value = 0;
    for (var index = 0; index < length; index++) {
      value = (value << 8) | bytes[offset + index];
    }
    return value;
  }

  static bool _validFrameId(String value) {
    if (value.length != 3 && value.length != 4) return false;
    return value.codeUnits.every(
      (unit) =>
          (unit >= 0x41 && unit <= 0x5A) || (unit >= 0x30 && unit <= 0x39),
    );
  }

  static List<int> _removeUnsynchronization(List<int> bytes) {
    final result = <int>[];
    for (var index = 0; index < bytes.length; index++) {
      final byte = bytes[index];
      result.add(byte);
      if (byte == 0xFF && index + 1 < bytes.length && bytes[index + 1] == 0) {
        index++;
      }
    }
    return result;
  }

  Future<File?> _findSidecar(Track track) async {
    final path = _audioPath(track);
    if (path == null || path.isEmpty) return null;

    final audio = File(path);
    final directory = audio.parent;
    final fileName = _fileName(path);
    final audioStem = _withoutExtension(fileName);
    final preferredNames = <String>{
      _normalizeName(audioStem),
      _normalizeName(track.title),
      _normalizeName('${track.artist} - ${track.title}'),
    }..removeWhere((name) => name.isEmpty);

    try {
      if (!await directory.exists()) return null;
      File? titleMatch;
      File? artistTitleMatch;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.lrc')) {
          continue;
        }
        final stem = _normalizeName(_withoutExtension(_fileName(entity.path)));
        if (stem == _normalizeName(audioStem)) return entity;
        if (stem == _normalizeName('${track.artist} - ${track.title}')) {
          artistTitleMatch = entity;
        } else if (stem == _normalizeName(track.title)) {
          titleMatch = entity;
        } else if (!preferredNames.contains(stem)) {
          continue;
        }
      }
      return artistTitleMatch ?? titleMatch;
    } on FileSystemException {
      return null;
    }
  }

  static String? _audioPath(Track track) {
    var path = track.filePath;
    if ((path == null || path.isEmpty) && track.sourceUri != null) {
      final uri = Uri.tryParse(track.sourceUri!);
      if (uri?.scheme == 'file') path = uri!.toFilePath();
    }
    return path;
  }

  static String _fileName(String path) {
    final slash = path.lastIndexOf('/');
    final backslash = path.lastIndexOf('\\');
    final separator = slash > backslash ? slash : backslash;
    return separator < 0 ? path : path.substring(separator + 1);
  }

  static String _withoutExtension(String value) {
    final dot = value.lastIndexOf('.');
    return dot <= 0 ? value : value.substring(0, dot);
  }

  static String _normalizeName(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
