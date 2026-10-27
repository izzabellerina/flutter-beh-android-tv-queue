// test/widget/queue_display_page_test.dart
//
// หน้าจอคิว: คิวคู่ / คิวเดี่ยวแนวตั้ง, การ์ดแพทย์, socket → refresh, "+N", Back, กันจอดับ

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_android_tv_queue/enum/display_rotation.dart';
import 'package:flutter_android_tv_queue/enum/queue_mode.dart';
import 'package:flutter_android_tv_queue/models/employee_info_model.dart';
import 'package:flutter_android_tv_queue/models/login_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_type_model.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_android_tv_queue/pages/queue_display_page.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/routes/router_path.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/queue_fixtures.dart';
import '../helpers/fake_socket.dart';
import '../helpers/fake_voice_player.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // server ปลอม — แก้ข้อมูลระหว่าง test ได้
  // ═══════════════════════════════════════════════════════════════════

  /// queue_type → public_queue ที่กำลังตรวจ (null = ไม่มี)
  late Map<String, String?> current;

  /// "prefix|STATUS" → รายการ public_queue
  late Map<String, List<String>> lists;
  late FakeSocketServer socketServer;
  late List<bool> keepScreenOnCalls;
  late FakePlayer player;

  /// text_th ที่ส่งไป get-voice
  late List<String> voiceRequests;

  final screening = QueueConfigModel(
    data: {
      'queue_type': 'screening',
      'prefix': '2SCR',
      'description': 'Screening 1',
    },
  );
  final refraction = QueueConfigModel(
    data: {
      'queue_type': 'refraction',
      'prefix': '2REF',
      'description': 'Refraction',
    },
  );
  final type = QueueConfigTypeModel(data: {'id': 1, 'name_th': 'ชนิดที่ 1'});
  final doctor = EmployeeInfoModel(
    data: {
      ...drThanawat,
      'firstname_en': 'Thanawat',
      'lastname_en': 'Kaewphrom',
      'license_number': '012556245',
    },
  );

  Map<String, dynamic> callQueueFor(String queueType) {
    final response = screeningCallQueueResponse();
    final data = response['data'] as Map<String, dynamic>;
    data['queue_type'] = queueType;
    data['prefix'] = queueType == 'screening' ? '2SCR' : '2REF';
    // ของจริง: screening มี building_room, station อื่นเป็น null
    data['building_room'] = queueType == 'screening'
        ? {'id': 23, 'name_th': 'ห้องสกรีนนิ่ง', 'name_en': 'Screening Room'}
        : null;
    final number = current[queueType];
    (data['queue_channel'] as List).first['appointment_call_queue'] =
        number == null
        ? null
        : {
            'bookno': 'BKN-$number',
            'queue': '${data['prefix']}0001',
            'public_queue': number,
          };
    return response;
  }

  MockClient apiClient() => MockClient((request) async {
    final url = request.url;
    Object body;
    if (url.path.contains('get-one-queue-config-call-queue-by-queue-type')) {
      body = callQueueFor(url.pathSegments[url.pathSegments.length - 2]);
    } else if (url.path.contains('get-all-appointment-bookeddate-by-queue')) {
      final key =
          '${url.queryParameters['queue_prefix']}|${url.queryParameters['call_queue_status']}';
      body = {
        'data': [
          for (final q in lists[key] ?? const <String>[])
            {'bookno': 'BKN-$q', 'queue': q, 'public_queue': q},
        ],
      };
    } else if (url.path.contains('get-last-one-queue-calling-voice-text')) {
      body = {
        'data': {
          'prefix_name_th': 'ขอเชิญหมายเลข',
          'middle_th': 'ที่',
          'suffix_name_th': 'ค่ะ',
          'prefix_name_en': 'Queue Number',
          'middle_en': 'please proceed to',
        },
      };
    } else if (url.path.contains('queue/get-voice')) {
      final json = jsonDecode(request.body) as Map;
      voiceRequests.add(json['text_th']);
      expect(json['speaking_rate'], 0.7);
      body = {
        'data': {
          'audio_content': base64Encode(utf8.encode(json['text_th'])),
          'audio_encoding': 'MP3',
        },
      };
    } else if (url.path.contains('get-all-queue-config')) {
      body = {
        'data': [screening.data, refraction.data],
      };
    } else {
      return http.Response('{}', 404);
    }
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });

  Future<GoRouter> pumpDisplay(
    WidgetTester tester, {
    required QueueMode mode,
    required List<QueueSlotSelection> slots,
    DisplayRotation rotation = DisplayRotation.portraitRight,
    bool voiceEnabled = true,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: RouterPath.queueSetup,
      routes: [
        GoRoute(
          path: RouterPath.queueSetup,
          builder: (_, _) => const Scaffold(body: Text('SETUP PAGE')),
        ),
        GoRoute(
          path: RouterPath.queueDisplay,
          builder: (_, _) => const QueueDisplayPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          httpClientProvider.overrideWithValue(apiClient()),
          socketConnectorProvider.overrideWithValue(socketServer.connect),
          voicePlayerFactoryProvider.overrideWithValue(() => player),
          voiceEnabledProvider.overrideWith((ref) => voiceEnabled),
          loginProvider.overrideWith(
            (ref) => LoginModel(data: {'token': 'tk'}),
          ),
          queueModeProvider.overrideWith((ref) => mode),
          queueSlotsProvider.overrideWith((ref) => slots),
          displayRotationProvider.overrideWith((ref) => rotation),
        ],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
      ),
    );
    router.push(RouterPath.queueDisplay);
    await tester.pumpAndSettle();
    return router;
  }

  setUp(() {
    current = {'screening': 'LS0001', 'refraction': null};
    lists = {};
    socketServer = FakeSocketServer();
    keepScreenOnCalls = [];
    player = FakePlayer();
    voiceRequests = [];
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.panudet789.flutter_android_tv_queue/screen'),
          (call) async {
            keepScreenOnCalls.add(call.arguments as bool);
            return null;
          },
        );
  });

  // ═══════════════════════════════════════════════════════════════════

  testWidgets(
    'คิวคู่: 2 บอร์ดซ้าย–ขวา, ห้อง/กำลังตรวจ/คิวรอ, การ์ดแพทย์เฉพาะชุดที่เลือก',
    (tester) async {
      lists['2SCR|CALLING'] = ['LS0002', 'LS0003'];
      lists['2SCR|DENIED'] = ['LS0009'];

      await pumpDisplay(
        tester,
        mode: QueueMode.dual,
        slots: [
          QueueSlotSelection(
            type: type,
            station: screening,
            doctor: doctor,
            autoRotation: false,
          ),
          QueueSlotSelection(
            type: type,
            station: refraction,
            autoRotation: false,
          ),
        ],
      );

      // ห้อง: building_room / ไม่มี → ชื่อ station
      expect(find.text('ห้องสกรีนนิ่ง'), findsOneWidget);
      expect(find.text('Refraction'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Refraction')).dx,
        greaterThan(tester.getCenter(find.text('ห้องสกรีนนิ่ง')).dx),
      );

      // กำลังตรวจ / คิวรอ / ติดต่อเคาน์เตอร์
      expect(find.text('LS0001'), findsOneWidget);
      expect(find.text('LS0002'), findsOneWidget);
      expect(find.text('LS0009'), findsOneWidget);

      // แพทย์: ชุด 1 เลือก → แสดง (ไทย + อังกฤษ + license), ชุด 2 ไม่เลือก → ไม่มีการ์ด
      expect(find.text('พญ. ธนวัฒน์ แก้วพรหม'), findsOneWidget);
      expect(find.text('Dr. Thanawat Kaewphrom'), findsOneWidget);
      expect(find.text('License Number : 012556245'), findsOneWidget);
    },
  );

  testWidgets('คิวเดี่ยวแนวตั้ง → หมุนภาพ 90°', (tester) async {
    await pumpDisplay(
      tester,
      mode: QueueMode.single,
      slots: [
        QueueSlotSelection(type: type, station: screening, autoRotation: false),
      ],
    );

    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
    expect(find.text('LS0001'), findsOneWidget);
    expect(find.text('SCREENING ROOM'), findsOneWidget);
  });

  testWidgets('คิวเดี่ยวบนทีวีแนวนอน → ไม่หมุน', (tester) async {
    await pumpDisplay(
      tester,
      mode: QueueMode.single,
      slots: [
        QueueSlotSelection(type: type, station: screening, autoRotation: false),
      ],
      rotation: DisplayRotation.landscape,
    );

    expect(find.byType(RotatedBox), findsNothing);
    expect(find.text('LS0001'), findsOneWidget);
  });

  testWidgets('socket เรียกคิว → refresh → เลขกำลังตรวจเปลี่ยน', (
    tester,
  ) async {
    lists['2SCR|CALLING'] = ['LS0002'];
    await pumpDisplay(
      tester,
      mode: QueueMode.single,
      slots: [
        QueueSlotSelection(type: type, station: screening, autoRotation: false),
      ],
    );
    expect(find.text('LS0001'), findsOneWidget);

    // พยาบาลเรียก LS0002 จากคิวรอ (bookno อยู่ในจอ + prefix ตรง)
    current['screening'] = 'LS0002';
    lists['2SCR|CALLING'] = [];
    socketServer.last.callQueue(bookNo: 'BKN-LS0002', queue: '2SCR0002');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('LS0001'), findsNothing);
    expect(find.text('LS0002'), findsOneWidget);
  });

  testWidgets('คิวรอเกินที่ → แสดงเท่าที่พอ + "+N"', (tester) async {
    lists['2SCR|CALLING'] = [
      for (var i = 1; i <= 11; i++) 'Q${i.toString().padLeft(3, '0')}',
    ];
    await pumpDisplay(
      tester,
      mode: QueueMode.single,
      slots: [
        QueueSlotSelection(type: type, station: screening, autoRotation: false),
      ],
    );

    // คิวเดี่ยว: คิวรอ 3 แถว × 3 = 9 ช่อง → 8 คิว + "+3"
    expect(find.text('Q008'), findsOneWidget);
    expect(find.text('Q009'), findsNothing);
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('Back = กลับหน้าตั้งค่า; เข้าหน้า = กันจอดับ, ออก = ปล่อย', (
    tester,
  ) async {
    await pumpDisplay(
      tester,
      mode: QueueMode.single,
      slots: [
        QueueSlotSelection(type: type, station: screening, autoRotation: false),
      ],
    );
    expect(keepScreenOnCalls, [true]);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('SETUP PAGE'), findsOneWidget);
    expect(keepScreenOnCalls, [true, false]);
    expect(socketServer.last.closed, isTrue);
  });

  // ═══════════════════════════════════════════════════════════════════
  // เสียงเรียกคิว
  // ═══════════════════════════════════════════════════════════════════

  void callServing({String publicQueue = 'LS0002', String queue = '2SCR0002'}) {
    socketServer.last.send({
      'type': 'appointment_call_queue',
      'data': {
        'bookno': 'BKN-$publicQueue',
        'queue': queue,
        'public_queue': publicQueue,
        'name_th': 'ช่อง 2',
        'name_en': 'Channel 2',
        'call_queue_status': 'SERVING',
      },
    });
  }

  testWidgets(
    'พยาบาลกดเรียก (SERVING) → ประกาศเสียง + ไฮไลต์เลขที่ขึ้นกำลังตรวจ',
    (tester) async {
      await pumpDisplay(
        tester,
        mode: QueueMode.single,
        slots: [
          QueueSlotSelection(
            type: type,
            station: screening,
            autoRotation: false,
          ),
        ],
      );

      current['screening'] = 'LS0002';
      callServing();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(voiceRequests, ['ขอเชิญหมายเลข LS0002 ที่ ช่อง 2 ค่ะ']);
      expect(player.played, ['ขอเชิญหมายเลข LS0002 ที่ ช่อง 2 ค่ะ']);
      expect(find.text('LS0002'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('announcing-highlight')),
        findsOneWidget,
      );

      player.finish();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('announcing-highlight')), findsNothing);
    },
  );

  testWidgets('คิวของ station อื่น (prefix ไม่ใช่ของจอนี้) → ไม่ประกาศ', (
    tester,
  ) async {
    await pumpDisplay(
      tester,
      mode: QueueMode.single,
      slots: [
        QueueSlotSelection(type: type, station: screening, autoRotation: false),
      ],
    );

    callServing(publicQueue: 'PH0001', queue: 'PHM0001');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(voiceRequests, isEmpty);
  });

  testWidgets('ปิดเสียงในหน้าตั้งค่า → ไม่ประกาศ', (tester) async {
    await pumpDisplay(
      tester,
      mode: QueueMode.single,
      slots: [
        QueueSlotSelection(type: type, station: screening, autoRotation: false),
      ],
      voiceEnabled: false,
    );

    callServing();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(voiceRequests, isEmpty);
    expect(player.played, isEmpty);
  });
}
