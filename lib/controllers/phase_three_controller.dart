import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/phase_three_models.dart';
import '../models/track.dart';

class PhaseThreeController extends ChangeNotifier {
  PhaseThreeController();

  static const _key = 'auralis.phase3.v1';
  static const _recoverySessionKey = 'auralis.recovery.session.v1';
  static const _recoveryPositionKey = 'auralis.recovery.position.v1';
  SharedPreferencesAsync? _preferences;
  Timer? _saveDebounce;
  Timer? _statsSaveTimer;
  Future<void> _writeChain = Future<void>.value();
  final Map<String, String?> _pendingRecoveryWrites = {};
  Future<void>? _recoveryWrite;

  final List<OutputProfile> _outputProfiles = [
    const OutputProfile(
      id: 'phone',
      name: 'This phone',
      kind: OutputDeviceKind.phone,
    ),
    const OutputProfile(
      id: 'wired',
      name: 'Wired headphones',
      kind: OutputDeviceKind.wired,
      volume: .7,
    ),
    const OutputProfile(
      id: 'car',
      name: 'Car Bluetooth',
      kind: OutputDeviceKind.car,
      volume: .9,
    ),
    const OutputProfile(
      id: 'bluetooth',
      name: 'Bluetooth audio',
      kind: OutputDeviceKind.bluetooth,
    ),
    const OutputProfile(
      id: 'usb-dac',
      name: 'USB DAC',
      kind: OutputDeviceKind.usbDac,
      bitPerfectRequested: true,
    ),
  ];
  final List<LinkedTrackGroup> _linkedGroups = [];
  final Map<String, TrackListeningStat> _stats = {};
  final List<Track> _recoveryQueue = [];

  String _activeOutputId = 'phone';
  AudioFocusBehavior _audioFocusBehavior = AudioFocusBehavior.pause;
  AuralisDisplayMode _displayMode = AuralisDisplayMode.full;
  AppIconTheme _iconTheme = AppIconTheme.system;
  AppBackgroundMode _backgroundMode = AppBackgroundMode.defaultTheme;
  AppBackgroundTheme _backgroundTheme = AppBackgroundTheme.aurora;
  String? _customBackgroundPath;
  String _localeCode = 'en';
  bool _largeTapTargets = false;
  bool _batteryProfilerEnabled = false;
  bool _onboardingComplete = false;
  bool _showLyrics = false;
  double _lyricsFontScale = 1;
  bool _highContrastLyrics = false;
  int _lastScreenIndex = 0;
  String? _recoveryCurrentId;
  Duration _recoveryPosition = Duration.zero;
  int _recoveryGeneration = 0;
  bool _ready = false;

  List<OutputProfile> get outputProfiles => List.unmodifiable(_outputProfiles);
  List<LinkedTrackGroup> get linkedGroups => List.unmodifiable(_linkedGroups);
  Map<String, TrackListeningStat> get stats => Map.unmodifiable(_stats);
  List<Track> get recoveryQueue => List.unmodifiable(_recoveryQueue);
  OutputProfile get activeOutput => _outputProfiles.firstWhere(
    (profile) => profile.id == _activeOutputId,
    orElse: () => _outputProfiles.first,
  );
  AudioFocusBehavior get audioFocusBehavior => _audioFocusBehavior;
  AuralisDisplayMode get displayMode => _displayMode;
  AppIconTheme get iconTheme => _iconTheme;
  AppBackgroundMode get backgroundMode => _backgroundMode;
  AppBackgroundTheme get backgroundTheme => _backgroundTheme;
  String? get customBackgroundPath => _customBackgroundPath;
  String get localeCode => _localeCode;
  bool get largeTapTargets => _largeTapTargets;
  bool get batteryProfilerEnabled => _batteryProfilerEnabled;
  bool get onboardingComplete => _onboardingComplete;
  bool get showLyrics => _showLyrics;
  double get lyricsFontScale => _lyricsFontScale;
  bool get highContrastLyrics => _highContrastLyrics;
  int get lastScreenIndex => _lastScreenIndex;
  String? get recoveryCurrentId => _recoveryCurrentId;
  Duration get recoveryPosition => _recoveryPosition;
  bool get hasRecoverySession =>
      _recoveryQueue.isNotEmpty && _recoveryCurrentId != null;
  bool get ready => _ready;

  Future<void> restore() async {
    try {
      final preferences = _preferences ??= SharedPreferencesAsync();
      final rawValues = await Future.wait([
        preferences.getString(_key),
        preferences.getString(_recoverySessionKey),
        preferences.getString(_recoveryPositionKey),
      ]);
      final raw = rawValues[0];
      if (raw != null) {
        final decoded = await Isolate.run(
          () => jsonDecode(raw) as Map<String, dynamic>,
        );
        _applyJson(decoded);
      }
      final recoverySession = rawValues[1];
      if (recoverySession != null) {
        final decoded = await Isolate.run(
          () => jsonDecode(recoverySession) as Map<String, dynamic>,
        );
        _applyRecoverySessionJson(decoded);
      }
      final recoveryPosition = rawValues[2];
      if (recoveryPosition != null) {
        final decoded = await Isolate.run(
          () => jsonDecode(recoveryPosition) as Map<String, dynamic>,
        );
        _applyRecoveryPositionJson(decoded);
      }
      if (recoverySession == null && hasRecoverySession) {
        // Migrate the legacy inline recovery payload before future settings
        // writes intentionally omit the large queue.
        await _queueRecoveryWrite(
          _recoverySessionKey,
          jsonEncode(_recoverySessionJson()),
        );
        await saveRecoveryPosition(_recoveryCurrentId!, _recoveryPosition);
      }
    } catch (_) {
      // Tests and unsupported platforms retain safe defaults.
    }
    _ready = true;
    notifyListeners();
  }

  void selectOutput(String id) {
    if (!_outputProfiles.any((profile) => profile.id == id)) return;
    _activeOutputId = id;
    _changed();
  }

  void updateOutput(OutputProfile profile) {
    final index = _outputProfiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) return;
    _outputProfiles[index] = profile;
    _changed();
  }

  void setAudioFocusBehavior(AudioFocusBehavior value) {
    _audioFocusBehavior = value;
    _changed();
  }

  void setDisplayMode(AuralisDisplayMode value) {
    _displayMode = value;
    _changed();
  }

  void setIconTheme(AppIconTheme value) {
    _iconTheme = value;
    _changed();
  }

  void setDynamicBackground() {
    _backgroundMode = AppBackgroundMode.dynamic;
    _changed(immediate: true);
  }

  void setCustomBackground(String path) {
    if (path.trim().isEmpty) return;
    _customBackgroundPath = path;
    _backgroundMode = AppBackgroundMode.customImage;
    _changed(immediate: true);
  }

  void setThemeBackground(AppBackgroundTheme value) {
    _backgroundTheme = value;
    _backgroundMode = AppBackgroundMode.theme;
    _changed(immediate: true);
  }

  void resetBackground() {
    _backgroundMode = AppBackgroundMode.defaultTheme;
    _customBackgroundPath = null;
    _changed(immediate: true);
  }

  /// Completes any pending settings write, used before deterministic handoff
  /// points such as tests or a platform-managed shutdown.
  Future<void> flushSettings() {
    _saveDebounce?.cancel();
    return _persist();
  }

  void setLocale(String code) {
    _localeCode = code;
    _changed();
  }

  void setLargeTapTargets(bool value) {
    _largeTapTargets = value;
    _changed();
  }

  void setBatteryProfiler(bool value) {
    _batteryProfilerEnabled = value;
    _changed();
  }

  void completeOnboarding() {
    _onboardingComplete = true;
    _changed(immediate: true);
  }

  void configureLyrics({bool? visible, double? fontScale, bool? highContrast}) {
    if (visible != null) _showLyrics = visible;
    if (fontScale != null) _lyricsFontScale = fontScale.clamp(.8, 2);
    if (highContrast != null) _highContrastLyrics = highContrast;
    _changed();
  }

  void setLastScreen(int index) {
    _lastScreenIndex = index.clamp(0, 3);
    _changed();
  }

  void linkTracks(List<String> trackIds, String label) {
    final unique = trackIds.toSet().toList();
    if (unique.length < 2) return;
    _linkedGroups.add(
      LinkedTrackGroup(
        id: 'linked-${DateTime.now().microsecondsSinceEpoch}',
        label: label.trim().isEmpty ? 'Alternate versions' : label.trim(),
        trackIds: unique,
        preferredTrackId: unique.first,
      ),
    );
    _changed();
  }

  void removeLinkedGroup(String id) {
    _linkedGroups.removeWhere((group) => group.id == id);
    _changed();
  }

  void selectLinkedVersion(String groupId, String trackId) {
    final index = _linkedGroups.indexWhere((group) => group.id == groupId);
    if (index < 0 || !_linkedGroups[index].trackIds.contains(trackId)) return;
    final group = _linkedGroups[index];
    _linkedGroups[index] = LinkedTrackGroup(
      id: group.id,
      label: group.label,
      trackIds: group.trackIds,
      preferredTrackId: trackId,
    );
    _changed();
  }

  void recordTrackStarted(Track track) {
    _stats[track.id] = (_stats[track.id] ?? const TrackListeningStat()).add(
      plays: 1,
    );
    _changed();
  }

  void recordListening(String trackId, Duration elapsed) {
    if (elapsed <= Duration.zero || elapsed > const Duration(seconds: 10)) {
      return;
    }
    _stats[trackId] = (_stats[trackId] ?? const TrackListeningStat()).add(
      milliseconds: elapsed.inMilliseconds,
    );
    _statsSaveTimer ??= Timer(const Duration(seconds: 5), () {
      _statsSaveTimer = null;
      unawaited(_persist());
    });
  }

  int get totalListeningMs =>
      _stats.values.fold(0, (sum, value) => sum + value.listenedMs);

  int get totalPlays =>
      _stats.values.fold(0, (sum, value) => sum + value.playCount);

  void saveRecoverySession({
    required List<Track> queue,
    required String currentId,
    required Duration position,
    required int screenIndex,
  }) {
    final currentIndex = queue.indexWhere((track) => track.id == currentId);
    final maxStart = (queue.length - 5000).clamp(0, queue.length).toInt();
    final start = currentIndex < 0
        ? 0
        : (currentIndex - 2500).clamp(0, maxStart).toInt();
    _recoveryQueue
      ..clear()
      ..addAll(queue.skip(start).take(5000));
    if (!_recoveryQueue.any((track) => track.id == currentId)) {
      final current = queue.where((track) => track.id == currentId);
      if (current.isNotEmpty) {
        if (_recoveryQueue.length == 5000) _recoveryQueue.removeLast();
        _recoveryQueue.add(current.first);
      }
    }
    _recoveryCurrentId = currentId;
    _recoveryPosition = _boundedRecoveryPosition(currentId, position);
    _lastScreenIndex = screenIndex;
    _recoveryGeneration++;
    final snapshot = jsonEncode(_recoverySessionJson());
    unawaited(_queueRecoveryWrite(_recoverySessionKey, snapshot));
    unawaited(saveRecoveryPosition(currentId, _recoveryPosition));
  }

  /// Persists only the volatile playback cursor.
  ///
  /// Keeping this separate from the queue/settings payload makes frequent
  /// crash-recovery checkpoints cheap and lets the newest cursor supersede a
  /// slower, older full-session write.
  Future<void> saveRecoveryPosition(String currentId, Duration position) {
    if (!_recoveryQueue.any((track) => track.id == currentId)) {
      return Future<void>.value();
    }
    _recoveryCurrentId = currentId;
    _recoveryPosition = _boundedRecoveryPosition(currentId, position);
    return _queueRecoveryWrite(
      _recoveryPositionKey,
      jsonEncode({
        'currentId': currentId,
        'positionMs': _recoveryPosition.inMilliseconds,
        'generation': _recoveryGeneration,
      }),
    );
  }

  void clearRecoverySession() {
    _recoveryQueue.clear();
    _recoveryCurrentId = null;
    _recoveryPosition = Duration.zero;
    _recoveryGeneration = 0;
    unawaited(_queueRecoveryWrite(_recoverySessionKey, null));
    unawaited(_queueRecoveryWrite(_recoveryPositionKey, null));
    _changed();
  }

  Map<String, Object?> toJson() => {
    ..._persistentSettingsJson(),
    'recoveryQueue': _recoveryQueue
        .map((track) => track.toSessionJson())
        .toList(),
    'recoveryCurrent': _recoveryCurrentId,
    'recoveryPositionMs': _recoveryPosition.inMilliseconds,
    'recoveryGeneration': _recoveryGeneration,
  };

  Map<String, Object?> _persistentSettingsJson() => {
    'outputs': _outputProfiles.map((item) => item.toJson()).toList(),
    'activeOutput': _activeOutputId,
    'focus': _audioFocusBehavior.name,
    'display': _displayMode.name,
    'icon': _iconTheme.name,
    'backgroundMode': _backgroundMode.name,
    'backgroundTheme': _backgroundTheme.name,
    'customBackgroundPath': _customBackgroundPath,
    'locale': _localeCode,
    'largeTargets': _largeTapTargets,
    'batteryProfiler': _batteryProfilerEnabled,
    'onboarding': _onboardingComplete,
    'lyrics': _showLyrics,
    'lyricsScale': _lyricsFontScale,
    'lyricsContrast': _highContrastLyrics,
    'lastScreen': _lastScreenIndex,
    'linked': _linkedGroups.map((item) => item.toJson()).toList(),
    'stats': _stats.map((key, value) => MapEntry(key, value.toJson())),
  };

  Map<String, Object?> _recoverySessionJson() => {
    'recoveryQueue': _recoveryQueue
        .map((track) => track.toSessionJson())
        .toList(),
    'recoveryCurrent': _recoveryCurrentId,
    'recoveryPositionMs': _recoveryPosition.inMilliseconds,
    'recoveryGeneration': _recoveryGeneration,
    'lastScreen': _lastScreenIndex,
  };

  void _applyJson(Map<String, dynamic> json) {
    final outputs = (json['outputs'] as List?)
        ?.map(
          (item) =>
              OutputProfile.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList();
    if (outputs != null && outputs.isNotEmpty) {
      for (final saved in outputs) {
        final index = _outputProfiles.indexWhere(
          (profile) => profile.id == saved.id,
        );
        if (index >= 0) {
          _outputProfiles[index] = saved;
        } else {
          _outputProfiles.add(saved);
        }
      }
    }
    _activeOutputId = json['activeOutput'] as String? ?? 'phone';
    _audioFocusBehavior = AudioFocusBehavior.values.byName(
      json['focus'] as String? ?? 'pause',
    );
    _displayMode = AuralisDisplayMode.values.byName(
      json['display'] as String? ?? 'full',
    );
    _iconTheme = AppIconTheme.values.byName(
      json['icon'] as String? ?? 'system',
    );
    _backgroundMode = _enumByName(
      AppBackgroundMode.values,
      json['backgroundMode'] as String?,
      AppBackgroundMode.defaultTheme,
    );
    _backgroundTheme = _enumByName(
      AppBackgroundTheme.values,
      json['backgroundTheme'] as String?,
      AppBackgroundTheme.aurora,
    );
    _customBackgroundPath = json['customBackgroundPath'] as String?;
    if (_backgroundMode == AppBackgroundMode.customImage &&
        (_customBackgroundPath == null || _customBackgroundPath!.isEmpty)) {
      _backgroundMode = AppBackgroundMode.defaultTheme;
    }
    _localeCode = json['locale'] as String? ?? 'en';
    _largeTapTargets = json['largeTargets'] as bool? ?? false;
    _batteryProfilerEnabled = json['batteryProfiler'] as bool? ?? false;
    _onboardingComplete = json['onboarding'] as bool? ?? false;
    _showLyrics = json['lyrics'] as bool? ?? false;
    _lyricsFontScale = (json['lyricsScale'] as num?)?.toDouble() ?? 1;
    _highContrastLyrics = json['lyricsContrast'] as bool? ?? false;
    _lastScreenIndex = (json['lastScreen'] as num?)?.toInt() ?? 0;
    _linkedGroups
      ..clear()
      ..addAll(
        (json['linked'] as List? ?? const []).map(
          (item) =>
              LinkedTrackGroup.fromJson(Map<String, Object?>.from(item as Map)),
        ),
      );
    _stats
      ..clear()
      ..addAll(
        (json['stats'] as Map? ?? const {}).map(
          (key, value) => MapEntry(
            key as String,
            TrackListeningStat.fromJson(
              Map<String, Object?>.from(value as Map),
            ),
          ),
        ),
      );
    _recoveryQueue
      ..clear()
      ..addAll(
        (json['recoveryQueue'] as List? ?? const []).map(
          (item) =>
              Track.fromSessionJson(Map<String, Object?>.from(item as Map)),
        ),
      );
    _recoveryCurrentId = json['recoveryCurrent'] as String?;
    _recoveryPosition = Duration(
      milliseconds: (json['recoveryPositionMs'] as num?)?.toInt() ?? 0,
    );
    _recoveryGeneration = (json['recoveryGeneration'] as num?)?.toInt() ?? 0;
  }

  void _applyRecoverySessionJson(Map<String, dynamic> json) {
    _recoveryQueue
      ..clear()
      ..addAll(
        (json['recoveryQueue'] as List? ?? const []).map(
          (item) =>
              Track.fromSessionJson(Map<String, Object?>.from(item as Map)),
        ),
      );
    _recoveryCurrentId = json['recoveryCurrent'] as String?;
    _recoveryGeneration = (json['recoveryGeneration'] as num?)?.toInt() ?? 0;
    final position = Duration(
      milliseconds: (json['recoveryPositionMs'] as num?)?.toInt() ?? 0,
    );
    if (_recoveryCurrentId != null) {
      _recoveryPosition = _boundedRecoveryPosition(
        _recoveryCurrentId!,
        position,
      );
    } else {
      _recoveryPosition = Duration.zero;
    }
    _lastScreenIndex =
        (json['lastScreen'] as num?)?.toInt() ?? _lastScreenIndex;
  }

  void _applyRecoveryPositionJson(Map<String, dynamic> json) {
    final currentId = json['currentId'] as String?;
    final generation = (json['generation'] as num?)?.toInt() ?? 0;
    if (currentId == null ||
        generation != _recoveryGeneration ||
        !_recoveryQueue.any((track) => track.id == currentId)) {
      return;
    }
    _recoveryCurrentId = currentId;
    _recoveryPosition = _boundedRecoveryPosition(
      currentId,
      Duration(milliseconds: (json['positionMs'] as num?)?.toInt() ?? 0),
    );
  }

  Duration _boundedRecoveryPosition(String currentId, Duration position) {
    if (position < Duration.zero) return Duration.zero;
    final matches = _recoveryQueue.where((track) => track.id == currentId);
    if (matches.isEmpty) return Duration.zero;
    final duration = matches.first.duration;
    return duration > Duration.zero && position > duration
        ? duration
        : position;
  }

  void _changed({bool immediate = false}) {
    notifyListeners();
    _saveDebounce?.cancel();
    if (immediate) {
      unawaited(_persist());
    } else {
      _saveDebounce = Timer(const Duration(milliseconds: 500), _persist);
    }
  }

  Future<void> _persist() async {
    final snapshot = jsonEncode(_persistentSettingsJson());
    _writeChain = _writeChain.then((_) async {
      try {
        final preferences = _preferences ??= SharedPreferencesAsync();
        await preferences.setString(_key, snapshot);
      } catch (_) {
        // Persistence is best-effort in tests and unsupported hosts.
      }
    });
    await _writeChain;
  }

  Future<void> _queueRecoveryWrite(String key, String? value) {
    _pendingRecoveryWrites[key] = value;
    return _ensureRecoveryWrite();
  }

  Future<void> _ensureRecoveryWrite() {
    final active = _recoveryWrite;
    if (active != null) {
      return active.then((_) async {
        if (_pendingRecoveryWrites.isNotEmpty) {
          await _ensureRecoveryWrite();
        }
      });
    }

    late final Future<void> write;
    write = _flushRecoveryWrites().whenComplete(() {
      if (identical(_recoveryWrite, write)) _recoveryWrite = null;
    });
    _recoveryWrite = write;
    return write.then((_) async {
      if (_pendingRecoveryWrites.isNotEmpty) {
        await _ensureRecoveryWrite();
      }
    });
  }

  Future<void> _flushRecoveryWrites() async {
    while (_pendingRecoveryWrites.isNotEmpty) {
      final pending = Map<String, String?>.from(_pendingRecoveryWrites);
      _pendingRecoveryWrites.clear();
      try {
        final preferences = _preferences ??= SharedPreferencesAsync();
        for (final entry in pending.entries) {
          if (entry.value == null) {
            await preferences.remove(entry.key);
          } else {
            await preferences.setString(entry.key, entry.value!);
          }
        }
      } catch (_) {
        // Persistence is best-effort in tests and unsupported hosts.
      }
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _statsSaveTimer?.cancel();
    super.dispose();
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
