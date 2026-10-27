import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ตัวช่วยตอนพัฒนาบน emulator เท่านั้น
///
/// คีย์บอร์ดบนจอของ Android TV (Gboard TV) ไม่รับเมาส์ และตอนเปิดอยู่จะบังการคลิก
/// ครึ่งล่างของจอ — ถ้าเป็น debug build และมีคีย์บอร์ดจริงต่ออยู่ จะไม่เปิดคีย์บอร์ดบนจอ
/// ให้พิมพ์จากคีย์บอร์ด PC แทน (release build/ทีวีจริงไม่กระทบ)
class DeviceInput {
  static const _channel = MethodChannel(
    'com.panudet789.flutter_android_tv_queue/device_input',
  );

  static bool _hideSoftKeyboard = false;

  /// ตรวจครั้งเดียวตอนเปิดแอป — เสียบ/ถอดคีย์บอร์ดระหว่างใช้งานต้อง restart แอป
  static bool get hideSoftKeyboard => _hideSoftKeyboard;

  static Future<void> init() async {
    if (!kDebugMode) return;

    try {
      _hideSoftKeyboard =
          await _channel.invokeMethod<bool>('hasHardwareKeyboard') ?? false;
    } on PlatformException {
      _hideSoftKeyboard = false;
    } on MissingPluginException {
      _hideSoftKeyboard = false;
    }
  }
}
