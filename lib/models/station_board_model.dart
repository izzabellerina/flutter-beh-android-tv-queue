import 'package:flutter_android_tv_queue/models/appointment_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_call_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';

/// ข้อมูลที่จอแสดงสำหรับ 1 station ณ เวลาหนึ่ง
class StationBoardModel {
  final QueueConfigModel station;
  final QueueConfigCallQueueModel callQueue;

  /// call_queue_status = CALLING
  final List<AppointmentQueueModel> waiting;

  /// call_queue_status = DENIED
  final List<AppointmentQueueModel> counter;

  const StationBoardModel({
    required this.station,
    required this.callQueue,
    required this.waiting,
    required this.counter,
  });

  /// กำลังตรวจ = queue_channel[0].appointment_call_queue (ตามที่ dev กำหนด)
  AppointmentQueueModel? get current {
    final channels = callQueue.queueChannel;
    return channels.isEmpty ? null : channels.first.appointmentCallQueue;
  }

  /// prefix สำหรับเทียบกับ `data.queue` ของ socket เช่น "2SCR"
  String get queuePrefix =>
      callQueue.prefix.isNotEmpty ? callQueue.prefix : station.prefix;

  /// ไม่มีคิวค้างเลย (กำลังตรวจ/รอ/ติดต่อเคาน์เตอร์) → AUTO ROTATION ค้างแค่ 10 วิ
  bool get isEmpty => current == null && waiting.isEmpty && counter.isEmpty;

  /// ใช้เทียบว่าข้อมูลเปลี่ยนไหมหลัง fetch ซ้ำ
  String get signature => [
    current?.bookNo ?? '-',
    waiting.map((e) => e.bookNo).join(','),
    counter.map((e) => e.bookNo).join(','),
  ].join('|');

  bool containsBookNo(String bookNo) {
    if (bookNo.isEmpty) return false;
    return current?.bookNo == bookNo ||
        waiting.any((e) => e.bookNo == bookNo) ||
        counter.any((e) => e.bookNo == bookNo);
  }

  /// building_room บาง station เป็น null → ใช้ชื่อ station แทน
  String get roomNameTh {
    final name = callQueue.buildingRoom.nameTh;
    if (name.isNotEmpty) return name;
    return station.description.isNotEmpty
        ? station.description
        : callQueue.description;
  }

  String get roomNameEn {
    final name = callQueue.buildingRoom.nameEn;
    return name == roomNameTh ? '' : name;
  }
}
