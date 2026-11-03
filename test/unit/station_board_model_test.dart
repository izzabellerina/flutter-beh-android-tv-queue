// test/unit/station_board_model_test.dart
//
// กำลังตรวจ: queue_channel ตัวเดียว / หลายตัว, ช่องที่ไม่มีคิว, signature + containsBookNo รวมทุกช่อง

import 'package:flutter_android_tv_queue/models/appointment_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_call_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';
import 'package:flutter_android_tv_queue/models/station_board_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/queue_fixtures.dart';

void main() {
  /// ชื่อช่อง → public_queue ที่กำลังเรียก (null = ยังไม่มีคิว)
  StationBoardModel board(
    Map<String, String?> calls, {
    List<AppointmentQueueModel> waiting = const [],
  }) => StationBoardModel(
    station: QueueConfigModel(data: {'prefix': '2SCR'}),
    callQueue: QueueConfigCallQueueModel(
      data: {
        'prefix': '2SCR',
        'queue_channel': [
          for (final (i, MapEntry(:key, :value)) in calls.entries.indexed)
            {
              ...channel(id: i + 1, roomTh: key),
              'appointment_call_queue': value == null
                  ? null
                  // เหมือน production: appointment_call_queue ใช้ status_tbooknoh
                  : {'status_tbooknoh': 'BKN-$value', 'public_queue': value},
            },
        ],
      },
    ),
    waiting: waiting,
    counter: const [],
  );

  test('channel เดียว → ไม่ใช่แบบหลายช่อง, current = คิวของช่องนั้น', () {
    final b = board({'ช่อง 1': 'C0025'});

    expect(b.hasMultipleChannels, isFalse);
    expect(b.current?.publicQueue, 'C0025');
  });

  test(
    'หลาย channel → ทุกช่องตามลำดับ API + ชื่อช่องจาก name_th, ช่องว่าง = null',
    () {
      final b = board({'ช่อง 1': 'C0025', 'ห้อง 4': null, 'ช่อง 2': 'C0031'});

      expect(b.hasMultipleChannels, isTrue);
      expect(b.currents.map((e) => e.channel), ['ช่อง 1', 'ห้อง 4', 'ช่อง 2']);
      expect(b.currents.map((e) => e.queue?.publicQueue), [
        'C0025',
        null,
        'C0031',
      ]);
    },
  );

  test('มีคิวแค่ในช่องที่ 2 → ไม่ว่าง + เจอ bookno', () {
    final b = board({'ช่อง 1': null, 'ช่อง 2': 'C0031'});

    expect(b.isEmpty, isFalse);
    expect(b.containsBookNo('BKN-C0031'), isTrue);
    expect(b.containsBookNo('BKN-C9999'), isFalse);
  });

  test('ทุกช่องว่าง + ไม่มีคิวรอ → isEmpty', () {
    expect(board({'ช่อง 1': null, 'ช่อง 2': null}).isEmpty, isTrue);
  });

  test('เลขในช่องที่ 2 เปลี่ยน → signature เปลี่ยน (fetch ใหม่ต้องรู้)', () {
    final before = board({'ช่อง 1': 'C0025', 'ช่อง 2': 'C0031'});
    final after = board({'ช่อง 1': 'C0025', 'ช่อง 2': 'C0032'});
    final same = board({'ช่อง 1': 'C0025', 'ช่อง 2': 'C0031'});

    expect(after.signature, isNot(before.signature));
    expect(same.signature, before.signature);
  });
}
