import 'package:flutter/services.dart';

class ScreenHelper {
  static const _channel = MethodChannel(
    'com.panudet789.flutter_android_tv_queue/screen',
  );

  /// เปิดตอนอยู่หน้าจอคิว — Android TV เข้า screensaver/ปิดจอเองถ้าไม่มีการกดรีโมทนาน ๆ
  static Future<void> setKeepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod('setKeepScreenOn', on);
    } on PlatformException {
      // ไม่ใช่ Android / test — ไม่เป็นไร
    } on MissingPluginException {
      // ไม่ใช่ Android / test — ไม่เป็นไร
    }
  }
}
