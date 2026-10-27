import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/enum/display_rotation.dart';
import 'package:flutter_android_tv_queue/enum/queue_mode.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SavedCredentials = ({String username, String password});
typedef SavedQueueSetup = ({
  QueueMode mode,
  List<QueueSlotSelection> slots,
  DisplayRotation rotation,
  bool voiceEnabled,
});

/// username / ธีม เก็บใน SharedPreferences ส่วนรหัสผ่านเก็บใน secure storage
/// (Android Keystore) — ต่างจาก flutter_beh_ic_register ที่เก็บรหัสเป็น plain text
class SharedPreferenceHelper {
  static const _keyUsername = "USERNAME";
  static const _keyPassword = "PASSWORD";
  static const _keyThemeMode = "THEME_MODE";
  static const _keyQueueSetup = "QUEUE_SETUP";

  static const _secureStorage = FlutterSecureStorage();

  // ══════════════════════════════════════════════════════════════════════════
  // CREDENTIALS
  // ══════════════════════════════════════════════════════════════════════════

  /// คืนค่า null ถ้ายังไม่เคยจดจำไว้
  static Future<SavedCredentials?> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_keyUsername) ?? "";
    if (username.isEmpty) return null;

    final password = await _secureStorage.read(key: _keyPassword) ?? "";
    return (username: username, password: password);
  }

  static Future<void> setCredentials(SavedCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, credentials.username);
    await _secureStorage.write(key: _keyPassword, value: credentials.password);
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUsername);
    await _secureStorage.delete(key: _keyPassword);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUEUE SETUP — โหมด + ค่าที่เลือก เติมกลับเข้าฟอร์มรอบหน้า
  // ══════════════════════════════════════════════════════════════════════════

  static Future<SavedQueueSetup?> getQueueSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyQueueSetup);
    if (raw == null) return null;

    try {
      final json = Map.from(jsonDecode(raw));
      final mode =
          QueueMode.values.asNameMap()[json['mode']] ?? QueueMode.single;
      final slots = List.from(json['slots'] ?? [])
          .map((e) => QueueSlotSelection.fromJson(Map.from(e)))
          .toList();
      final rotation =
          DisplayRotation.values.asNameMap()[json['rotation']] ??
          DisplayRotation.portraitRight;
      return (
        mode: mode,
        slots: slots,
        rotation: rotation,
        voiceEnabled: json['voice'] != false,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static Future<void> setQueueSetup(SavedQueueSetup setup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyQueueSetup,
      jsonEncode({
        'mode': setup.mode.name,
        'rotation': setup.rotation.name,
        'voice': setup.voiceEnabled,
        'slots': setup.slots.map((e) => e.toJson()).toList(),
      }),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // THEME
  // ══════════════════════════════════════════════════════════════════════════

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) == ThemeMode.light.name
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode.name);
  }
}
