// ═══════════════════════════════════════════════════════════════════
// COMPLETE CHECKED
// ═══════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/models/employee_info_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/login_model.dart';
import '../models/response_model.dart';
import '../provider/common_provider.dart';

import 'configuration.dart';

class AuthService {
  // ═══════════════════════════════════════════════════════════════════
  // AUTHENTICATION
  // ═══════════════════════════════════════════════════════════════════

  // 1. /api/authentication/ (เข้าสู่ระบบ)
  static Future<ResponseModel<LoginModel>> login({
    required String username,
    required String password,
    http.Client? client,
  }) async {
    log("login");

    final httpClient = client ?? http.Client();

    final httpString = BehConfig.https(
      service: PortConfig.authPort,
      path: "authentication/",
    );

    final uri = Uri.parse(httpString);
    final httpPostResponse = httpClient.post(
      uri,
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'app-id': 'new-his',
        'secret-key': r'*wg%bg!b2lzl7ir5g1_g2av0n&m*+t4_6yqu6^u_p+54$%',
      },
      body: jsonEncode({"username": username, "password": password}),
    );

    final response = await httpPostResponse;
    final responseJS = jsonDecode(response.body);

    log("Response Body (login) ${response.body}");
    log("Response Status Code (login) ${response.statusCode}");

    if (response.statusCode == 200 && (responseJS["code"] == null)) {
      final data = Map.from(responseJS);
      return ResponseModel(
        data: LoginModel(data: data),
        responseEnum: ResponseEnum.success,
      );
    } else if (response.statusCode == 200 &&
        ((responseJS["message"] ?? "") ==
                "username or password are incorrect" ||
            // DEV server ปัจจุบันตอบ 200 + code แทนข้อความด้านบน
            // 401 "Password is incorrect", 404 "Employee with username ... does not exist"
            responseJS["code"] == 401 ||
            responseJS["code"] == 404)) {
      return ResponseModel(
        data: LoginModel(data: {}),
        responseEnum: ResponseEnum.passwordUserIncorrect,
      );
    } else if (response.statusCode == 400 &&
        (responseJS["message"] ?? "") == "Patient not found.") {
      return ResponseModel(
        data: LoginModel(data: {}),
        responseEnum: ResponseEnum.patientNoFound,
      );
    } else {
      return ResponseModel(
        data: LoginModel(data: {}),
        responseEnum: ResponseEnum.fail,
      );
    }
  }

  // 2. /api/authentication/userinfo (ข้อมูลผู้ใช้งาน)
  static Future<ResponseModel<EmployeeInfoModel>> getUserInfo(
    BuildContext context, {
    http.Client? client,
  }) async {
    log("getUserInfo");

    final httpClient = client ?? http.Client();

    final container = ProviderScope.containerOf(context, listen: false);
    final login = container.read(loginProvider);

    final httpString = BehConfig.https(
      service: PortConfig.authPort,
      path: "authentication/userinfo",
    );

    final uri = Uri.parse(httpString);
    final httpGetResponse = httpClient.get(
      uri,
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${login.token}',
      },
    );

    final response = await httpGetResponse;

    log("Response Body (getUserInfo) ${response.body}");
    log("Response Status Code (getUserInfo) ${response.statusCode}");

    if (response.statusCode == 200) {
      final responseJS = Map.from(jsonDecode(response.body));
      return ResponseModel(
        data: EmployeeInfoModel(data: responseJS),
        responseEnum: ResponseEnum.success,
      );
    } else {
      return ResponseModel(
        data: EmployeeInfoModel(data: {}),
        responseEnum: ResponseEnum.fail,
      );
    }
  }
}
