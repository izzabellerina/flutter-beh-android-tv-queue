// ═══════════════════════════════════════════════════════════════════
// COMPLETE CHECKED
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter_android_tv_queue/helper/utf8_try_decode.dart';
import 'package:flutter_android_tv_queue/models/department_model.dart';
import 'package:flutter_android_tv_queue/models/position_model.dart';

class EmployeeInfoModel {
  final Map data;

  EmployeeInfoModel({required this.data});

  int get id => data["id"] ?? 0;

  String get emp => data["emp"] ?? "";

  String get prefix => data["pefx"] ?? "";

  String get prefixTh => data['pefx_th'] ?? data["pefx"] ?? "";

  String get firstName => Utf8TryDecode.decode(data["firstname"] ?? "");

  String get midName => Utf8TryDecode.decode(data["midname"] ?? "");

  String get lastName => Utf8TryDecode.decode(data["lastname"] ?? "");

  String get firstNameEn => data["firstname_en"] ?? "";

  String get midNameEn => data["midname_en"] ?? "";

  String get lastNameEn => data["lastname_en"] ?? "";

  String? get birthdate => data["birthdate"] ?? "";

  String get thaiId => data["thai_id"] ?? "";

  String get gender => data["gend"] ?? "";

  String get username => data["username"] ?? "";

  String? get avatarImagePath => data["avatar_image_path"] ?? "";

  List<DepartmentModel> get dep =>
      List.from(data["dep"] ?? [])
          .map((e) => DepartmentModel(data: e))
          .toList();

  PositionModel get position => PositionModel(data: data["position"] ?? {});

  bool get scheduleAble => data["schedulable"] ?? false;

  String get licenseNumber => data["license_number"] ?? "";

  String get eSignatureImage => data["e_signature_image"] ?? "";

  String get fullname => "$prefixTh $firstName $lastName";

  /// pefx + firstname_en + midname_en + lastname_en เช่น "Dr. Thanawat Kaewphrom"
  String get fullnameEnWithMid => [
    prefix,
    firstNameEn,
    midNameEn,
    lastNameEn,
  ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');

  /// คำนำหน้า + ชื่อ + ชื่อกลาง + นามสกุล (ข้ามส่วนที่ว่าง) เช่น "พญ. ธนวัฒน์ แก้วพรหม"
  String get fullnameWithMid => [
    prefixTh,
    firstName,
    midName,
    lastName,
  ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');

  String get fullnameEn => "$firstNameEn $lastNameEn";
}
