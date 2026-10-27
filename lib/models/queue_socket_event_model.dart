import 'dart:convert';

/// event เรียกคิวจาก socket (`type == appointment_call_queue`)
///
/// ตัวอย่างจริงที่ได้แล้วมีแค่ `{"message":"Connected to updates","type":"connected"}`
/// field ของ event เรียกคิวมาจากที่ dev แจ้ง: `data.bookno`, `data.queue` (เช่น "FIN0001")
class QueueSocketEventModel {
  static const typeCallQueue = 'appointment_call_queue';
  static const typeConnected = 'connected';

  final String type;
  final Map data;

  QueueSocketEventModel({required this.type, required this.data});

  String get bookNo => data['bookno']?.toString() ?? '';

  String get queue => data['queue']?.toString() ?? '';

  /// เลขที่แสดง/ประกาศ เช่น "LS0001"
  String get publicQueue => data['public_queue']?.toString() ?? '';

  /// ชื่อช่อง/ห้องที่ให้ไป (ใช้ในเสียงประกาศ)
  String get nameTh => data['name_th']?.toString() ?? '';

  String get nameEn => data['name_en']?.toString() ?? '';

  String get callQueueStatus => data['call_queue_status']?.toString() ?? '';

  /// พยาบาลกดเรียก → คิวขึ้น "กำลังตรวจ"
  bool get isServing => callQueueStatus == 'SERVING';

  bool get isCallQueue => type == typeCallQueue;

  bool get isConnected => type == typeConnected;

  /// เกี่ยวกับ station ที่มี prefix นี้ไหม — prefix ว่างไม่นับ (startsWith('') เป็นจริงเสมอ)
  bool matchesPrefix(String prefix) =>
      prefix.isNotEmpty && queue.startsWith(prefix);

  /// null = ไม่ใช่ JSON object ที่มี type
  static QueueSocketEventModel? tryParse(dynamic message) {
    try {
      final json = message is String ? jsonDecode(message) : message;
      if (json is! Map || json['type'] is! String) return null;
      return QueueSocketEventModel(
        type: json['type'],
        data: json['data'] is Map ? json['data'] : const {},
      );
    } on FormatException {
      return null;
    }
  }
}
