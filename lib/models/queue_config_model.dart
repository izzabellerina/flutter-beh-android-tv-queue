import 'package:flutter_android_tv_queue/helper/utf8_try_decode.dart';

class QueueConfigModel {
  final Map data;

  QueueConfigModel({required this.data});

  String get queueType => data['queue_type'] ?? "";

  String get prefix => data['prefix'] ?? "";

  int get numberLength => data['number_length'] ?? 0;

  String get description => Utf8TryDecode.decode(data['description'] ?? "");

  DateTime? get createdAt => DateTime.tryParse(data['created_at'] ?? "");

  String get queueCategory => data['queue_category'] ?? "";

  String get waitingStatus => data['waiting_status'] ?? "";

  int get queueConfigTypeId => data['queue_config_type_id'] ?? 0;

  int get sequent => data['sequent'] ?? 0;
}
