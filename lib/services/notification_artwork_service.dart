import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'media_session_item_factory.dart';

/// Makes the branded notification fallback available as a normal file URI.
///
/// `audio_service` supports file URIs on both Android and Darwin. Android's
/// provider resolves real MediaStore artwork first; this file is primarily the
/// guaranteed Control Center/lock-screen fallback on other platforms.
abstract final class NotificationArtworkService {
  static const _assetPath = 'assets/branding/auralis_icon_master.png';
  static const _fileName = 'auralis_notification_art_v1.png';

  static Future<void> prepareFallback() async {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    if (await file.exists() && await file.length() > 0) {
      MediaSessionItemFactory.fallbackArtworkUri = file.uri;
      return;
    }
    final data = await rootBundle.load(_assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await file.writeAsBytes(bytes, flush: true);
    MediaSessionItemFactory.fallbackArtworkUri = file.uri;
  }
}
