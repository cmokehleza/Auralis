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
  SharedPreferencesAsync? _preferences;
  Timer? _saveDebounce;
  Timer? _statsSaveTimer;
  Future<void> _writeChain = Future<void>.value();

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
      eqPreset: 'Road',
      volume: .9,
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
      final raw = await preferences.getString(_key);
      if (raw != null) {
        final decoded = await Isolate.run(
          () => jsonDecode(raw) as Map<String, dynamic>,
        );
        _applyJson(decoded);
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
    _recoveryQueue
      ..clear()
      ..addAll(queue.take(5000));
    _recoveryCurrentId = currentId;
    _recoveryPosition = position;
    _lastScreenIndex = screenIndex;
    unawaited(_persist());
  }

  void clearRecoverySession() {
    _recoveryQueue.clear();
    _recoveryCurrentId = null;
    _recoveryPosition = Duration.zero;
    _changed();
  }

  Map<String, Object?> toJson() => {
    'outputs': _outputProfiles.map((item) => item.toJson()).toList(),
    'activeOutput': _activeOutputId,
    'focus': _audioFocusBehavior.name,
    'display': _displayMode.name,
    'icon': _iconTheme.name,
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
    'recoveryQueue': _recoveryQueue
        .map((track) => track.toSessionJson())
        .toList(),
    'recoveryCurrent': _recoveryCurrentId,
    'recoveryPositionMs': _recoveryPosition.inMilliseconds,
  };

  void _applyJson(Map<String, dynamic> json) {
    final outputs = (json['outputs'] as List?)
        ?.map(
          (item) =>
              OutputProfile.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList();
    if (outputs != null && outputs.isNotEmpty) {
      _outputProfiles
        ..clear()
        ..addAll(outputs);
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
    final snapshot = jsonEncode(toJson());
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

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _statsSaveTimer?.cancel();
    super.dispose();
  }
}
