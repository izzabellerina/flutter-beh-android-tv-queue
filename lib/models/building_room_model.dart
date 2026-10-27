import 'package:flutter_android_tv_queue/helper/utf8_try_decode.dart';

class BuildingRoomModel {
  final Map data;

  BuildingRoomModel({required this.data});

  int get id => data['id'] ?? 0;

  String get nameTh => Utf8TryDecode.decode(data['name_th'] ?? "");

  String get nameEn => data['name_en'] ?? "";

  String get image => data['image'] ?? "";
}
