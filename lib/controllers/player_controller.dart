import 'dart:async';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/track.dart';
import '../models/phase_three_models.dart';
import '../services/home_widget_service.dart';
import '../services/media_session_item_factory.dart';

enum PlaybackRepeatMode { off, all, one }

/// One UI-facing contract for both real device audio and the offline demo.
class PlayerController extends ChangeNotifier {
  PlayerController(List<Track> library)
    : _queue = List<Track>.from(library),
      _current = library.first {
    _bindNativePlayer();
  }

  final Random _random = Random();
  final Set<String> _favoriteIds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _ticker;
  Timer? _recoveryLoadTimer;
  Timer? _widgetDebounce;
  int _nativeLoadGeneration = 0;
  int _queueRevision = 0;
  Future<void> _nativeLoadQueue = Future<void>.value();
  String? _loadedTrackId;
  List<String> _nativePlaylistTrackIds = const [];
  bool _nativePlaylistReady = false;
  String? _appliedOutputProfileId;
  double? _appliedOutputProfileVolume;
  List<Track> _queue;
  Track _current;
  Duration _position = Duration.zero;
  Duration _lastStatsPosition = Duration.zero;
  Duration? _loopA;
  Duration? _loopB;
  bool _isPlaying = false;
  bool _playRequested = false;
  bool _shuffle = false;
  bool _usingNativeAudio = false;
  bool _autoPauseOnDisconnect = true;
  bool _autoResumeOnReconnect = false;
  bool _silenceCalibration = false;
  bool _replayGainEnabled = true;
  bool _monoDownmix = false;
  bool _bitPerfectRequested = false;
  String _outputProfileName = 'This phone';
  AudioFocusBehavior _audioFocusBehavior = AudioFocusBehavior.pause;
  bool _stopAfterCurrentTrack = false;
  bool _stopAfterQueue = false;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.off;
  double _speed = 1;
  double _volume = .82;
  double _volumeLimit = .85;
  double _crossfade = 4;
  String? _playbackError;
  Duration? Function(String trackId)? resumePositionResolver;
  ValueChanged<Track>? onTrackStarted;
  void Function(String trackId, Duration elapsed)? onListening;
  ValueChanged<Set<String>>? onFavoritesChanged;
  ValueChanged<double>? onVolumeChanged;

  Track get current => _current;
  List<Track> get queue => List.unmodifiable(_queue);
  Duration get position => _position;
  Duration? get loopA => _loopA;
  Duration? get loopB => _loopB;
  bool get isPlaying => _isPlaying;
  bool get shuffle => _shuffle;
  bool get usingNativeAudio => _usingNativeAudio;
  PlaybackRepeatMode get repeatMode => _repeatMode;
  double get speed => _speed;
  double get volume => _volume;
  double get volumeLimit => _volumeLimit;
  double get crossfade => _crossfade;
  String? get playbackError => _playbackError;
  bool get monoDownmix => _monoDownmix;
  bool get bitPerfectRequested => _bitPerfectRequested;
  bool get bitPerfectActive =>
      _bitPerfectRequested && _current.isLossless && speed == 1;
  String get outputProfileName => _outputProfileName;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  int get queueRevision => _queueRevision;

  bool isFavorite(Track track) => _favoriteIds.contains(track.id);

  void replaceLibrary(
    List<Track> tracks, {
    bool playFirst = false,
    bool preserveQueue = true,
  }) {
    if (tracks.isEmpty) {
      _nativeLoadGeneration++;
      _loadedTrackId = null;
      _nativePlaylistReady = false;
      _nativePlaylistTrackIds = const [];
      _ticker?.cancel();
      _recoveryLoadTimer?.cancel();
      _queue = const [Track.empty];
      _queueRevision++;
      _current = Track.empty;
      _position = Duration.zero;
      _lastStatsPosition = Duration.zero;
      _isPlaying = false;
      _playRequested = false;
      _usingNativeAudio = false;
      _playbackError = null;
      _loopA = null;
      _loopB = null;
      unawaited(_audioPlayer.stop());
      notifyListeners();
      return;
    }
    if (playFirst) {
      playTrack(tracks.first, from: tracks);
      return;
    }
    final byId = {for (final track in tracks) track.id: track};
    final refreshedCurrent = byId[_current.id];
    if (refreshedCurrent != null) {
      _current = refreshedCurrent;
      _queue = preserveQueue
          ? _queue.map((track) => byId[track.id]).whereType<Track>().toList()
          : List<Track>.from(tracks);
      if (_queue.isEmpty) _queue = [refreshedCurrent];
    } else {
      _nativeLoadGeneration++;
      _loadedTrackId = null;
      _nativePlaylistReady = false;
      _ticker?.cancel();
      _recoveryLoadTimer?.cancel();
      unawaited(_audioPlayer.stop());
      _queue = List<Track>.from(tracks);
      _current = tracks.first;
      _position = Duration.zero;
      _lastStatsPosition = Duration.zero;
      _isPlaying = false;
      _playRequested = false;
      _playbackError = null;
      _loopA = null;
      _loopB = null;
      _usingNativeAudio = _current.isDeviceTrack;
      if (_usingNativeAudio) {
        final generation = ++_nativeLoadGeneration;
        _queueNativeTrackLoad(_current, generation: generation);
      }
    }
    _queueRevision++;
    notifyListeners();
  }

  void updateTrack(Track updated) {
    final index = _queue.indexWhere((track) => track.id == updated.id);
    if (index >= 0) {
      _queue[index] = updated;
      _queueRevision++;
    }
    if (_current.id == updated.id) _current = updated;
    notifyListeners();
  }

  void playTrack(Track track, {List<Track>? from, Duration? initialPosition}) {
    _recoveryLoadTimer?.cancel();
    if (from != null && from.isNotEmpty) {
      _queue = List<Track>.from(from);
      _queueRevision++;
    }
    final canSeekLoadedPlaylist =
        track.isDeviceTrack && _nativePlaylistMatchesQueue();
    final isTrackChange = _current.id != track.id;
    if (isTrackChange) _speed = 1;
    final loadGeneration = ++_nativeLoadGeneration;
    _loadedTrackId = null;
    _current = track;
    final startPosition =
        initialPosition ??
        resumePositionResolver?.call(track.id) ??
        Duration.zero;
    _position = startPosition;
    _isPlaying = true;
    _playRequested = true;
    _playbackError = null;
    _loopA = null;
    _loopB = null;
    _lastStatsPosition = startPosition;
    onTrackStarted?.call(track);
    if (track.isDeviceTrack) {
      _ticker?.cancel();
      _usingNativeAudio = true;
      if (canSeekLoadedPlaylist) {
        _queueNativePlaylistSeek(
          track,
          generation: loadGeneration,
          position: startPosition,
        );
      } else {
        _nativePlaylistReady = false;
        _queueNativeTrackLoad(track, generation: loadGeneration);
      }
    } else {
      _usingNativeAudio = false;
      _loadedTrackId = null;
      _startTicker();
    }
    notifyListeners();
  }

  void togglePlay() {
    _isPlaying = !_isPlaying;
    _playRequested = _isPlaying;
    if (_usingNativeAudio) {
      if (_loadedTrackId == _current.id) {
        unawaited(_isPlaying ? _audioPlayer.play() : _audioPlayer.pause());
      }
    } else if (_isPlaying) {
      _startTicker();
    } else {
      _ticker?.cancel();
    }
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _playRequested = false;
    _ticker?.cancel();
    if (_usingNativeAudio) unawaited(_audioPlayer.pause());
    notifyListeners();
  }

  void retryCurrent() {
    if (_current.isEmpty) return;
    playTrack(_current, from: _queue, initialPosition: _position);
  }

  void seek(Duration value) {
    _position = Duration(
      milliseconds: value.inMilliseconds.clamp(
        0,
        _current.duration.inMilliseconds,
      ),
    );
    if (_usingNativeAudio && _loadedTrackId == _current.id) {
      unawaited(_audioPlayer.seek(_position));
    }
    notifyListeners();
  }

  void markLoopA() {
    _loopA = _position;
    if (_loopB != null && _loopB! <= _loopA!) _loopB = null;
    notifyListeners();
  }

  void markLoopB() {
    if (_loopA == null || _position <= _loopA!) return;
    _loopB = _position;
    notifyListeners();
  }

  void clearLoop() {
    _loopA = null;
    _loopB = null;
    notifyListeners();
  }

  void next() => _advanceToNext(fromCompletion: false);

  void _advanceToNext({required bool fromCompletion}) {
    if (_queue.isEmpty || _current.isEmpty) return;
    if (fromCompletion && _repeatMode == PlaybackRepeatMode.one) {
      playTrack(_current, initialPosition: Duration.zero);
      return;
    }
    final index = _queue.indexWhere((track) => track.id == _current.id);
    if (!_shuffle &&
        index == _queue.length - 1 &&
        _repeatMode == PlaybackRepeatMode.off) {
      _stopAtQueueEnd();
      return;
    }
    final nextIndex = _shuffle
        ? _random.nextInt(_queue.length)
        : (index < 0 ? 0 : index + 1) % _queue.length;
    playTrack(_queue[nextIndex]);
  }

  void _stopAtQueueEnd() {
    _isPlaying = false;
    _playRequested = false;
    _ticker?.cancel();
    if (_usingNativeAudio && _loadedTrackId == _current.id) {
      unawaited(_audioPlayer.pause());
    }
    notifyListeners();
  }

  void previous() {
    if (_position > const Duration(seconds: 4)) {
      seek(Duration.zero);
      return;
    }
    final index = _queue.indexWhere((track) => track.id == _current.id);
    playTrack(_queue[(index - 1 + _queue.length) % _queue.length]);
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_usingNativeAudio && _loadedTrackId == _current.id) {
      unawaited(_audioPlayer.setShuffleModeEnabled(_shuffle));
    }
    notifyListeners();
  }

  void cycleRepeat() {
    _repeatMode = PlaybackRepeatMode
        .values[(_repeatMode.index + 1) % PlaybackRepeatMode.values.length];
    if (_usingNativeAudio && _loadedTrackId == _current.id) {
      unawaited(_applyNativeRepeatMode());
    }
    notifyListeners();
  }

  void toggleFavorite(Track track) {
    if (!_favoriteIds.add(track.id)) _favoriteIds.remove(track.id);
    onFavoritesChanged?.call(Set<String>.from(_favoriteIds));
    notifyListeners();
  }

  void restoreFavorites(Iterable<String> trackIds) {
    _favoriteIds
      ..clear()
      ..addAll(trackIds);
    notifyListeners();
  }

  void setSpeed(double value) {
    _speed = value.clamp(.5, 2);
    if (_usingNativeAudio && _loadedTrackId == _current.id) {
      unawaited(_audioPlayer.setSpeed(_speed));
    }
    notifyListeners();
  }

  void setVolume(double value) {
    _volume = value.clamp(0, _volumeLimit);
    unawaited(_applyNativeVolume());
    onVolumeChanged?.call(_volume);
    notifyListeners();
  }

  void setVolumeLimit(double value) {
    _volumeLimit = value.clamp(.2, 1);
    if (_volume > _volumeLimit) _volume = _volumeLimit;
    unawaited(_applyNativeVolume());
    notifyListeners();
  }

  void configureAudioEnvironment({
    required bool autoPauseOnDisconnect,
    required bool autoResumeOnReconnect,
    required bool silenceCalibration,
    required bool replayGain,
    AudioFocusBehavior audioFocusBehavior = AudioFocusBehavior.pause,
  }) {
    _autoPauseOnDisconnect = autoPauseOnDisconnect;
    _autoResumeOnReconnect = autoResumeOnReconnect;
    _silenceCalibration = silenceCalibration;
    _replayGainEnabled = replayGain;
    _audioFocusBehavior = audioFocusBehavior;
    unawaited(_audioPlayer.setSkipSilenceEnabled(silenceCalibration));
    unawaited(_applyNativeVolume());
  }

  void applyOutputProfile(OutputProfile profile) {
    final outputChanged = _appliedOutputProfileId != profile.id;
    final rememberedVolumeChanged =
        _appliedOutputProfileVolume != profile.volume;
    final presentationChanged =
        _outputProfileName != profile.name ||
        _monoDownmix != profile.monoDownmix ||
        _bitPerfectRequested != profile.bitPerfectRequested;
    if (!outputChanged && !rememberedVolumeChanged && !presentationChanged) {
      return;
    }

    _appliedOutputProfileId = profile.id;
    _appliedOutputProfileVolume = profile.volume;
    _outputProfileName = profile.name;
    _monoDownmix = profile.monoDownmix;
    _bitPerfectRequested = profile.bitPerfectRequested;
    if (outputChanged || rememberedVolumeChanged) {
      _volume = profile.volume.clamp(0, _volumeLimit);
      unawaited(_applyNativeVolume());
    }
    notifyListeners();
  }

  void restoreSession({
    required List<Track> queue,
    required String currentId,
    required Duration position,
  }) {
    if (queue.isEmpty) return;
    _queue = List<Track>.from(queue);
    _queueRevision++;
    final recoveredCurrent = queue.where((track) => track.id == currentId);
    final restoredExactTrack = recoveredCurrent.isNotEmpty;
    _current = restoredExactTrack ? recoveredCurrent.first : queue.first;
    _position = restoredExactTrack
        ? position < Duration.zero
              ? Duration.zero
              : position > _current.duration
              ? _current.duration
              : position
        : Duration.zero;
    _lastStatsPosition = _position;
    _isPlaying = false;
    _playRequested = false;
    _loadedTrackId = null;
    _nativePlaylistReady = false;
    _usingNativeAudio = _current.isDeviceTrack;
    if (_usingNativeAudio) {
      _recoveryLoadTimer?.cancel();
      final loadGeneration = ++_nativeLoadGeneration;
      _recoveryLoadTimer = Timer(
        const Duration(milliseconds: 900),
        () => _queueNativeTrackLoad(_current, generation: loadGeneration),
      );
    }
    notifyListeners();
  }

  void configureSleepStop({
    required bool afterCurrentTrack,
    required bool afterQueue,
  }) {
    _stopAfterCurrentTrack = afterCurrentTrack;
    _stopAfterQueue = afterQueue;
    if (_usingNativeAudio && _loadedTrackId == _current.id) {
      unawaited(_applyNativeRepeatMode());
    }
  }

  void setCrossfade(double value) {
    _crossfade = value;
    notifyListeners();
  }

  void addNext(Track track) {
    _queue.removeWhere((item) => item.id == track.id);
    final index = _queue.indexWhere((item) => item.id == _current.id);
    _queue.insert(index + 1, track);
    _queueRevision++;
    _reloadNativePlaylistPreservingState();
    notifyListeners();
  }

  void removeFromQueue(Track track) {
    if (_queue.length == 1 || track.id == _current.id) return;
    _queue.removeWhere((item) => item.id == track.id);
    _queueRevision++;
    _reloadNativePlaylistPreservingState();
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    _queueRevision++;
    _reloadNativePlaylistPreservingState();
    notifyListeners();
  }

  Future<void> _loadNativeTrack(Track track, {required int generation}) async {
    try {
      final nativeTracks = _queue.where((item) => item.isDeviceTrack).toList();
      final initialIndex = nativeTracks.indexWhere(
        (item) => item.id == track.id,
      );
      if (initialIndex < 0) {
        throw StateError('The selected track is not in the playable queue.');
      }
      final sources = nativeTracks.map(_audioSourceForTrack).toList();
      final loadPosition = _position > track.duration
          ? track.duration
          : _position;
      _nativePlaylistTrackIds = nativeTracks.map((item) => item.id).toList();
      await _audioPlayer.setAudioSources(
        sources,
        initialIndex: initialIndex,
        initialPosition: loadPosition,
      );
      if (!_isLatestNativeLoad(track, generation)) return;
      _nativePlaylistReady = true;
      final pendingPosition = _position > track.duration
          ? track.duration
          : _position;
      if (pendingPosition != loadPosition) {
        await _audioPlayer.seek(pendingPosition);
        if (!_isLatestNativeLoad(track, generation)) return;
      }
      _loadedTrackId = track.id;
      await _audioPlayer.setSpeed(_speed);
      if (!_isLatestNativeLoad(track, generation)) return;
      await _audioPlayer.setShuffleModeEnabled(_shuffle);
      if (!_isLatestNativeLoad(track, generation)) return;
      await _applyNativeRepeatMode();
      if (!_isLatestNativeLoad(track, generation)) return;
      await _audioPlayer.setSkipSilenceEnabled(_silenceCalibration);
      if (!_isLatestNativeLoad(track, generation)) return;
      await _applyNativeVolume();
      if (_playRequested && _isLatestNativeLoad(track, generation)) {
        unawaited(_startNativePlayback(track, generation));
      }
    } catch (error) {
      if (!_isLatestNativeLoad(track, generation)) return;
      _nativePlaylistReady = false;
      _isPlaying = false;
      _playRequested = false;
      _loadedTrackId = null;
      _playbackError = 'Could not play ${track.title}: $error';
      notifyListeners();
    }
  }

  AudioSource _audioSourceForTrack(Track track) {
    final rawUri = track.sourceUri;
    final uri = rawUri != null ? Uri.parse(rawUri) : Uri.file(track.filePath!);
    final mediaItem = MediaSessionItemFactory.fromTrack(track);
    final baseSource = AudioSource.uri(uri, tag: mediaItem);
    return track.cueStart == null
        ? baseSource
        : ClippingAudioSource(
            child: baseSource,
            start: track.cueStart,
            end: track.cueEnd,
            tag: mediaItem,
            duration: track.duration,
          );
  }

  bool _nativePlaylistMatchesQueue() =>
      _nativePlaylistReady &&
      listEquals(
        _nativePlaylistTrackIds,
        _queue
            .where((track) => track.isDeviceTrack)
            .map((track) => track.id)
            .toList(),
      );

  void _queueNativePlaylistSeek(
    Track track, {
    required int generation,
    required Duration position,
  }) {
    _nativeLoadQueue = _nativeLoadQueue.then((_) async {
      if (!_isLatestNativeLoad(track, generation)) return;
      final index = _nativePlaylistTrackIds.indexOf(track.id);
      if (!_nativePlaylistReady || index < 0) {
        await _loadNativeTrack(track, generation: generation);
        return;
      }
      try {
        await _audioPlayer.seek(position, index: index);
        if (!_isLatestNativeLoad(track, generation)) return;
        _loadedTrackId = track.id;
        await _audioPlayer.setSpeed(_speed);
        if (!_isLatestNativeLoad(track, generation)) return;
        await _applyNativeVolume();
        if (_playRequested && _isLatestNativeLoad(track, generation)) {
          unawaited(_startNativePlayback(track, generation));
        }
        notifyListeners();
      } catch (_) {
        if (!_isLatestNativeLoad(track, generation)) return;
        _nativePlaylistReady = false;
        await _loadNativeTrack(track, generation: generation);
      }
    });
    unawaited(_nativeLoadQueue);
  }

  void _reloadNativePlaylistPreservingState() {
    if (!_usingNativeAudio || _current.isEmpty || !_current.isDeviceTrack) {
      return;
    }
    _loadedTrackId = null;
    _nativePlaylistReady = false;
    final generation = ++_nativeLoadGeneration;
    _queueNativeTrackLoad(_current, generation: generation);
  }

  bool _isLatestNativeLoad(Track track, int generation) =>
      generation == _nativeLoadGeneration && _current.id == track.id;

  Future<void> _startNativePlayback(Track track, int generation) async {
    try {
      await _audioPlayer.play();
    } catch (error) {
      if (!_isLatestNativeLoad(track, generation)) return;
      _isPlaying = false;
      _playRequested = false;
      _playbackError = 'Could not play ${track.title}: $error';
      notifyListeners();
    }
  }

  void _queueNativeTrackLoad(Track track, {required int generation}) {
    _nativeLoadQueue = _nativeLoadQueue.then((_) async {
      if (!_isLatestNativeLoad(track, generation)) return;
      await _loadNativeTrack(track, generation: generation);
    });
    unawaited(_nativeLoadQueue);
  }

  Future<void> _applyNativeVolume() async {
    final gainDb = _replayGainEnabled ? (_current.replayGainDb ?? 0) : 0;
    final replayScale = pow(10, gainDb / 20).toDouble();
    await _audioPlayer.setVolume(
      (_volume * replayScale).clamp(0, _volumeLimit),
    );
  }

  Future<void> _applyNativeRepeatMode() => _audioPlayer.setLoopMode(
    _stopAfterCurrentTrack || _stopAfterQueue
        ? LoopMode.off
        : switch (_repeatMode) {
            PlaybackRepeatMode.off => LoopMode.off,
            PlaybackRepeatMode.all => LoopMode.all,
            PlaybackRepeatMode.one => LoopMode.one,
          },
  );

  void _bindNativePlayer() {
    _subscriptions.add(
      _audioPlayer.currentIndexStream.listen(_handleNativeIndexChange),
    );
    _subscriptions.add(
      _audioPlayer.positionStream.listen((value) {
        if (!_usingNativeAudio || _loadedTrackId != _current.id) return;
        _position = value;
        final statsDelta = value - _lastStatsPosition;
        if (_isPlaying &&
            statsDelta > Duration.zero &&
            statsDelta <= const Duration(seconds: 3)) {
          onListening?.call(_current.id, statsDelta);
        }
        _lastStatsPosition = value;
        if (_loopA != null && _loopB != null && value >= _loopB!) {
          unawaited(_audioPlayer.seek(_loopA!));
        }
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _audioPlayer.playerStateStream.listen((state) {
        if (!_usingNativeAudio || _loadedTrackId != _current.id) return;
        // Once a source is loaded the media session is authoritative. This
        // keeps lock-screen, notification, headset and in-app buttons in sync.
        _isPlaying = state.playing;
        _playRequested = state.playing;
        if (state.processingState == ProcessingState.completed) {
          final currentIndex = _queue.indexWhere(
            (track) => track.id == _current.id,
          );
          final atQueueEnd = currentIndex == _queue.length - 1;
          if (_stopAfterCurrentTrack || (_stopAfterQueue && atQueueEnd)) {
            _playRequested = false;
            _isPlaying = false;
            _stopAfterCurrentTrack = false;
            _stopAfterQueue = false;
            unawaited(_applyNativeRepeatMode());
          } else {
            _advanceToNext(fromCompletion: true);
          }
        }
        notifyListeners();
      }),
    );
    unawaited(_configureSession());
  }

  void _handleNativeIndexChange(int? index) {
    if (!_usingNativeAudio ||
        _loadedTrackId == null ||
        index == null ||
        index < 0 ||
        index >= _nativePlaylistTrackIds.length) {
      return;
    }
    final trackId = _nativePlaylistTrackIds[index];
    if (trackId == _current.id) return;
    final matches = _queue.where((track) => track.id == trackId);
    if (matches.isEmpty) return;

    if (_stopAfterCurrentTrack) {
      _stopAfterCurrentTrack = false;
      _playRequested = false;
      _isPlaying = false;
      unawaited(_audioPlayer.pause());
      unawaited(_applyNativeRepeatMode());
    }

    _current = matches.first;
    _loadedTrackId = trackId;
    _position = Duration.zero;
    _lastStatsPosition = Duration.zero;
    _loopA = null;
    _loopB = null;
    _playbackError = null;
    if (_speed != 1) {
      _speed = 1;
      unawaited(_audioPlayer.setSpeed(1));
    }
    unawaited(_applyNativeVolume());
    onTrackStarted?.call(_current);
    notifyListeners();
  }

  Future<void> _configureSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _subscriptions.add(
        session.becomingNoisyEventStream.listen((_) {
          if (_autoPauseOnDisconnect) pause();
        }),
      );
      _subscriptions.add(
        session.interruptionEventStream.listen((event) {
          if (_audioFocusBehavior == AudioFocusBehavior.ignore) return;
          if (event.begin) {
            if (_audioFocusBehavior == AudioFocusBehavior.duck) {
              unawaited(_audioPlayer.setVolume((_volume * .25).clamp(0, 1)));
            } else {
              pause();
            }
          } else {
            if (_audioFocusBehavior == AudioFocusBehavior.duck) {
              unawaited(_applyNativeVolume());
            } else if (_autoResumeOnReconnect && !_isPlaying) {
              togglePlay();
            }
          }
        }),
      );
    } catch (_) {
      // The demo and widget tests can operate without a native audio session.
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _recoveryLoadTimer?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPlaying) return;
      final nextPosition =
          _position + Duration(milliseconds: (1000 * _speed).round());
      if (_loopA != null && _loopB != null && nextPosition >= _loopB!) {
        _position = _loopA!;
      } else if (nextPosition >= _current.duration) {
        final currentIndex = _queue.indexWhere(
          (track) => track.id == _current.id,
        );
        final atQueueEnd = currentIndex == _queue.length - 1;
        if (_stopAfterCurrentTrack || (_stopAfterQueue && atQueueEnd)) {
          _stopAfterCurrentTrack = false;
          _stopAfterQueue = false;
          _stopAtQueueEnd();
        } else {
          _advanceToNext(fromCompletion: true);
        }
      } else {
        _position = nextPosition;
        onListening?.call(_current.id, const Duration(seconds: 1));
        notifyListeners();
      }
    });
  }

  void _syncHomeWidget() {
    if (_widgetDebounce?.isActive == true) return;
    _widgetDebounce = Timer(
      const Duration(seconds: 1),
      () => unawaited(
        HomeWidgetService.update(
          track: _current,
          position: _position,
          playing: _isPlaying,
        ),
      ),
    );
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _syncHomeWidget();
  }

  @override
  void dispose() {
    _nativeLoadGeneration++;
    _ticker?.cancel();
    _recoveryLoadTimer?.cancel();
    _widgetDebounce?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }
}
