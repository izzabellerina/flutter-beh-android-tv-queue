// test/widget/queue_setup_flow_test.dart
//
// หน้าเลือกระบบคิว → หน้าตั้งค่าคิว ด้วยปุ่มรีโมท (ลูกศร / select / Back)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_android_tv_queue/helper/queue_date.dart';
import 'package:flutter_android_tv_queue/models/login_model.dart';
import 'package:flutter_android_tv_queue/pages/queue_display_page.dart';
import 'package:flutter_android_tv_queue/pages/queue_mode_page.dart';
import 'package:flutter_android_tv_queue/pages/queue_setup_page.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/routes/router_path.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/tv/tv_traversal_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/queue_fixtures.dart';
import '../helpers/fake_socket.dart';
import '../helpers/fake_voice_player.dart';

void main() {
  late List<Uri> requests;
  late bool failTypes;
  late FakePlayer player;
  late List<String> voiceRequests;

  // ═══════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════

  MockClient apiClient() {
    return MockClient((request) async {
      requests.add(request.url);
      final url = request.url.toString();

      Map<String, dynamic> body;
      if (url.contains('get-all-queue-config-type')) {
        if (failTypes) return http.Response('{}', 500);
        body = queueConfigTypesResponse();
      } else if (url.contains('get-all-queue-config?')) {
        final typeId = int.parse(
          request.url.queryParameters['queue_config_type_id']!,
        );
        body = queueConfigsResponse(typeId);
      } else if (url.contains(
        'get-one-queue-config-call-queue-by-queue-type',
      )) {
        body = screeningCallQueueResponse();
      } else if (url.contains('get-last-one-queue-calling-voice-text')) {
        body = {
          'data': {
            'prefix_name_th': 'ขอเชิญหมายเลข',
            'middle_th': 'ที่',
            'suffix_name_th': 'ค่ะ',
          },
        };
      } else if (url.contains('queue/get-voice')) {
        final textTh = (jsonDecode(request.body) as Map)['text_th'] as String;
        voiceRequests.add(textTh);
        body = {
          'data': {'audio_content': base64Encode(utf8.encode(textTh))},
        };
      } else if (url.contains('get-all-appointment-bookeddate-by-queue')) {
        body = {'data': []};
      } else {
        return http.Response('{}', 404);
      }

      return http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    String initialLocation = RouterPath.queueMode,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RouterPath.login,
          builder: (_, _) => const Scaffold(body: Text('LOGIN PAGE')),
        ),
        GoRoute(
          path: RouterPath.queueMode,
          builder: (_, _) => const QueueModePage(),
        ),
        GoRoute(
          path: RouterPath.queueSetup,
          builder: (_, _) => const QueueSetupPage(),
        ),
        GoRoute(
          path: RouterPath.queueDisplay,
          builder: (_, _) => const QueueDisplayPage(),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(apiClient()),
        socketConnectorProvider.overrideWithValue(FakeSocketServer().connect),
        voicePlayerFactoryProvider.overrideWithValue(() => player),
        loginProvider.overrideWith(
          (ref) => LoginModel(data: {'token': 'token_abc'}),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: TvTraversalPolicy.builder,
          theme: AppTheme.dark,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  String? focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  setUpAll(() => initializeDateFormatting('th'));

  setUp(() {
    requests = [];
    failTypes = false;
    player = FakePlayer();
    voiceRequests = [];
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════════════
  // หน้าเลือกระบบคิว
  // ═══════════════════════════════════════════════════════════════════

  group('หน้าเลือกระบบคิว', () {
    testWidgets(
      'focus เริ่มที่คิวเดี่ยว → ขวา = คิวคู่ → OK = หน้าตั้งค่า 2 ชุดซ้าย–ขวา',
      (tester) async {
        final container = await pumpApp(tester);
        expect(focusedLabel(), 'mode-single');

        await press(tester, LogicalKeyboardKey.arrowRight);
        expect(focusedLabel(), 'mode-dual');

        await press(tester, LogicalKeyboardKey.select);
        expect(find.byType(QueueSetupPage), findsOneWidget);
        expect(find.text('คิวที่ 1'), findsOneWidget);
        expect(find.text('คิวที่ 2'), findsOneWidget);
        expect(container.read(queueSlotsProvider), hasLength(2));

        // ซ้าย–ขวา: คิวที่ 2 อยู่ขวาของคิวที่ 1 ในแถวเดียวกัน
        final left = tester.getTopLeft(find.text('คิวที่ 1'));
        final right = tester.getTopLeft(find.text('คิวที่ 2'));
        expect(right.dx, greaterThan(left.dx));
        expect(right.dy, left.dy);
      },
    );

    testWidgets('มีค่าที่เคยบันทึก → focus โหมดเดิม + เติมค่าในฟอร์ม', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'QUEUE_SETUP': jsonEncode({
          'mode': 'dual',
          'slots': [
            {
              'type': queueConfigTypesResponse()['data'][0],
              'auto_rotation': true,
            },
            {
              'type': queueConfigTypesResponse()['data'][1],
              'auto_rotation': false,
            },
          ],
        }),
      });

      await pumpApp(tester);
      expect(focusedLabel(), 'mode-dual');

      await press(tester, LogicalKeyboardKey.select);
      expect(find.text('แผนกตรวจตา'), findsOneWidget);
      expect(find.text('แผนกเด็ก'), findsOneWidget);
    });

    testWidgets('Back บนรีโมท = ออกจากระบบ → หน้า login และล้าง token', (
      tester,
    ) async {
      final container = await pumpApp(tester);

      await back(tester);

      expect(find.text('LOGIN PAGE'), findsOneWidget);
      expect(container.read(loginProvider).token, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // หน้าตั้งค่าคิว
  // ═══════════════════════════════════════════════════════════════════

  // บนทีวีจริงเคยเจอ: ลงจากคอลัมน์ซ้ายแล้วไปโดน Go Back (ล่างซ้าย) จนย้อนกลับหน้าเดิม
  testWidgets('คิวคู่: กดลงจนสุดจากคอลัมน์ไหนก็ไปที่ปุ่ม "เริ่มแสดงคิว"', (
    tester,
  ) async {
    await pumpApp(tester);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select); // คิวคู่

    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focusedLabel(), 'start');

    // คอลัมน์ขวา: ขึ้นกลับไปบนสุด → ขวา → ลงจนสุด
    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.arrowUp);
    }
    await press(tester, LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(focusedLabel(), 'start');
  });

  group('หน้าตั้งค่าคิว (คิวเดี่ยว)', () {
    Future<ProviderContainer> openSingleSetup(WidgetTester tester) async {
      final container = await pumpApp(tester);
      await press(tester, LogicalKeyboardKey.select); // คิวเดี่ยว
      expect(find.byType(QueueSetupPage), findsOneWidget);
      return container;
    }

    testWidgets('เลือก TYPE → STATION → DOCTOR ด้วยรีโมท', (tester) async {
      final container = await openSingleSetup(tester);

      // TYPE (focus อยู่แล้ว)
      await press(tester, LogicalKeyboardKey.select);
      expect(find.text('เลือก TYPE'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.select); // รายการแรก = แผนกตรวจตา
      expect(find.text('เลือก TYPE'), findsNothing);
      expect(find.text('แผนกตรวจตา'), findsOneWidget);

      // STATION
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.select);
      expect(find.text('Refraction'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.select); // Screening 1
      expect(find.text('Screening 1'), findsOneWidget);

      // DOCTOR — รายการแรก "ไม่ระบุแพทย์" → ลง 1 = หมอ
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.select);
      expect(find.text('ไม่ระบุแพทย์'), findsOneWidget);
      expect(find.text('ช่อง 2'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.select);
      expect(find.text('พญ. ธนวัฒน์ แก้วพรหม'), findsOneWidget);

      final slot = container.read(queueSlotsProvider).single;
      expect(slot.type?.id, 1);
      expect(slot.station?.queueType, 'screening');
      expect(slot.doctor?.emp, 'EMP000001');

      // วันที่ใน path = วันนี้ตามเวลาไทย
      final doctorRequest = requests.singleWhere(
        (u) => u.path.contains('get-one-queue-config-call-queue-by-queue-type'),
      );
      expect(doctorRequest.pathSegments.last, QueueDate.today());
      expect(
        doctorRequest.pathSegments[doctorRequest.pathSegments.length - 2],
        'screening',
      );
    });

    testWidgets(
      'เปลี่ยน TYPE → STATION ถูกล้าง และโหลด STATION ของ TYPE ใหม่',
      (tester) async {
        final container = await openSingleSetup(tester);

        await press(tester, LogicalKeyboardKey.select);
        await press(tester, LogicalKeyboardKey.select); // แผนกตรวจตา
        await press(tester, LogicalKeyboardKey.arrowDown);
        await press(tester, LogicalKeyboardKey.select);
        await press(tester, LogicalKeyboardKey.select); // Screening 1

        await press(tester, LogicalKeyboardKey.arrowUp); // กลับ TYPE
        await press(tester, LogicalKeyboardKey.select);
        await press(tester, LogicalKeyboardKey.arrowDown);
        await press(tester, LogicalKeyboardKey.select); // แผนกเด็ก

        expect(container.read(queueSlotsProvider).single.station, isNull);
        expect(find.text('Screening 1'), findsNothing);

        await press(tester, LogicalKeyboardKey.arrowDown);
        await press(tester, LogicalKeyboardKey.select);
        expect(find.text('Kids 1'), findsOneWidget);
      },
    );

    testWidgets(
      'Back ใน sheet = ปิดโดยไม่เปลี่ยนค่า, Back อีกครั้ง = กลับหน้าเลือกระบบคิว',
      (tester) async {
        final container = await openSingleSetup(tester);

        await press(tester, LogicalKeyboardKey.select);
        expect(find.text('เลือก TYPE'), findsOneWidget);
        await back(tester);
        expect(find.text('เลือก TYPE'), findsNothing);
        expect(container.read(queueSlotsProvider).single.type, isNull);

        await back(tester);
        expect(find.byType(QueueModePage), findsOneWidget);
      },
    );

    testWidgets('โหลดพลาด → "ลองใหม่" แล้วโหลดได้', (tester) async {
      await openSingleSetup(tester);
      failTypes = true;

      await press(tester, LogicalKeyboardKey.select);
      expect(find.text('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);

      failTypes = false;
      await press(tester, LogicalKeyboardKey.select); // ปุ่มลองใหม่ (autofocus)
      expect(find.text('แผนกตรวจตา'), findsOneWidget);
    });

    testWidgets(
      'ยังไม่เลือก TYPE → แจ้งเตือน; เลือกแล้ว → บันทึกค่า + ไปจอคิว',
      (tester) async {
        await openSingleSetup(tester);

        await tester.tap(find.text('เริ่มแสดงคิว'));
        await tester.pumpAndSettle();
        expect(find.text('กรุณาเลือก TYPE'), findsOneWidget);
        expect(find.byType(QueueDisplayPage), findsNothing);

        await press(tester, LogicalKeyboardKey.select);
        await press(
          tester,
          LogicalKeyboardKey.select,
        ); // แผนกตรวจตา (AUTO ROTATION เปิดอยู่ → ไม่ต้องเลือก STATION)
        await tester.tap(find.text('เริ่มแสดงคิว'));
        await tester.pumpAndSettle();

        expect(find.byType(QueueDisplayPage), findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        final saved = jsonDecode(prefs.getString('QUEUE_SETUP')!);
        expect(saved['mode'], 'single');
        expect(saved['slots'][0]['type']['id'], 1);
        expect(saved['voice'], isTrue);
      },
    );

    testWidgets(
      'ปุ่มทดสอบเสียง → เรียก get-voice จริงด้วยคิวตัวอย่าง แล้วเล่น',
      (tester) async {
        await openSingleSetup(tester);

        await tester.tap(find.text('ทดสอบเสียง'));
        await tester.pumpAndSettle();

        expect(voiceRequests, ['ขอเชิญหมายเลข A001 ที่ ช่อง 1 ค่ะ']);
        expect(player.played, hasLength(1));
        expect(find.text('กำลังเล่นเสียงทดสอบ…'), findsOneWidget);
        player.finish();
      },
    );

    testWidgets('สวิตช์เสียง → ปิด แล้วบันทึกไปกับค่าตั้งคิว', (tester) async {
      await openSingleSetup(tester);

      await tester.tap(find.text('เสียง: เปิด'));
      await tester.pumpAndSettle();
      expect(find.text('เสียง: ปิด'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.select); // TYPE
      await press(tester, LogicalKeyboardKey.select); // แผนกตรวจตา
      await tester.tap(find.text('เริ่มแสดงคิว'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('QUEUE_SETUP')!)['voice'], isFalse);
    });
  });
}
