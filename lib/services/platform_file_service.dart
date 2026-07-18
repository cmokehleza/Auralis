import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

abstract final class PlatformFileService {
  static const _channel = MethodChannel('com.auralis.player/files');

  static Future<String?> saveBytes({
    required Uint8List bytes,
    required String suggestedName,
    required String mimeType,
    required List<String> extensions,
  }) async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<String>('saveFile', {
          'bytes': bytes,
          'suggestedName': suggestedName,
          'mimeType': mimeType,
        });
      } on PlatformException {
        return null;
      }
    }

    final type = XTypeGroup(label: suggestedName, extensions: extensions);
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [type],
    );
    if (location == null) return null;
    final file = XFile.fromData(bytes, name: suggestedName, mimeType: mimeType);
    await file.saveTo(location.path);
    return location.path;
  }
}
