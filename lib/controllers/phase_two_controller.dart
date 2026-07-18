import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/advanced_models.dart';
import '../services/platform_file_service.dart';

class PhaseTwoController extends ChangeNotifier {
  PhaseTwoController({this._preferences});

  static const _storageKey = 'auralis.phase2.settings.v1';
  static const _schemaVersion = 2;
  SharedPreferencesAsync? _preferences;
  final List<TrackBookmark> _bookmarks = [];
  final List<PlaylistRule> _playlistRules = [];
  final List<UserPlaylist> _userPlaylists = [];
  final Set<String> _favoriteIds = {};
  final Map<String, Map<String, String>> _customTags = {};
  final Map<String, int> _resumePositionsMs = {};
  Timer? _sleepTimer;
  Timer? _saveDebounce;
  Future<void> _writeChain = Future<void>.value();

  Color _accent = const Color(0xFF95F3C7);
  SleepTimerMode _sleepMode = SleepTimerMode.off;
  int _sleepMinutes = 30;
  bool _autoPauseOnDisconnect = true;
  bool _autoResumeOnReconnect = false;
  bool _silenceCalibration = false;
  bool _replayGain = true;
  bool _bitPerfect = true;
  bool _gapless = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _highContrast = false;
  bool _watchFolders = true;
  double _volumeLimit = .85;
  bool _ready = false;

  Color get accent => _accent;
  SleepTimerMode get sleepMode => _sleepMode;
  int get sleepMinutes => _sleepMinutes;
  bool get autoPauseOnDisconnect => _autoPauseOnDisconnect;
  bool get autoResumeOnReconnect => _autoResumeOnReconnect;
  bool get silenceCalibration => _silenceCalibration;
  bool get replayGain => _replayGain;
  bool get bitPerfect => _bitPerfect;
  bool get gapless => _gapless;
  ThemeMode get themeMode => _themeMode;
  bool get highContrast => _highContrast;
  bool get watchFolders => _watchFolders;
  double get volumeLimit => _volumeLimit;
  bool get ready => _ready;
  List<TrackBookmark> get bookmarks => List.unmodifiable(_bookmarks);
  List<PlaylistRule> get playlistRules => List.unmodifiable(_playlistRules);
  List<UserPlaylist> get userPlaylists => List.unmodifiable(_userPlaylists);
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  List<TrackBookmark> bookmarksFor(String trackId) =>
      _bookmarks.where((bookmark) => bookmark.trackId == trackId).toList();

  Duration? resumePositionFor(String trackId) {
    final milliseconds = _resumePositionsMs[trackId];
    return milliseconds == null ? null : Duration(milliseconds: milliseconds);
  }

  Map<String, String> customTagsFor(String trackId) =>
      Map.unmodifiable(_customTags[trackId] ?? const {});

  Future<void> restore() async {
    try {
      final preferences = _preferences ??= SharedPreferencesAsync();
      final value = await preferences.getString(_storageKey);
      if (value != null) _applyJson(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      // Widget tests and unsupported platforms can run without a preferences plugin.
    }
    _ready = true;
    notifyListeners();
  }

  void setAccent(Color value) {
    _accent = value;
    _changed();
  }

  void setAutoPauseOnDisconnect(bool value) {
    _autoPauseOnDisconnect = value;
    _changed();
  }

  void setAutoResumeOnReconnect(bool value) {
    _autoResumeOnReconnect = value;
    _changed();
  }

  void setSilenceCalibration(bool value) {
    _silenceCalibration = value;
    _changed();
  }

  void setReplayGain(bool value) {
    _replayGain = value;
    _changed();
  }

  void setBitPerfect(bool value) {
    _bitPerfect = value;
    _changed();
  }

  void setGapless(bool value) {
    _gapless = value;
    _changed();
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    _changed();
  }

  void setHighContrast(bool value) {
    _highContrast = value;
    _changed();
  }

  void setWatchFolders(bool value) {
    _watchFolders = value;
    _changed();
  }

  void setVolumeLimit(double value) {
    _volumeLimit = value;
    _changed();
  }

  void addBookmark(String trackId, Duration position, {String? label}) {
    final item = TrackBookmark(
      id: '${trackId}_${DateTime.now().microsecondsSinceEpoch}',
      trackId: trackId,
      label: label?.trim().isNotEmpty == true
          ? label!.trim()
          : 'Bookmark ${bookmarksFor(trackId).length + 1}',
      position: position,
    );
    _bookmarks.add(item);
    _changed();
  }

  void removeBookmark(String id) {
    _bookmarks.removeWhere((item) => item.id == id);
    _changed();
  }

  void setCustomTag(String trackId, String field, String value) {
    final tags = _customTags.putIfAbsent(trackId, () => {});
    if (value.trim().isEmpty) {
      tags.remove(field);
    } else {
      tags[field] = value.trim();
    }
    _changed();
  }

  void addRule(PlaylistRule rule) {
    _playlistRules.add(rule);
    _changed();
  }

  void removeRule(int index) {
    _playlistRules.removeAt(index);
    _changed();
  }

  String createPlaylist(String name) {
    final trimmed = name.trim();
    final id = 'playlist-${DateTime.now().microsecondsSinceEpoch}';
    _userPlaylists.add(
      UserPlaylist(
        id: id,
        name: trimmed.isEmpty ? 'Untitled playlist' : trimmed,
        trackIds: const [],
      ),
    );
    _changed();
    return id;
  }

  void deletePlaylist(String id) {
    _userPlaylists.removeWhere((playlist) => playlist.id == id);
    _changed();
  }

  void addTracksToPlaylist(String id, Iterable<String> trackIds) {
    final index = _userPlaylists.indexWhere((playlist) => playlist.id == id);
    if (index < 0) return;
    final merged = <String>{
      ..._userPlaylists[index].trackIds,
      ...trackIds,
    }.toList();
    _userPlaylists[index] = _userPlaylists[index].copyWith(trackIds: merged);
    _changed();
  }

  void removeTrackFromPlaylist(String id, String trackId) {
    final index = _userPlaylists.indexWhere((playlist) => playlist.id == id);
    if (index < 0) return;
    _userPlaylists[index] = _userPlaylists[index].copyWith(
      trackIds: _userPlaylists[index].trackIds
          .where((item) => item != trackId)
          .toList(),
    );
    _changed();
  }

  void setFavoriteIds(Iterable<String> trackIds) {
    final updated = trackIds.toSet();
    if (_favoriteIds.length == updated.length &&
        _favoriteIds.every(updated.contains)) {
      return;
    }
    _favoriteIds
      ..clear()
      ..addAll(updated);
    _changed();
  }

  void saveResumePosition(String trackId, Duration position) {
    _resumePositionsMs[trackId] = position.inMilliseconds;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 2), _persist);
  }

  void configureSleepTimer(
    SleepTimerMode mode, {
    int? minutes,
    VoidCallback? onElapsed,
  }) {
    _sleepTimer?.cancel();
    _sleepMode = mode;
    if (minutes != null) _sleepMinutes = minutes;
    if (mode == SleepTimerMode.minutes && onElapsed != null) {
      _sleepTimer = Timer(Duration(minutes: _sleepMinutes), onElapsed);
    }
    _changed();
  }

  Future<String?> exportBackup() async {
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(toJson())),
    );
    return PlatformFileService.saveBytes(
      bytes: bytes,
      suggestedName: 'auralis-backup.json',
      mimeType: 'application/json',
      extensions: const ['json'],
    );
  }

  Future<bool> importBackup() async {
    const type = XTypeGroup(label: 'Auralis JSON backup', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: const [type]);
    if (file == null) return false;
    try {
      final bytes = await file.readAsBytes();
      _applyJson(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
      await _persist();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
    'version': _schemaVersion,
    'accent': _accent.toARGB32(),
    'sleepMode': _sleepMode.name,
    'sleepMinutes': _sleepMinutes,
    'autoPauseOnDisconnect': _autoPauseOnDisconnect,
    'autoResumeOnReconnect': _autoResumeOnReconnect,
    'silenceCalibration': _silenceCalibration,
    'replayGain': _replayGain,
    'bitPerfect': _bitPerfect,
    'gapless': _gapless,
    'themeMode': _themeMode.name,
    'highContrast': _highContrast,
    'watchFolders': _watchFolders,
    'volumeLimit': _volumeLimit,
    'bookmarks': _bookmarks.map((item) => item.toJson()).toList(),
    'rules': _playlistRules.map((item) => item.toJson()).toList(),
    'playlists': _userPlaylists.map((item) => item.toJson()).toList(),
    'favorites': _favoriteIds.toList(),
    'customTags': _customTags,
    'resumePositions': _resumePositionsMs,
  };

  void _applyJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    _accent = Color((json['accent'] as num?)?.toInt() ?? _accent.toARGB32());
    _sleepMode = SleepTimerMode.values.byName(
      json['sleepMode'] as String? ?? 'off',
    );
    _sleepMinutes = (json['sleepMinutes'] as num?)?.toInt() ?? 30;
    _autoPauseOnDisconnect = json['autoPauseOnDisconnect'] as bool? ?? true;
    _autoResumeOnReconnect = json['autoResumeOnReconnect'] as bool? ?? false;
    // Version 1 enabled Android silence skipping by default. That changed the
    // timing of quiet music and could sound like an unexpected speed-up.
    _silenceCalibration = version >= _schemaVersion
        ? json['silenceCalibration'] as bool? ?? false
        : false;
    _replayGain = json['replayGain'] as bool? ?? true;
    _bitPerfect = json['bitPerfect'] as bool? ?? true;
    _gapless = json['gapless'] as bool? ?? true;
    _themeMode = switch (json['themeMode']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _highContrast = json['highContrast'] as bool? ?? false;
    _watchFolders = json['watchFolders'] as bool? ?? true;
    _volumeLimit = (json['volumeLimit'] as num?)?.toDouble() ?? .85;
    _bookmarks
      ..clear()
      ..addAll(
        (json['bookmarks'] as List? ?? const []).map(
          (item) =>
              TrackBookmark.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    _playlistRules
      ..clear()
      ..addAll(
        (json['rules'] as List? ?? const []).map(
          (item) =>
              PlaylistRule.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    _userPlaylists
      ..clear()
      ..addAll(
        (json['playlists'] as List? ?? const []).map(
          (item) =>
              UserPlaylist.fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    _favoriteIds
      ..clear()
      ..addAll((json['favorites'] as List? ?? const []).cast<String>());
    _customTags
      ..clear()
      ..addAll(
        (json['customTags'] as Map? ?? const {}).map(
          (key, value) =>
              MapEntry(key.toString(), Map<String, String>.from(value as Map)),
        ),
      );
    _resumePositionsMs
      ..clear()
      ..addAll(
        (json['resumePositions'] as Map? ?? const {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        ),
      );
  }

  void _changed() {
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final snapshot = jsonEncode(toJson());
    _writeChain = _writeChain.then((_) async {
      try {
        final preferences = _preferences ??= SharedPreferencesAsync();
        await preferences.setString(_storageKey, snapshot);
      } catch (_) {
        // Persistence is best-effort when a platform plugin is unavailable.
      }
    });
    await _writeChain;
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _saveDebounce?.cancel();
    super.dispose();
  }
}
