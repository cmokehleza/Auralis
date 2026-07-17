import 'dart:async';

import 'package:audio_session/audio_session.dart';

class AudioOutputDetectionService {
  StreamSubscription<Set<AudioDevice>>? _subscription;

  Future<void> start(void Function(String profileId) onProfile) async {
    try {
      final session = await AudioSession.instance;
      _subscription = session.devicesStream.listen(
        (devices) => onProfile(_profileFor(devices)),
      );
      onProfile(_profileFor(await session.getDevices(includeInputs: false)));
    } catch (_) {
      // Device enumeration is optional on unsupported desktop/test hosts.
    }
  }

  String _profileFor(Set<AudioDevice> devices) {
    final outputs = devices.where((device) => device.isOutput).toList();
    if (outputs.any((device) => device.type.name == 'usbAudio')) {
      return 'usb-dac';
    }
    if (outputs.any(
      (device) =>
          device.type.name == 'carAudio' ||
          device.name.toLowerCase().contains('car') ||
          device.name.toLowerCase().contains('auto'),
    )) {
      return 'car';
    }
    if (outputs.any(
      (device) =>
          device.type.name == 'bluetoothA2dp' ||
          device.type.name == 'bluetoothSco',
    )) {
      return 'car';
    }
    if (outputs.any(
      (device) =>
          device.type.name == 'wiredHeadphones' ||
          device.type.name == 'wiredHeadset',
    )) {
      return 'wired';
    }
    return 'phone';
  }

  void dispose() {
    unawaited(_subscription?.cancel());
  }
}
