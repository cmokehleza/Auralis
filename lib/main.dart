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
import 'services/phase_three_services.dart';
import 'theme/app_motion.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.auralis.player.audio',
    androidNotificationChannelName: 'Auralis playback',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
    androidNotificationIcon: 'drawable/ic_stat_auralis',
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
      ..addListener(_checkpointPlayer);
    unawaited(_restore());
  }

  Future<void> _restore() async {
    await Future.wait([_phaseTwo.restore(), _phaseThree.restore()]);
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
    if (_player.current.isEmpty) return;
    if (_checkpointTimer?.isActive == true) return;
    _checkpointTimer = Timer(const Duration(seconds: 3), () {
      _phaseThree.saveRecoverySession(
        queue: _player.queue,
        currentId: _player.current.id,
        position: _player.position,
        screenIndex: _phaseThree.lastScreenIndex,
      );
    });
  }

  @override
  void dispose() {
    _checkpointTimer?.cancel();
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
                if (result.tracks.isNotEmpty) {
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
