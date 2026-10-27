// test/widget/login_page_test.dart
//
// ทดสอบหน้า Login บน TV — ใช้ปุ่มรีโมท (ลูกศร / select) แทนการแตะ

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_android_tv_queue/pages/queue_mode_page.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/pages/login_page.dart';
import 'package:flutter_android_tv_queue/routes/router_path.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_traversal_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════

  Future<void> pumpLoginPage(WidgetTester tester, {http.Client? client}) async {
    // จอ TV 1080p = 960×540 dp
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: RouterPath.login,
      routes: [
        GoRoute(
          path: RouterPath.login,
          builder: (_, _) => LoginPage(client: client),
        ),
        GoRoute(
          path: RouterPath.queueMode,
          builder: (_, _) => const QueueModePage(),
        ),
        GoRoute(
          path: RouterPath.queueSetup,
          builder: (_, _) => const Scaffold(body: Text('SETUP PAGE')),
        ),
        GoRoute(
          path: RouterPath.queueDisplay,
          builder: (_, _) => const Scaffold(body: Text('DISPLAY PAGE')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: TvTraversalPolicy.builder,
          theme: AppTheme.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  MockClient loginClient({required Map<String, dynamic> loginBody}) {
    return MockClient((request) async {
      final body = request.url.path.endsWith('userinfo')
          ? {
              'username': 'doctor_demo_01',
              'firstname': 'สมชาย',
              'lastname': 'ใจดี',
            }
          : loginBody;
      return http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  setUpAll(() => initializeDateFormatting('th'));

  setUp(() {
    LoginPage.autoStartUsed = false;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════════════
  // Focus เริ่มต้น
  // ═══════════════════════════════════════════════════════════════════

  testWidgets('ไม่มีข้อมูลที่จำไว้ → focus ที่ช่องชื่อเข้าใช้งาน', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    expect(focusedLabel(), 'username');
  });

  testWidgets('มีข้อมูลที่จำไว้ → เติมให้ และ focus ที่ปุ่มเข้าใช้งาน', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'USERNAME': 'doctor_demo_01'});
    FlutterSecureStorage.setMockInitialValues({'PASSWORD': 'secret'});

    await pumpLoginPage(tester);

    expect(find.text('doctor_demo_01'), findsOneWidget);
    expect(focusedLabel(), 'login');
  });

  // ═══════════════════════════════════════════════════════════════════
  // รีโมท D-pad
  // ═══════════════════════════════════════════════════════════════════

  testWidgets('ลูกศรลง เลื่อนจากชื่อ → รหัส โดยไม่เปิดโหมดแก้ไข', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await press(tester, LogicalKeyboardKey.arrowDown);

    expect(focusedLabel(), 'password');
  });

  testWidgets('select = เข้าโหมดพิมพ์, ลูกศรลงระหว่างพิมพ์ = ออกจากช่องได้', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await press(tester, LogicalKeyboardKey.select);
    expect(focusedLabel(), 'TvTextField.edit');

    await tester.enterText(find.byType(TextField).first, 'doctor_demo_01');
    await press(tester, LogicalKeyboardKey.arrowDown);

    expect(focusedLabel(), 'password');
    expect(find.text('doctor_demo_01'), findsOneWidget);
  });

  testWidgets(
    'ถัดไปที่ช่องชื่อ → ช่องรหัส (ไม่ข้าม), เสร็จที่ช่องรหัส → login ทันที',
    (tester) async {
      await pumpLoginPage(
        tester,
        client: loginClient(
          loginBody: {'code': 401, 'message': 'Password is incorrect'},
        ),
      );

      await press(tester, LogicalKeyboardKey.select);
      await tester.enterText(find.byType(TextField).at(0), 'doctor_demo_01');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(focusedLabel(), 'password');

      await press(tester, LogicalKeyboardKey.select);
      await tester.enterText(find.byType(TextField).at(1), 'wrong');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // เรียก API แล้ว (ไม่ต้องกดปุ่มเข้าใช้งาน) → แจ้งรหัสผิด
      expect(find.text('ชื่อเข้าใช้งานหรือรหัสไม่ถูกต้อง'), findsOneWidget);
      expect(focusedLabel(), 'password');
    },
  );

  testWidgets('ลูกศรเลื่อนตามตำแหน่งบนจอ แม้ focus เคยถูกย้ายด้วยโค้ด', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    // ชื่อ → (ถัดไป) รหัส → (ลงระหว่างพิมพ์) จดจำ → ลง ปุ่ม → ขึ้น จดจำ → ขึ้น รหัส
    await press(tester, LogicalKeyboardKey.select);
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedLabel(), 'remember');

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedLabel(), 'login');

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusedLabel(), 'remember');

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusedLabel(), 'password');
  });

  testWidgets(
    'ลูกศรขึ้นจากช่องชื่อ → ปุ่มสลับธีม แล้ว select สลับเป็นโหมดสว่าง',
    (tester) async {
      await pumpLoginPage(tester);
      expect(find.text('โหมดสว่าง'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.select);

      expect(find.text('โหมดมืด'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('THEME_MODE'), 'light');
    },
  );

  // ═══════════════════════════════════════════════════════════════════
  // Login
  // ═══════════════════════════════════════════════════════════════════

  testWidgets('กดเข้าใช้งานโดยไม่กรอก → แจ้งเตือน และ focus กลับช่องชื่อ', (
    tester,
  ) async {
    await pumpLoginPage(tester);

    await tester.ensureVisible(find.text('เข้าใช้งาน'));
    await tester.tap(find.text('เข้าใช้งาน'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกชื่อเข้าใช้งาน'), findsOneWidget);
    expect(focusedLabel(), 'username');
  });

  testWidgets('รหัสผิด → แสดงข้อความผิดพลาด', (tester) async {
    SharedPreferences.setMockInitialValues({'USERNAME': 'doctor_demo_01'});
    FlutterSecureStorage.setMockInitialValues({'PASSWORD': 'wrong'});

    await pumpLoginPage(
      tester,
      client: loginClient(
        loginBody: {
          'code': 401,
          'message': 'username or password are incorrect',
        },
      ),
    );

    await press(tester, LogicalKeyboardKey.select);

    expect(find.text('ชื่อเข้าใช้งานหรือรหัสไม่ถูกต้อง'), findsOneWidget);
    expect(focusedLabel(), 'password');
  });

  testWidgets(
    'login สำเร็จ → ไปหน้าเลือกระบบคิว, เก็บข้อมูลผู้ใช้ และจดจำ user/pass',
    (tester) async {
      SharedPreferences.setMockInitialValues({'USERNAME': 'doctor_demo_01'});
      FlutterSecureStorage.setMockInitialValues({'PASSWORD': 'secret'});

      await pumpLoginPage(
        tester,
        client: loginClient(
          loginBody: {'token': 'token_abc', 'app_id': 'new-his'},
        ),
      );

      await press(tester, LogicalKeyboardKey.select);

      expect(find.text('เลือกระบบคิว'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(QueueModePage)),
      );
      expect(container.read(loginProvider).token, 'token_abc');
      expect(container.read(employeeInfoProvider).firstName, 'สมชาย');
      expect(
        await const FlutterSecureStorage().read(key: 'PASSWORD'),
        'secret',
      );
    },
  );

  // ═══════════════════════════════════════════════════════════════════
  // เข้าจอคิวอัตโนมัติตอนเปิดแอป (ทีวีรีสตาร์ท/ไฟดับ)
  // ═══════════════════════════════════════════════════════════════════

  group('เข้าจอคิวอัตโนมัติ', () {
    final completeSetup = jsonEncode({
      'mode': 'single',
      'rotation': 'portraitRight',
      'slots': [
        {
          'type': {'id': 1, 'name_th': 'ชนิดที่ 1'},
          'auto_rotation': true,
        },
      ],
    });

    void saveCredentialsAndSetup({String? setup}) {
      SharedPreferences.setMockInitialValues({
        'USERNAME': 'doctor_demo_01',
        'QUEUE_SETUP': ?setup,
      });
      FlutterSecureStorage.setMockInitialValues({'PASSWORD': 'secret'});
    }

    final okClient = loginClient(loginBody: {'token': 'token_abc'});

    testWidgets(
      'มี user/pass + ค่าตั้งคิวครบ → login เอง → จอคิว; Back ย้อนได้ทีละหน้า',
      (tester) async {
        saveCredentialsAndSetup(setup: completeSetup);

        await pumpLoginPage(tester, client: okClient);

        expect(find.text('DISPLAY PAGE'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('SETUP PAGE'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(QueueModePage), findsOneWidget);
      },
    );

    testWidgets('ค่าตั้งคิวไม่ครบ → ไม่เข้าเอง (รอกดเหมือนเดิม)', (
      tester,
    ) async {
      saveCredentialsAndSetup(
        setup: jsonEncode({
          'mode': 'single',
          'slots': [
            {'auto_rotation': true},
          ], // ยังไม่เลือก TYPE
        }),
      );

      await pumpLoginPage(tester, client: okClient);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(focusedLabel(), 'login');
    });

    testWidgets('เน็ตยังไม่มา → แจ้ง + ลองใหม่เองทุก 15 วิ จนเข้าได้', (
      tester,
    ) async {
      saveCredentialsAndSetup(setup: completeSetup);
      var networkUp = false;
      final client = MockClient((request) async {
        if (!networkUp) throw http.ClientException('network unreachable');
        final body = request.url.path.endsWith('userinfo')
            ? {'username': 'doctor_demo_01'}
            : {'token': 'token_abc'};
        return http.Response(jsonEncode(body), 200);
      });

      await pumpLoginPage(tester, client: client);
      expect(find.textContaining('ลองใหม่ใน 15 วินาที'), findsOneWidget);

      networkUp = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('DISPLAY PAGE'), findsOneWidget);
    });

    testWidgets('ทำครั้งเดียวต่อการเปิดแอป', (tester) async {
      saveCredentialsAndSetup(setup: completeSetup);
      LoginPage.autoStartUsed = true; // เคยเข้าเองไปแล้ว แล้วออกจากระบบกลับมา

      await pumpLoginPage(tester, client: okClient);

      expect(find.byType(LoginPage), findsOneWidget);
    });
  });
}
