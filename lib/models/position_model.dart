import 'package:flutter_android_tv_queue/helper/utf8_try_decode.dart';

class PositionModel {
  final Map data;

  PositionModel({required this.data});

  int get id => data['id'] ?? 0;

  String get publicId => data['public_id'] ?? "";

  String get nameTh => Utf8TryDecode.decode(data['name_th'] ?? "");

  String get nameEn => data['name_en'] ?? "";

  DateTime get createdAt => DateTime.parse(data['created_at'] ?? "");

  DateTime get updatedAt => DateTime.parse(data['updated_at'] ?? "");

  DateTime? get deletedAt => DateTime.parse(data['deleted_at'] ?? "");

  String? get createdBy => data['created_by'] ?? "";

  String get updatedBy => data['updated_by'] ?? "";

  String? get deletedBy => data['deleted_by'] ?? "";
}
