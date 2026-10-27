import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/enum/display_rotation.dart';
import 'package:flutter_android_tv_queue/enum/queue_mode.dart';
import 'package:flutter_android_tv_queue/models/employee_info_model.dart';
import 'package:flutter_android_tv_queue/models/login_model.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_android_tv_queue/service/queue_socket_service.dart';
import 'package:flutter_android_tv_queue/service/voice_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

final loginProvider = StateProvider<LoginModel>((ref) => LoginModel(data: {}));
final employeeInfoProvider = StateProvider<EmployeeInfoModel>(
  (ref) => EmployeeInfoModel(data: {}),
);

///---------------------------QUEUE SETUP ------------------------------
final queueModeProvider = StateProvider<QueueMode>((ref) => QueueMode.single);

/// การวางจอของหน้าจอคิวเดี่ยว (คิวคู่เป็นแนวนอนเสมอ)
final displayRotationProvider = StateProvider<DisplayRotation>(
  (ref) => DisplayRotation.portraitRight,
);

/// เสียงเรียกคิวของทีวีเครื่องนี้ — ปิดได้ถ้ามีหลายเครื่องในห้องรอเดียวกัน (กันประกาศซ้อน)
final voiceEnabledProvider = StateProvider<bool>((ref) => true);

/// จำนวนชุด = queueModeProvider.slotCount (ปรับตอนเลือกโหมด)
final queueSlotsProvider = StateProvider<List<QueueSlotSelection>>(
  (ref) => const [QueueSlotSelection()],
);

///-------------------------------------------------------------------------

///---------------------------APP SETTINGS ------------------------------
/// ค่าเริ่มต้นถูก override ใน main() ด้วยค่าที่บันทึกไว้
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// null = ใช้ http ปกติ; test override ด้วย MockClient
final httpClientProvider = Provider<http.Client?>((ref) => null);

/// null = WebSocket จริง; test override ด้วยตัวปลอม
final socketConnectorProvider = Provider<SocketConnector?>((ref) => null);

/// null = audioplayers จริง; test override ด้วยตัวเล่นปลอม
final voicePlayerFactoryProvider = Provider<VoicePlayer Function()?>(
  (ref) => null,
);

///-------------------------------------------------------------------------
