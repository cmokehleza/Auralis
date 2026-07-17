import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

class BatterySample {
  const BatterySample({
    required this.at,
    required this.level,
    required this.playing,
  });
  final DateTime at;
  final int level;
  final bool playing;
}

class BatteryProfileService extends ChangeNotifier {
  final Battery _battery = Battery();
  final List<BatterySample> _samples = [];
  Timer? _timer;

  bool get running => _timer != null;
  List<BatterySample> get samples => List.unmodifiable(_samples);

  Future<void> start({required bool Function() isPlaying}) async {
    if (running) return;
    await _sample(isPlaying());
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _sample(isPlaying()),
    );
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  Future<void> _sample(bool playing) async {
    try {
      _samples.add(
        BatterySample(
          at: DateTime.now(),
          level: await _battery.batteryLevel,
          playing: playing,
        ),
      );
      if (_samples.length > 720) _samples.removeAt(0);
      notifyListeners();
    } catch (_) {
      // Battery APIs are optional on desktop/test hosts.
    }
  }

  String buildReport() {
    if (_samples.length < 2) return 'Not enough samples yet.';
    final first = _samples.first;
    final last = _samples.last;
    final elapsed = last.at.difference(first.at);
    final drain = first.level - last.level;
    final active = _samples.where((sample) => sample.playing).length;
    return 'Samples: ${_samples.length}\nElapsed: ${elapsed.inMinutes} min\n'
        'Battery change: -$drain%\nPlaying samples: $active';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
