import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/helper/device_input.dart';
import 'package:flutter_android_tv_queue/helper/shared_preference_helper.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/routes/app_router.dart';
import 'package:flutter_android_tv_queue/service/configuration.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_traversal_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await initializeDateFormatting('th');
  await DeviceInput.init();

  // TV ใช้รีโมทเสมอ — แสดงกรอบ focus ตั้งแต่เปิดแอป ไม่ต้องรอกดปุ่มแรก
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;

  final themeMode = await SharedPreferenceHelper.getThemeMode();

  runApp(
    ProviderScope(
      overrides: [themeModeProvider.overrideWith((ref) => themeMode)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'BEH TV Queue',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      builder: TvTraversalPolicy.builder,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
    );
  }
}
