import 'package:flutter_android_tv_queue/helper/utf8_try_decode.dart';

class DepartmentModel {
  final Map data;

  DepartmentModel({required this.data});

  int get id => data['id'] ?? 0;

  String get dep => data['dep'] ?? "";

  String get depName => Utf8TryDecode.decode(data['depname'] ?? "");

  String get depNameEn => data['depname_en'] ?? "";

  String? get icon => data['icon'] ?? "";

  // auth-api/api/authentication/userinfo
  bool get isMainDep => data['is_main_dep'] ?? false;

  String? get parentDep => data['parentdep'] ?? "";

  String get manager1 => data['manager1'] ?? "";

  String get manager2 => data['manager2'] ?? "";

  String get hosp => data['hosp'] ?? "";

  DateTime get createdAt => DateTime.parse(data['created_at'] ?? "");

  DateTime get updatedAt => DateTime.parse(data['updated_at'] ?? "");

  DateTime? get deletedAt => DateTime.parse(data['deleted_at'] ?? "");
}
