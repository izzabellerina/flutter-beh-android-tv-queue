import 'package:flutter_android_tv_queue/models/employee_info_model.dart';

class QueueConfigScheduleModel {
  final Map data;

  QueueConfigScheduleModel({required this.data});

  int get id => data['id'] ?? 0;

  String get publicId => data['public_id'] ?? "";

  String get queuePrefix => data['queue_prefix'] ?? "";

  int get versionNumber => data['version_number'] ?? 0;

  String get emp => data['emp'] ?? "";

  int get queueRoomId => data['queue_room_id'] ?? 0;

  String get dayOfWeek => data['day_of_week'] ?? "";

  DateTime? get startDate => DateTime.tryParse(data['start_date'] ?? "");

  DateTime? get endDate => DateTime.tryParse(data['end_date'] ?? "");

  String get timeOfDay => data['time_of_day'] ?? "";

  DateTime? get createdAt => DateTime.tryParse(data['created_at'] ?? "");

  DateTime? get updatedAt => DateTime.tryParse(data['updated_at'] ?? "");

  DateTime? get deletedAt => DateTime.tryParse(data['deleted_at'] ?? "");

  String get createdBy => data['created_by'] ?? "";

  String get updatedBy => data['updated_by'] ?? "";

  String get deletedBy => data['deleted_by'] ?? "";

  EmployeeInfoModel get employee =>
      EmployeeInfoModel(data: data['employee'] ?? {});
}
