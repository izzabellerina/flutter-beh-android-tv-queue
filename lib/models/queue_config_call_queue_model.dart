import 'package:flutter_android_tv_queue/models/building_room_model.dart';
import 'package:flutter_android_tv_queue/models/department_model.dart';
import 'package:flutter_android_tv_queue/models/employee_info_model.dart';
import 'package:flutter_android_tv_queue/models/queue_channel_model.dart';

class QueueConfigCallQueueModel {
  final Map data;

  QueueConfigCallQueueModel({required this.data});

  String get queueType => data['queue_type'] ?? "";

  String get prefix => data['prefix'] ?? "";

  int get numberLength => data['number_length'] ?? 0;

  String get description => data['description'] ?? "";

  DateTime? get createdAt => DateTime.tryParse(data['created_at'] ?? "");

  String get queueCategory => data['queue_category'] ?? "";

  String get waitingStatus => data['waiting_status'] ?? "";

  int get queueConfigTypeId => data['queue_config_type_id'] ?? 0;

  int get sequent => data['sequent'] ?? 0;

  EmployeeInfoModel get employee =>
      EmployeeInfoModel(data: data['employee'] ?? {});

  DepartmentModel get department =>
      DepartmentModel(data: data['department'] ?? {});

  List<QueueChannelModel> get queueChannel =>
      List.from(data['queue_channel'] ?? [])
          .map((e) => QueueChannelModel(data: e))
          .toList();

  BuildingRoomModel get buildingRoom =>
      BuildingRoomModel(data: data['building_room'] ?? {});

  /// แพทย์ที่มีตารางของ queue type นี้ — จาก queue_channel[*].queue_config_schedule[*]
  /// คนเดียวกันอยู่หลาย channel ได้ → รวมเป็นรายการเดียว (ตัดซ้ำด้วย emp) พร้อมชื่อห้อง/ช่อง
  List<ScheduledDoctor> get scheduledDoctors {
    final byEmp = <String, ScheduledDoctor>{};

    for (final channel in queueChannel) {
      final roomName = channel.queueRoom.nameTh;
      for (final schedule in channel.queueConfigSchedule) {
        final employee = schedule.employee;
        final key = employee.emp.isNotEmpty ? employee.emp : schedule.emp;
        if (key.isEmpty) continue;

        final doctor = byEmp.putIfAbsent(
          key,
          () => ScheduledDoctor(employee: employee, rooms: []),
        );
        if (roomName.isNotEmpty && !doctor.rooms.contains(roomName)) {
          doctor.rooms.add(roomName);
        }
      }
    }

    return byEmp.values.toList();
  }
}

class ScheduledDoctor {
  final EmployeeInfoModel employee;

  /// ชื่อห้อง/ช่องที่แพทย์มีตาราง เช่น ["ช่อง 2"]
  final List<String> rooms;

  ScheduledDoctor({required this.employee, required this.rooms});
}
