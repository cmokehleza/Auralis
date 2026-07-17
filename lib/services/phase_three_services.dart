import 'battery_profile_service.dart';
import 'audio_output_detection_service.dart';
import 'large_library_service.dart';
import 'local_network_service.dart';

class PhaseThreeServices {
  PhaseThreeServices()
    : largeLibrary = LargeLibraryService(),
      batteryProfile = BatteryProfileService(),
      outputDetection = AudioOutputDetectionService(),
      localNetwork = LocalNetworkService();

  final LargeLibraryService largeLibrary;
  final BatteryProfileService batteryProfile;
  final AudioOutputDetectionService outputDetection;
  final LocalNetworkService localNetwork;

  void dispose() {
    largeLibrary.dispose();
    batteryProfile.dispose();
    outputDetection.dispose();
    localNetwork.dispose();
  }
}
