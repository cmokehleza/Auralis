import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'controllers/phase_three_controller.dart';
import 'controllers/phase_two_controller.dart';
import 'controllers/player_controller.dart';
import 'l10n/app_localizations.dart';
import 'models/track.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/device_library_service.dart';
import 'services/library_repository.dart';
import 'services/notification_artwork_service.dart';
import 'services/phase_three_services.dart';
import 'theme/app_motion.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationArtworkService.prepareFallback();
  await JustAudioBackground.init(
    androidResumeOnClick: true,
    androidNotificationChannelId: 'com.auralis.player.audio',
    androidNotificationChannelName: 'Auralis playback',
    androidNotificationChannelDescription:
        'Playback controls and information for the current song',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: false,
    androidStopForegroundOnPause: false,
    androidNotificationIcon: 'drawable/ic_stat_auralis',
    notificationColor: const Color(0xFF68D7FF),
    artDownscaleWidth: 512,
    artDownscaleHeight: 512,
  );
  runApp(const AuralisApp());
}

class AuralisApp extends StatefulWidget {
  const AuralisApp({super.key, this.useDemoLibrary = false});

  final bool useDemoLibrary;

  @override
  State<AuralisApp> createState() => _AuralisAppState();
}

class _AuralisAppState extends State<AuralisApp> {
  late final PlayerController _player;
  late final PhaseTwoController _phaseTwo;
  late final PhaseThreeController _phaseThree;
  late final PhaseThreeServices _services;
  Timer? _checkpointTimer;
  Timer? _volumeMemoryTimer;
  int _lastRecoveryQueueRevision = -1;
  String? _lastRecoveryTrackId;
  String? _lastPositionCheckpointTrackId;
  int? _lastPositionCheckpointSecond;
  Duration? _lastObservedPosition;
  bool _lastPlaybackWasPlaying = false;
  bool _recoveryReady = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.useDemoLibrary && LibraryRepository.tracks.isEmpty) {
      LibraryRepository.loadDemoLibrary();
    }
    _player = PlayerController(
      LibraryRepository.tracks.isEmpty
          ? const [Track.empty]
          : LibraryRepository.tracks,
    );
    _phaseTwo = PhaseTwoController()..addListener(_applySettings);
    _phaseThree = PhaseThreeController()..addListener(_applySettings);
    _services = PhaseThreeServices();
    _services.largeLibrary.replace(LibraryRepository.tracks);
    unawaited(
      _services.outputDetection.start((profileId) {
        _phaseThree.selectOutput(profileId);
        _player.applyOutputProfile(_phaseThree.activeOutput);
      }),
    );
    _player
      ..resumePositionResolver = _phaseTwo.resumePositionFor
      ..onTrackStarted = _phaseThree.recordTrackStarted
      ..onListening = _phaseThree.recordListening
      ..onFavoritesChanged = _phaseTwo.setFavoriteIds
      ..onVolumeChanged = _rememberVolume
      ..addListener(_checkpointPlayer);
    unawaited(_restore());
  }

  Future<void> _restore() async {
    await Future.wait([_phaseTwo.restore(), _phaseThree.restore()]);
    _player.restoreFavorites(_phaseTwo.favoriteIds);
    var liveTracks = <Track>[];
    var libraryScanSucceeded = false;
    if (_phaseThree.onboardingComplete) {
      final result = await DeviceLibraryService().scan(
        requestPermission: false,
      );
      libraryScanSucceeded = result.permissionGranted && result.error == null;
      if (libraryScanSucceeded) {
        liveTracks = result.tracks;
        LibraryRepository.replaceWithDeviceTracks(liveTracks);
        _services.largeLibrary.replace(liveTracks);
        _player.replaceLibrary(liveTracks);
      }
    }
    if (_phaseThree.hasRecoverySession) {
      final recovery = liveTracks.isNotEmpty
          ? () {
              final byId = {for (final track in liveTracks) track.id: track};
              return _phaseThree.recoveryQueue
                  .map((track) => byId[track.id])
                  .whereType<Track>()
                  .toList();
            }()
          : libraryScanSucceeded
          ? <Track>[]
          : _phaseThree.recoveryQueue;
      final queue = recovery.isEmpty ? liveTracks : recovery;
      if (queue.isNotEmpty) {
        _player.restoreSession(
          queue: queue,
          currentId: _phaseThree.recoveryCurrentId!,
          position: _phaseThree.recoveryPosition,
        );
      }
    }
    _applySettings();
    _recoveryReady = true;
    _checkpointPlayer();
    _checkpointTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkpointPosition(),
    );
    if (mounted) setState(() => _ready = true);
  }

  void _applySettings() {
    _player
      ..setVolumeLimit(_phaseTwo.volumeLimit)
      ..configureAudioEnvironment(
        autoPauseOnDisconnect: _phaseTwo.autoPauseOnDisconnect,
        autoResumeOnReconnect: _phaseTwo.autoResumeOnReconnect,
        silenceCalibration: _phaseTwo.silenceCalibration,
        replayGain: _phaseTwo.replayGain,
        audioFocusBehavior: _phaseThree.audioFocusBehavior,
      )
      ..applyOutputProfile(_phaseThree.activeOutput);
    if (_phaseThree.batteryProfilerEnabled) {
      unawaited(
        _services.batteryProfile.start(isPlaying: () => _player.isPlaying),
      );
    } else {
      _services.batteryProfile.stop();
    }
  }

  void _checkpointPlayer() {
    if (!_recoveryReady || _player.current.isEmpty) return;
    final currentId = _player.current.id;
    final currentPosition = _player.position;
    final queueChanged = _lastRecoveryQueueRevision != _player.queueRevision;
    final trackChanged = _lastRecoveryTrackId != currentId;
    final recoveryTrackMissing =
        !queueChanged &&
        trackChanged &&
        !_phaseThree.recoveryQueue.any((track) => track.id == currentId);
    final playbackStopped = _lastPlaybackWasPlaying && !_player.isPlaying;
    final positionJumped =
        !trackChanged &&
        _lastObservedPosition != null &&
        (currentPosition - _lastObservedPosition!).abs() >=
            const Duration(seconds: 5);

    _lastRecoveryQueueRevision = _player.queueRevision;
    _lastRecoveryTrackId = currentId;
    _lastPlaybackWasPlaying = _player.isPlaying;
    _lastObservedPosition = currentPosition;

    if (queueChanged || recoveryTrackMissing) {
      _phaseThree.saveRecoverySession(
        queue: _player.queue,
        currentId: currentId,
        position: currentPosition,
        screenIndex: _phaseThree.lastScreenIndex,
      );
      _rememberPositionCheckpoint(currentId, currentPosition);
    } else if (trackChanged || playbackStopped || positionJumped) {
      _savePositionCheckpoint(currentId, currentPosition);
    }
  }

  void _checkpointPosition() {
    if (!_recoveryReady || _player.current.isEmpty) return;
    final currentId = _player.current.id;
    final position = _player.position;
    if (_lastPositionCheckpointTrackId == currentId &&
        _lastPositionCheckpointSecond == position.inSeconds) {
      return;
    }
    _savePositionCheckpoint(currentId, position);
  }

  void _savePositionCheckpoint(String currentId, Duration position) {
    _rememberPositionCheckpoint(currentId, position);
    unawaited(_phaseThree.saveRecoveryPosition(currentId, position));
  }

  void _rememberPositionCheckpoint(String currentId, Duration position) {
    _lastPositionCheckpointTrackId = currentId;
    _lastPositionCheckpointSecond = position.inSeconds;
  }

  void _rememberVolume(double volume) {
    _volumeMemoryTimer?.cancel();
    _volumeMemoryTimer = Timer(const Duration(milliseconds: 450), () {
      final active = _phaseThree.activeOutput;
      if ((active.volume - volume).abs() < .001) return;
      _phaseThree.updateOutput(active.copyWith(volume: volume));
    });
  }

  @override
  void dispose() {
    _checkpointTimer?.cancel();
    _volumeMemoryTimer?.cancel();
    _player
      ..removeListener(_checkpointPlayer)
      ..dispose();
    _phaseTwo
      ..removeListener(_applySettings)
      ..dispose();
    _phaseThree
      ..removeListener(_applySettings)
      ..dispose();
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_phaseTwo, _phaseThree]),
    builder: (context, _) => MaterialApp(
      title: 'Auralis Music Player',
      debugShowCheckedModeBanner: false,
      locale: Locale(_phaseThree.localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme:
          AppTheme.light(
            accent: _phaseTwo.accent,
            highContrast: _phaseTwo.highContrast,
          ).copyWith(
            materialTapTargetSize: _phaseThree.largeTapTargets
                ? MaterialTapTargetSize.padded
                : MaterialTapTargetSize.shrinkWrap,
            visualDensity: _phaseThree.largeTapTargets
                ? const VisualDensity(horizontal: 1, vertical: 1)
                : VisualDensity.standard,
          ),
      darkTheme:
          AppTheme.dark(
            accent: _phaseTwo.accent,
            highContrast: _phaseTwo.highContrast,
          ).copyWith(
            materialTapTargetSize: _phaseThree.largeTapTargets
                ? MaterialTapTargetSize.padded
                : MaterialTapTargetSize.shrinkWrap,
            visualDensity: _phaseThree.largeTapTargets
                ? const VisualDensity(horizontal: 1, vertical: 1)
                : VisualDensity.standard,
          ),
      themeMode: _phaseTwo.themeMode,
      home: Builder(
        builder: (context) {
          final Widget destination;
          if (!_ready) {
            destination = const BrandSplash(key: ValueKey('brand-splash'));
          } else if (!_phaseThree.onboardingComplete) {
            destination = OnboardingScreen(
              key: const ValueKey('onboarding'),
              onComplete: _phaseThree.completeOnboarding,
              onScan: () async {
                final result = await _services.largeLibrary
                    .rescanInBackground();
                if (result.permissionGranted && result.error == null) {
                  LibraryRepository.replaceWithDeviceTracks(result.tracks);
                  _player.replaceLibrary(result.tracks);
                }
                return result.tracks.length;
              },
            );
          } else {
            destination = AppShell(
              key: const ValueKey('app-shell'),
              player: _player,
              phaseTwo: _phaseTwo,
              phaseThree: _phaseThree,
              services: _services,
            );
          }
          return AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.standard),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .012),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: destination,
          );
        },
      ),
    ),
  );
}
