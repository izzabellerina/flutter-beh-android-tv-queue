import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/helper/shared_preference_helper.dart';
import 'package:flutter_android_tv_queue/models/employee_info_model.dart';
import 'package:flutter_android_tv_queue/models/login_model.dart';
import 'package:flutter_android_tv_queue/models/response_model.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/routes/router_path.dart';
import 'package:flutter_android_tv_queue/service/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SessionHelper {
  /// ล้าง token/ข้อมูลผู้ใช้ แล้วกลับหน้า login
  /// (user/pass ที่จดจำไว้ และค่าตั้งคิวยังอยู่ — login รอบหน้าเติมให้)
  static void logout(BuildContext context, WidgetRef ref) {
    ref.read(loginProvider.notifier).state = LoginModel(data: {});
    ref.read(employeeInfoProvider.notifier).state = EmployeeInfoModel(data: {});
    context.go(RouterPath.login);
  }

  /// token ใกล้หมด (ภายใน [margin]) — `expired_at` อ่านไม่ได้ถือว่ายังไม่หมด
  static bool tokenExpiringSoon(
    LoginModel login, {
    DateTime? now,
    Duration margin = const Duration(minutes: 5),
  }) {
    final expiredAt = login.expiredAt;
    if (expiredAt.year <= 1970) return false;
    return expiredAt.isBefore((now ?? DateTime.now()).add(margin));
  }

  /// login ใหม่เงียบ ๆ ด้วย user/pass ที่จดจำไว้ — จอคิวเปิดทั้งวัน token หมดอายุระหว่างวันได้
  /// คืน false ถ้าไม่ได้จดจำไว้ หรือ login ไม่สำเร็จ
  static Future<bool> relogin(WidgetRef ref) async {
    final saved = await SharedPreferenceHelper.getCredentials();
    if (saved == null) return false;

    try {
      final response = await AuthService.login(
        username: saved.username,
        password: saved.password,
        client: ref.read(httpClientProvider),
      );
      if (response.responseEnum != ResponseEnum.success) return false;
      ref.read(loginProvider.notifier).state = response.data;
      return true;
    } catch (_) {
      return false;
    }
  }
}
