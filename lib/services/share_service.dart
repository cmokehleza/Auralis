import 'package:flutter/services.dart';

abstract final class ShareService {
  static const _channel = MethodChannel('com.auralis.player/share');

  static Future<bool> shareText(String text) async {
    try {
      return await _channel.invokeMethod<bool>('shareText', {'text': text}) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
