import 'package:flutter_android_tv_queue/helper/utf8_try_decode.dart';

class QueueCallingVoiceTextModel {
  final Map data;

  QueueCallingVoiceTextModel({required this.data});

  int get id => data['id'] ?? 0;

  String get publicId => data['public_id'] ?? '';

  String get prefixNameEn => data['prefix_name_en'] ?? '';

  String get prefixNameTh => Utf8TryDecode.decode(data['prefix_name_th'] ?? '');

  String get suffixNameEn => data['suffix_name_en'] ?? '';

  String get suffixNameTh => Utf8TryDecode.decode(data['suffix_name_th'] ?? '');

  DateTime? get createdAt => DateTime.tryParse(data['created_at'] ?? '');

  DateTime? get updatedAt => DateTime.tryParse(data['updated_at'] ?? '');

  DateTime? get deletedAt => DateTime.tryParse(data['deleted_at'] ?? '');

  String get createdBy => data['created_by'] ?? '';

  String get updatedBy => data['updated_by'] ?? '';

  String get deletedBy => data['deleted_by'] ?? '';

  String get middleTh => Utf8TryDecode.decode(data['middle_th'] ?? '');

  String get middleEn => data['middle_en'] ?? '';
}
