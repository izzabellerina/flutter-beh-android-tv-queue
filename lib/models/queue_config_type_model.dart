import 'package:flutter_android_tv_queue/helper/utf8_try_decode.dart';

class QueueConfigTypeModel {
  final Map data;

  QueueConfigTypeModel({required this.data});

  int get id => data['id'] ?? 0;

  String get publicId => data['public_id'] ?? "";

  String get nameEn => data['name_en'] ?? "";

  String get nameTh => Utf8TryDecode.decode(data['name_th'] ?? "");

  String get color => data['color'] ?? "";

  int get sequent => data['sequent'] ?? 0;

  DateTime? get createdAt => DateTime.tryParse(data['created_at'] ?? "");

  DateTime? get updatedAt => DateTime.tryParse(data['updated_at'] ?? "");

  DateTime? get deletedAt => DateTime.tryParse(data['deleted_at'] ?? "");

  String get createdBy => data['created_by'] ?? "";

  String get updatedBy => data['updated_by'] ?? "";

  String get deletedBy => data['deleted_by'] ?? "";
}
