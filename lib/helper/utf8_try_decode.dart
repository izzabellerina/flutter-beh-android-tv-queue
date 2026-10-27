import 'dart:convert';

class Utf8TryDecode {
  /// แปลงค่าจาก JSON เป็น string ที่อ่านออก (ลอง decode UTF-8 ก่อน)
  ///
  /// รับ [Object?] ไม่ใช่ [String] เพราะค่าที่ส่งเข้ามาคือ `data['key']` ตรง ๆ
  /// ซึ่งเป็น dynamic — ถ้า API คืน int/bool/null มาจะ throw
  /// `type 'int' is not a subtype of type 'String'` ตอน runtime
  static String decode(Object? value) {
    if (value == null) return '';

    final str = value.toString();

    try {
      return utf8.decode(str.codeUnits);
    } catch (e) {
      return str;
    }
  }
}
