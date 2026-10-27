// test/unit/queue_voice_announcer_test.dart
//
// เสียงเรียกคิว: เงื่อนไข dev 3 ข้อ, ประกอบข้อความ, คิวเสียง, กันซ้ำ, พลาดแล้วไปต่อ

import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_android_tv_queue/controller/queue_voice_announcer.dart';
import 'package:flutter_android_tv_queue/models/queue_calling_voice_text_model.dart';
import 'package:flutter_android_tv_queue/models/queue_socket_event_model.dart';
import 'package:flutter_android_tv_queue/models/voice_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_voice_player.dart';

/// template จริงจาก DEV (27/10/69)
final devTemplate = QueueCallingVoiceTextModel(
  data: {
    'prefix_name_th': 'ขอเชิญหมายเลข',
    'middle_th': 'ที่',
    'suffix_name_th': 'ค่ะ',
    'prefix_name_en': 'Queue Number',
    'middle_en': 'please proceed to',
    'suffix_name_en': null,
  },
);

QueueSocketEventModel serving({
  String bookNo = 'BKN1',
  String queue = '2SCR0001',
  String publicQueue = 'LS0001',
  String status = 'SERVING',
  String type = 'appointment_call_queue',
}) => QueueSocketEventModel(
  type: type,
  data: {
    'bookno': bookNo,
    'queue': queue,
    'public_queue': publicQueue,
    'name_th': 'ช่อง 2',
    'name_en': 'Channel 2',
    'call_queue_status': status,
  },
);

void main() {
  late FakePlayer player;
  late List<({String th, String en})> requested;
  late bool failVoice;
  late Set<String> prefixes;

  setUp(() {
    player = FakePlayer();
    requested = [];
    failVoice = false;
    prefixes = {'2SCR'};
  });

  /// เสียงปลอม = ข้อความไทยเข้ารหัส base64 → เช็คได้ว่าเล่นอะไร
  QueueVoiceAnnouncer create({DateTime Function()? now}) => QueueVoiceAnnouncer(
    fetchTemplate: () async => devTemplate,
    fetchVoice: ({required textTh, required textEn}) async {
      requested.add((th: textTh, en: textEn));
      if (failVoice) throw Exception('get-voice failed');
      return VoiceModel(
        data: {
          'audio_content': base64Encode(utf8.encode(textTh)),
          'audio_encoding': 'MP3',
        },
      );
    },
    player: player,
    prefixes: () => prefixes,
    now: now ?? DateTime.now,
  );

  // ═══════════════════════════════════════════════════════════════════

  test('ประกอบข้อความจาก template จริง', () {
    final text = QueueVoiceAnnouncer.buildText(
      devTemplate,
      const VoiceAnnouncement(
        publicQueue: 'LS0001',
        nameTh: 'ช่อง 2',
        nameEn: 'Channel 2',
      ),
    );

    expect(text.th, 'ขอเชิญหมายเลข LS0001 ที่ ช่อง 2 ค่ะ');
    expect(text.en, 'Queue Number LS0001 please proceed to Channel 2');
  });

  test('ไม่มี template (โหลดไม่ได้) → ยังพูดเลขกับช่องได้', () {
    final text = QueueVoiceAnnouncer.buildText(
      null,
      const VoiceAnnouncement(
        publicQueue: 'LS0001',
        nameTh: 'ช่อง 2',
        nameEn: '',
      ),
    );

    expect(text.th, 'LS0001 ช่อง 2');
  });

  group('เงื่อนไข dev', () {
    test('appointment_call_queue + prefix ตรง + SERVING → ประกาศ', () {
      expect(create().shouldAnnounce(serving()), isTrue);
    });

    test('สถานะอื่น (เช่น CALLING) → ไม่ประกาศ', () {
      expect(create().shouldAnnounce(serving(status: 'CALLING')), isFalse);
    });

    test('prefix ไม่ใช่ของจอนี้ → ไม่ประกาศ', () {
      expect(create().shouldAnnounce(serving(queue: 'PHM0001')), isFalse);
    });

    test('type อื่น → ไม่ประกาศ', () {
      expect(create().shouldAnnounce(serving(type: 'connected')), isFalse);
    });
  });

  test('ส่ง speaking_rate 0.7 และเล่นเสียงที่ได้', () {
    fakeAsync((async) {
      final announcer = create()..start();
      async.flushMicrotasks();

      announcer.onSocketEvent(serving());
      async.flushMicrotasks();

      expect(QueueVoiceAnnouncer.speakingRate, 0.7);
      expect(
        requested.single.en,
        'Queue Number LS0001 please proceed to Channel 2',
      );
      expect(player.played, ['ขอเชิญหมายเลข LS0001 ที่ ช่อง 2 ค่ะ']);
      expect(
        announcer.announcing.value,
        'LS0001',
        reason: 'จอไฮไลต์เลขระหว่างเล่น',
      );

      player.finish();
      async.flushMicrotasks();
      expect(announcer.announcing.value, isNull);
      announcer.dispose();
    });
  });

  test('เรียกติดกัน → เล่นทีละอันตามลำดับ ไม่ทับกัน', () {
    fakeAsync((async) {
      final announcer = create()..start();
      async.flushMicrotasks();

      announcer.onSocketEvent(serving(bookNo: 'B1', publicQueue: 'LS0001'));
      announcer.onSocketEvent(serving(bookNo: 'B2', publicQueue: 'LS0002'));
      async.flushMicrotasks();
      expect(player.played, hasLength(1));

      player.finish();
      async.flushMicrotasks();
      expect(player.played.last, contains('LS0002'));
      player.finish();
      announcer.dispose();
    });
  });

  test(
    'event ซ้ำภายใน 5 วิ → ประกาศครั้งเดียว; กดเรียกซ้ำทีหลัง → ประกาศใหม่',
    () {
      fakeAsync((async) {
        final announcer = create(now: () => DateTime(2026).add(async.elapsed))
          ..start();
        async.flushMicrotasks();

        announcer.onSocketEvent(serving());
        announcer.onSocketEvent(serving()); // คิวคู่ 2 ฝั่ง / socket ส่งซ้ำ
        async.flushMicrotasks();
        player.finish();
        async.flushMicrotasks();
        expect(player.played, hasLength(1));

        async.elapse(const Duration(seconds: 6));
        announcer.onSocketEvent(serving()); // พยาบาลกดเรียกซ้ำ
        async.flushMicrotasks();
        expect(player.played, hasLength(2));
        player.finish();
        announcer.dispose();
      });
    },
  );

  test('ค้างเกิน 5 รายการ → ทิ้งอันเก่าสุด', () {
    fakeAsync((async) {
      final announcer = create()..start();
      async.flushMicrotasks();

      for (var i = 1; i <= 8; i++) {
        announcer.onSocketEvent(serving(bookNo: 'B$i', publicQueue: 'Q$i'));
      }
      async.flushMicrotasks(); // Q1 กำลังเล่น, ค้าง Q2–Q8 → เหลือ Q4–Q8

      for (var i = 0; i < 8; i++) {
        player.finish();
        async.flushMicrotasks();
      }

      expect(player.played.map((e) => e.split(' ')[1]), [
        'Q1',
        'Q4',
        'Q5',
        'Q6',
        'Q7',
        'Q8',
      ]);
      announcer.dispose();
    });
  });

  test('get-voice พลาด → ข้าม แล้วเล่นอันถัดไปได้', () {
    fakeAsync((async) {
      final announcer = create()..start();
      async.flushMicrotasks();

      failVoice = true;
      announcer.onSocketEvent(serving(bookNo: 'B1', publicQueue: 'LS0001'));
      async.flushMicrotasks();
      expect(player.played, isEmpty);
      expect(announcer.announcing.value, isNull);

      failVoice = false;
      announcer.onSocketEvent(serving(bookNo: 'B2', publicQueue: 'LS0002'));
      async.flushMicrotasks();
      expect(player.played.single, contains('LS0002'));
      player.finish();
      announcer.dispose();
    });
  });

  test('dispose → หยุดคิวเสียง + ปิด player', () {
    fakeAsync((async) {
      final announcer = create()..start();
      async.flushMicrotasks();
      announcer.dispose();

      announcer.onSocketEvent(serving());
      async.flushMicrotasks();

      expect(player.played, isEmpty);
      expect(player.disposed, isTrue);
    });
  });
}
