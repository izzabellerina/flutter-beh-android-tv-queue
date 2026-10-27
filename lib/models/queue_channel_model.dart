import 'package:flutter_android_tv_queue/models/appointment_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_schedule_model.dart';
import 'package:flutter_android_tv_queue/models/queue_room_model.dart';

class QueueChannelModel {
  final Map data;

  QueueChannelModel({required this.data});

  int get id => data['id'] ?? 0;

  String get publicId => data['public_id'] ?? "";

  String get queueType => data['queue_type'] ?? "";

  int get queueRoomId => data['queue_room_id'] ?? 0;

  DateTime? get createdAt => DateTime.tryParse(data['created_at'] ?? "");

  DateTime? get updatedAt => DateTime.tryParse(data['updated_at'] ?? "");

  DateTime? get deletedAt => DateTime.tryParse(data['deleted_at'] ?? "");

  String get createdBy => data['created_by'] ?? "";

  String get updatedBy => data['updated_by'] ?? "";

  String get deletedBy => data['deleted_by'] ?? "";

  DateTime? get startDate => DateTime.tryParse(data['start_date'] ?? "");

  DateTime? get endDate => DateTime.tryParse(data['end_date'] ?? "");

  String get channelPriority => data['channel_priority'] ?? "";

  QueueRoomModel get queueRoom =>
      QueueRoomModel(data: data['queue_room'] ?? {});

  /// คิวที่ช่องนี้กำลังเรียกอยู่ (null = ยังไม่มี) — เป็น object ไม่ใช่ String
  AppointmentQueueModel? get appointmentCallQueue =>
      data['appointment_call_queue'] is Map
      ? AppointmentQueueModel(data: data['appointment_call_queue'])
      : null;

  List<QueueConfigScheduleModel> get queueConfigSchedule =>
      List.from(data['queue_config_schedule'] ?? [])
          .map((e) => QueueConfigScheduleModel(data: e))
          .toList();
}
