// test/widget/queue_display_page_test.dart
//
// หน้าจอคิว: คิวคู่ / คิวเดี่ยวแนวตั้ง, การ์ดแพทย์, socket → refresh, "+N", Back, กันจอดับ

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  /// คิวของ channel ที่ 2+ (index → public_queue) — fixture มี 4 channel
  late Map<int, String> otherChannels;

  /// queue_type → จำนวน queue_channel (ไม่ระบุ = 4 ตาม fixture, เกิน 4 = เติมช่องเพิ่ม)
  late Map<String, int> channelCount;

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
    // เหมือน production: appointment_call_queue ใช้ status_tbooknoh (ไม่ใช่ bookno)
    Map<String, dynamic>? call(String? number) => number == null
        ? null
        : {
            'status_tbooknoh': 'BKN-$number',
            'call_queue_status': 'SERVING',
            'queue': '${data['prefix']}0001',
            'public_queue': number,
          };

    final channels = data['queue_channel'] as List;
    final count = channelCount[queueType];
    if (count != null && count < channels.length) {
      channels.removeRange(count, channels.length);
    }
    for (var i = channels.length; i < (count ?? 0); i++) {
      channels.add(channel(id: 100 + i, roomTh: 'ช่อง ${i + 1}'));
    }
    channels.first['appointment_call_queue'] = call(current[queueType]);
    for (final MapEntry(:key, :value) in otherChannels.entries) {
      if (key < channels.length) {
        channels[key]['appointment_call_queue'] = call(value);
      }
    }
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
    otherChannels = {};
    channelCount = {};
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

  /// ป้ายชื่อช่องต้องเห็นครบ ไม่ถูกตัดเป็น "ช่..."
  void expectBadgesNotCut(WidgetTester tester) {
    for (final name in ['ช่อง 1', 'ห้อง 4', 'ช่อง 2']) {
      for (final e in find.text(name).evaluate()) {
        final paragraph = e.renderObject! as RenderParagraph;
        expect(paragraph.didExceedMaxLines, isFalse, reason: name);
      }
    }
  }

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

  testWidgets(
    'คิวกำลังตรวจถูกย้ายไป station อื่น → refresh ทันที คิวหายจากกำลังตรวจ',
    (tester) async {
      channelCount = {'screening': 1};
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
      expect(find.text('LS0001'), findsOneWidget);

      // เว็บย้าย LS0001 ไป refraction: socket bookno เดิม แต่ queue เป็น prefix ของ station ใหม่
      current['screening'] = null;
      socketServer.last.callQueue(bookNo: 'BKN-LS0001', queue: '2REF0001');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('LS0001'), findsNothing);
    },
  );

  testWidgets(
    'กำลังตรวจ หลาย channel → ทุกช่อง: เลขคิวซ้าย + ชื่อช่องขวา, ไม่มีคิว = "-"',
    (tester) async {
      otherChannels = {2: 'LS0005'};
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

      // fixture: ช่อง 1 (LS0001), ห้อง 4 (ว่าง), ช่อง 2 (LS0005), ช่อง 2 (ว่าง)
      expect(find.text('ช่อง 1'), findsOneWidget);
      expect(find.text('ห้อง 4'), findsOneWidget);
      expect(find.text('ช่อง 2'), findsNWidgets(2));
      expect(find.text('LS0001'), findsOneWidget);
      expect(find.text('LS0005'), findsOneWidget);
      expect(find.text('-'), findsNWidgets(2));

      // เรียงตาม queue_channel (หมุน 90° → ลำดับบนลงล่างอยู่บนแกน x ของจอ)
      Offset at(String text) => tester.getCenter(find.text(text).first);
      expect(at('ห้อง 4').dx, lessThan(at('ช่อง 1').dx));
      // เลขคิวกับชื่อช่องอยู่แถวเดียวกัน
      expect(at('LS0001').dx, moreOrLessEquals(at('ช่อง 1').dx, epsilon: 2));
    },
  );

  testWidgets('กำลังตรวจ channel เดียว → เลขใหญ่แบบเดิม ไม่มีชื่อช่อง', (
    tester,
  ) async {
    channelCount = {'screening': 1};
    await pumpDisplay(
      tester,
      mode: QueueMode.single,
      slots: [
        QueueSlotSelection(type: type, station: screening, autoRotation: false),
      ],
    );

    expect(find.text('LS0001'), findsOneWidget);
    expect(find.text('ช่อง 1'), findsNothing);
  });

  testWidgets('คิวคู่ + การ์ดแพทย์ 4 ช่อง → แถวเตี้ยเกิน = แบ่ง 2 คอลัมน์', (
    tester,
  ) async {
    otherChannels = {1: 'LS0004'};
    await pumpDisplay(
      tester,
      mode: QueueMode.dual,
      slots: [
        for (var i = 0; i < 2; i++)
          QueueSlotSelection(
            type: type,
            station: screening,
            doctor: doctor,
            autoRotation: false,
          ),
      ],
    );

    // fixture: [ช่อง 1 | ห้อง 4] / [ช่อง 2 | ช่อง 2] — บอร์ดแรก
    Offset at(String text) => tester.getCenter(find.text(text).first);
    expect(at('LS0001').dy, moreOrLessEquals(at('LS0004').dy, epsilon: 1));
    expect(at('LS0004').dx, greaterThan(at('LS0001').dx));
    expect(find.text('ช่อง 2'), findsNWidgets(4));
    expectBadgesNotCut(tester);
  });

  testWidgets('คิวคู่ ไม่มีการ์ดแพทย์ 4 ช่อง → ช่องละแถว, ชื่อช่องไม่ถูกตัด', (
    tester,
  ) async {
    // เหมือนจอจริงในภาพผู้ใช้: หัวมีแต่ชื่อไทย (refraction ไม่มี building_room)
    current['refraction'] = 'LS0001';
    otherChannels = {1: 'LS0004'};
    await pumpDisplay(
      tester,
      mode: QueueMode.dual,
      slots: [
        for (var i = 0; i < 2; i++)
          QueueSlotSelection(
            type: type,
            station: refraction,
            autoRotation: false,
          ),
      ],
    );

    Offset at(String text) => tester.getCenter(find.text(text).first);
    expect(at('LS0004').dy, greaterThan(at('LS0001').dy));
    expect(at('LS0004').dx, moreOrLessEquals(at('LS0001').dx, epsilon: 1));
    expectBadgesNotCut(tester);
  });

  testWidgets(
    'ช่องเยอะ + พื้นที่น้อย (คิวคู่ + การ์ดแพทย์ 12 ช่อง) → แสดงครบ ไม่ล้น',
    (tester) async {
      channelCount = {'screening': 12};
      otherChannels = {11: 'LS0012'};
      await pumpDisplay(
        tester,
        mode: QueueMode.dual,
        slots: [
          for (var i = 0; i < 2; i++)
            QueueSlotSelection(
              type: type,
              station: screening,
              doctor: doctor,
              autoRotation: false,
            ),
        ],
      );

      expect(find.text('ช่อง 12'), findsNWidgets(2));
      expect(find.text('LS0012'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AUTO ROTATION สลับ station ที่จำนวนช่องต่างกัน → ไม่ล้นระหว่างเปลี่ยน',
    (tester) async {
      // คิวคู่ + การ์ดแพทย์ = พื้นที่กำลังตรวจน้อย → 2 ช่องกับ 4 ช่องสูงไม่เท่ากัน
      channelCount = {'screening': 2, 'refraction': 4};
      await pumpDisplay(
        tester,
        mode: QueueMode.dual,
        slots: [
          QueueSlotSelection(
            type: type,
            station: screening,
            doctor: doctor,
            autoRotation: true,
          ),
          QueueSlotSelection(
            type: type,
            station: screening,
            doctor: doctor,
            autoRotation: false,
          ),
        ],
      );
      // fixture: ช่อง 1, ห้อง 4 | ช่อง 2, ช่อง 2
      expect(find.text('ห้อง 4'), findsNWidgets(2));
      expect(find.text('ช่อง 2'), findsNothing);

      // screening มีคิว → ค้าง 30 วิ → fetch ซ้ำเหมือนเดิม → ไป refraction
      await tester.pump(const Duration(seconds: 31));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(find.text('ช่อง 2'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets(
    'ปุ่มสลับโหมด: ซ่อนไว้ → กดรีโมท = โผล่ + focus → OK สลับ → ไม่กด 5 วิหาย; Back ยังกลับได้',
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
      final container = ProviderScope.containerOf(
        tester.element(find.byType(QueueDisplayPage)),
      );
      expect(find.text('โหมดสว่าง'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump();
      expect(find.text('โหมดสว่าง'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'theme-toggle');

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(find.text('โหมดมืด'), findsOneWidget);

      // กดปุ่มอื่นระหว่างแสดง = นับใหม่ → 4 วิยังอยู่, ครบ 5 วิหลังกดล่าสุดถึงหาย
      await tester.pump(const Duration(seconds: 3));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('โหมดมืด'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('โหมดมืด'), findsNothing);

      // Back ระหว่างปุ่มโผล่ ยังกลับหน้าตั้งค่า
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('SETUP PAGE'), findsOneWidget);
    },
  );

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

      expect(voiceRequests, ['ขอเชิญหมายเลข L S 0 0 0 2 ที่ ช่อง 2 ค่ะ']);
      expect(player.played, ['ขอเชิญหมายเลข L S 0 0 0 2 ที่ ช่อง 2 ค่ะ']);
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
