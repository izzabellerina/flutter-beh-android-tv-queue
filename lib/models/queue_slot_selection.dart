import 'package:flutter_android_tv_queue/models/employee_info_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_type_model.dart';

/// ค่าที่เลือกของคิว 1 ชุด (คิวเดี่ยวมี 1 ชุด, คิวคู่มี 2 ชุด)
class QueueSlotSelection {
  final QueueConfigTypeModel? type;
  final QueueConfigModel? station;
  final EmployeeInfoModel? doctor;

  /// วนทุก station ของ type — ตัดไป station ที่มีการเรียกคิว (ทำงานที่หน้าจอคิว)
  final bool autoRotation;

  const QueueSlotSelection({
    this.type,
    this.station,
    this.doctor,
    this.autoRotation = true,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // UPDATE — เปลี่ยนตัวก่อนหน้าแล้วล้างตัวที่ขึ้นกับมัน
  // ══════════════════════════════════════════════════════════════════════════

  QueueSlotSelection selectType(QueueConfigTypeModel value) {
    if (type?.id == value.id) return this;
    return QueueSlotSelection(type: value, autoRotation: autoRotation);
  }

  QueueSlotSelection selectStation(QueueConfigModel value) {
    if (station?.queueType == value.queueType) return this;
    return QueueSlotSelection(
      type: type,
      station: value,
      autoRotation: autoRotation,
    );
  }

  /// null = ไม่ระบุแพทย์
  QueueSlotSelection selectDoctor(EmployeeInfoModel? value) {
    return QueueSlotSelection(
      type: type,
      station: station,
      doctor: value,
      autoRotation: autoRotation,
    );
  }

  QueueSlotSelection withAutoRotation(bool value) {
    return QueueSlotSelection(
      type: type,
      station: station,
      doctor: doctor,
      autoRotation: value,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION
  // ══════════════════════════════════════════════════════════════════════════

  /// TYPE บังคับ; STATION บังคับเมื่อไม่วน station; DOCTOR ไม่บังคับ
  String? validate() {
    if (type == null) return 'กรุณาเลือก TYPE';
    if (!autoRotation && station == null) {
      return 'กรุณาเลือก STATION (หรือเปิด AUTO ROTATION)';
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JSON — เก็บ data ดิบของแต่ละ model ไว้ เติมกลับเข้าฟอร์มได้ทันที
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> toJson() => {
    'type': type?.data,
    'station': station?.data,
    'doctor': doctor?.data,
    'auto_rotation': autoRotation,
  };

  factory QueueSlotSelection.fromJson(Map json) {
    Map? mapOf(String key) => json[key] is Map ? json[key] as Map : null;

    final type = mapOf('type');
    final station = mapOf('station');
    final doctor = mapOf('doctor');

    return QueueSlotSelection(
      type: type == null ? null : QueueConfigTypeModel(data: type),
      station: station == null ? null : QueueConfigModel(data: station),
      doctor: doctor == null ? null : EmployeeInfoModel(data: doctor),
      autoRotation: json['auto_rotation'] ?? true,
    );
  }
}
