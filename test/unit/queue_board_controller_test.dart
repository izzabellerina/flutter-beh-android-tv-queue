// test/unit/queue_board_controller_test.dart
//
// กติกาจอคิว (ตกลงกับผู้ใช้ 27/10/69) — ใช้ fake_async คุมเวลา

import 'package:fake_async/fake_async.dart';
import 'package:flutter_android_tv_queue/controller/queue_board_controller.dart';
import 'package:flutter_android_tv_queue/models/appointment_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_call_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_type_model.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_android_tv_queue/models/queue_socket_event_model.dart';
import 'package:flutter_android_tv_queue/models/station_board_model.dart';
import 'package:flutter_test/flutter_test.dart';

QueueConfigModel station(String type, String prefix) =>
    QueueConfigModel(data: {'queue_type': type, 'prefix': prefix});

AppointmentQueueModel appt(String bookNo, String queue) =>
    AppointmentQueueModel(
      data: {'bookno': bookNo, 'queue': queue, 'public_queue': queue},
    );

QueueSocketEventModel callEvent({String bookNo = 'BKN-X', String queue = ''}) =>
    QueueSocketEventModel(
      type: 'appointment_call_queue',
      data: {'bookno': bookNo, 'queue': queue},
    );

/// server ปลอม: ข้อมูลคิวต่อ station แก้ระหว่าง test ได้ + นับจำนวนครั้งที่ fetch
class FakeServer {
  final stations = [
    station('a', 'AAA'),
    station('b', 'BBB'),
    station('c', 'CCC'),
  ];
  final waiting = <String, List<AppointmentQueueModel>>{};
  final fetches = <String>[];
  bool failBoards = false;

  Future<List<QueueConfigModel>> fetchStations() async => stations;

  Future<StationBoardModel> fetchBoard(QueueConfigModel s) async {
    fetches.add(s.queueType);
    if (failBoards) throw Exception('down');
    return StationBoardModel(
      station: s,
      callQueue: QueueConfigCallQueueModel(
        data: {'prefix': s.prefix, 'queue_channel': []},
      ),
      waiting: waiting[s.queueType] ?? [],
      counter: const [],
    );
  }

  QueueBoardController controller({
    bool autoRotation = true,
    QueueConfigModel? selected,
  }) {
    return QueueBoardController(
      slot: QueueSlotSelection(
        type: QueueConfigTypeModel(data: {'id': 1}),
        station: selected,
        autoRotation: autoRotation,
      ),
      fetchStations: fetchStations,
      fetchBoard: fetchBoard,
      // 12:00 เวลาไทย — ไกลจากเที่ยงคืน
      now: () => DateTime.utc(2026, 10, 27, 5),
    );
  }
}

void main() {
  late FakeServer server;

  setUp(() => server = FakeServer());

  String shown(QueueBoardController c) => c.board!.station.queueType;

  // ═══════════════════════════════════════════════════════════════════
  // AUTO ROTATION
  // ═══════════════════════════════════════════════════════════════════

  group('AUTO ROTATION', () {
    test('เริ่มที่ station ที่เลือก (ถ้ามี)', () {
      fakeAsync((async) {
        final c = server.controller(selected: station('b', 'BBB'))..start();
        async.flushMicrotasks();

        expect(shown(c), 'b');
        c.dispose();
      });
    });

    test(
      'ไม่มีคิวเลย → ค้าง 10 วิ แล้วไป station ถัดไป (fetch ตอนเปลี่ยน)',
      () {
        fakeAsync((async) {
          final c = server.controller()..start();
          async.flushMicrotasks();
          expect(shown(c), 'a');

          async.elapse(const Duration(seconds: 9));
          expect(shown(c), 'a');

          async.elapse(const Duration(seconds: 1));
          expect(shown(c), 'b');
          expect(server.fetches, ['a', 'b']);

          async.elapse(const Duration(seconds: 20));
          expect(shown(c), 'a', reason: 'วนกลับ: b(10) → c(10) → a');
          c.dispose();
        });
      },
    );

    test('มีคิว → ค้าง 30 วิ → fetch ซ้ำ → เหมือนเดิม = ไปต่อ', () {
      fakeAsync((async) {
        server.waiting['a'] = [appt('B1', 'AAA0001')];
        final c = server.controller()..start();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 29));
        expect(shown(c), 'a');
        expect(server.fetches, ['a']);

        async.elapse(const Duration(seconds: 1));
        expect(server.fetches, ['a', 'a', 'b'], reason: 'fetch a ซ้ำ แล้วไป b');
        expect(shown(c), 'b');
        c.dispose();
      });
    });

    test('มีคิว → 30 วิ → fetch แล้วมีคิวเพิ่ม = ค้างต่ออีก 30 วิ', () {
      fakeAsync((async) {
        server.waiting['a'] = [appt('B1', 'AAA0001')];
        final c = server.controller()..start();
        async.flushMicrotasks();

        server.waiting['a'] = [appt('B1', 'AAA0001'), appt('B2', 'AAA0002')];
        async.elapse(const Duration(seconds: 30));
        expect(shown(c), 'a');
        expect(c.board!.waiting, hasLength(2), reason: 'แสดงข้อมูลใหม่ทันที');

        async.elapse(const Duration(seconds: 30)); // รอบนี้เหมือนเดิม
        expect(shown(c), 'b');
        c.dispose();
      });
    });

    test('socket เรียกคิวของ station อื่น → ตัดไป station นั้น', () {
      fakeAsync((async) {
        final c = server.controller()..start();
        async.flushMicrotasks();

        server.waiting['c'] = [appt('B9', 'CCC0009')];
        c.onSocketEvent(callEvent(bookNo: 'B9', queue: 'CCC0009'));
        async.elapse(QueueBoardController.debounce);

        expect(shown(c), 'c');
        // c มีคิว → ค้าง 30 วิ (ไม่ใช่ 10)
        async.elapse(const Duration(seconds: 15));
        expect(shown(c), 'c');
        c.dispose();
      });
    });

    test('ปิด AUTO ROTATION → อยู่ station เดิม, refresh ทุก 60 วิ, ไม่ตัดไป station อื่น', () {
      fakeAsync((async) {
        final c = server.controller(
          autoRotation: false,
          selected: station('b', 'BBB'),
        )..start();
        async.flushMicrotasks();

        c.onSocketEvent(callEvent(queue: 'CCC0001'));
        async.elapse(const Duration(seconds: 59));
        expect(shown(c), 'b');
        expect(server.fetches, ['b']);

        async.elapse(const Duration(seconds: 1));
        expect(server.fetches, ['b', 'b']);
        c.dispose();
      });
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // เงื่อนไข socket
  // ═══════════════════════════════════════════════════════════════════

  group('socket event ของ station ที่แสดงอยู่', () {
    void expectRefresh(QueueSocketEventModel event, {required bool refresh}) {
      fakeAsync((async) {
        server.waiting['b'] = [appt('B1', 'BBB0001')];
        final c = server.controller(
          autoRotation: false,
          selected: station('b', 'BBB'),
        )..start();
        async.flushMicrotasks();

        c.onSocketEvent(event);
        async.elapse(QueueBoardController.debounce);

        expect(server.fetches.length, refresh ? 2 : 1);
        c.dispose();
      });
    }

    test('[คิวเข้า] bookno ใหม่ + prefix ตรง → refresh', () {
      expectRefresh(callEvent(bookNo: 'NEW', queue: 'BBB0002'), refresh: true);
    });

    test('[คิวออก] bookno อยู่ในจอ + prefix ไม่ตรง (ย้ายไป station อื่น) → refresh', () {
      expectRefresh(callEvent(bookNo: 'B1', queue: 'CCC0001'), refresh: true);
    });

    test('[เปลี่ยนสถานะ] bookno อยู่ในจอ + prefix ตรง (เช่น เรียกจากคิวรอ) → refresh', () {
      expectRefresh(callEvent(bookNo: 'B1', queue: 'BBB0001'), refresh: true);
    });

    test('ไม่เกี่ยวเลย → ไม่ refresh', () {
      expectRefresh(
        callEvent(bookNo: 'OTHER', queue: 'CCC0001'),
        refresh: false,
      );
    });

    test('type อื่น (เช่น connected) → ไม่ refresh', () {
      expectRefresh(
        QueueSocketEventModel(type: 'connected', data: {'queue': 'BBB0001'}),
        refresh: false,
      );
    });

    test('หลาย event ติดกัน → fetch ครั้งเดียว', () {
      fakeAsync((async) {
        final c = server.controller(
          autoRotation: false,
          selected: station('b', 'BBB'),
        )..start();
        async.flushMicrotasks();

        for (var i = 0; i < 5; i++) {
          c.onSocketEvent(callEvent(bookNo: 'N$i', queue: 'BBB000$i'));
          async.elapse(const Duration(milliseconds: 100));
        }
        async.elapse(QueueBoardController.debounce);

        expect(server.fetches, ['b', 'b']);
        c.dispose();
      });
    });

    test('prefix ว่าง ไม่ match ทุกคิว', () {
      expect(callEvent(queue: 'ANY001').matchesPrefix(''), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // ทนทาน
  // ═══════════════════════════════════════════════════════════════════

  test('โหลดไม่ได้ → เก็บข้อมูลเดิมไว้ + แจ้ง error + ลองใหม่', () {
    fakeAsync((async) {
      final c = server.controller(
        autoRotation: false,
        selected: station('b', 'BBB'),
      )..start();
      async.flushMicrotasks();

      server.failBoards = true;
      c.refresh();
      async.elapse(QueueBoardController.debounce);
      expect(shown(c), 'b', reason: 'จอไม่ว่าง');
      expect(c.error, isNotNull);

      server.failBoards = false;
      async.elapse(QueueBoardController.emptyDwell);
      expect(c.error, isNull);
      c.dispose();
    });
  });

  test('เที่ยงคืนเวลาไทย → โหลดใหม่เอง', () {
    fakeAsync((async) {
      final c = QueueBoardController(
        slot: QueueSlotSelection(
          station: station('b', 'BBB'),
          autoRotation: false,
        ),
        fetchStations: server.fetchStations,
        fetchBoard: server.fetchBoard,
        // 23:59:30 ไทย → เที่ยงคืน + margin 5 วิ = อีก 35 วิ (ก่อน refresh สำรอง 60 วิ)
        now: () => DateTime.utc(2026, 10, 27, 16, 59, 30),
      )..start();
      async.flushMicrotasks();
      expect(server.fetches, ['b']);

      async.elapse(const Duration(seconds: 34));
      expect(server.fetches, ['b']);
      async.elapse(const Duration(seconds: 1));
      expect(server.fetches, ['b', 'b']);
      c.dispose();
    });
  });
}
