// test/unit/queue_setup_test.dart
//
// วันที่เวลาไทย, รวมรายชื่อแพทย์จาก response, ค่าที่เลือกในฟอร์มคิว

import 'dart:convert';

import 'package:flutter_android_tv_queue/helper/queue_date.dart';
import 'package:flutter_android_tv_queue/models/employee_info_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_call_queue_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';
import 'package:flutter_android_tv_queue/models/queue_config_type_model.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/queue_fixtures.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // QueueDate — เปลี่ยนวันตอนเที่ยงคืนเวลาไทย ไม่ใช่เที่ยงคืน UTC/เครื่อง
  // ═══════════════════════════════════════════════════════════════════

  group('QueueDate.today', () {
    test('23:59:59 เวลาไทย = ยังเป็นวันเดิม', () {
      // 16:59:59 UTC = 23:59:59 ไทย
      expect(
        QueueDate.today(now: DateTime.utc(2026, 10, 26, 16, 59, 59)),
        '2026-10-26',
      );
    });

    test('00:00:00 เวลาไทย = วันใหม่ทันที', () {
      // 17:00:00 UTC = 00:00 ไทยของวันถัดไป
      expect(
        QueueDate.today(now: DateTime.utc(2026, 10, 26, 17)),
        '2026-10-27',
      );
    });

    test('ข้ามเดือน/ปี', () {
      expect(
        QueueDate.today(now: DateTime.utc(2026, 12, 31, 17)),
        '2027-01-01',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // scheduledDoctors — จาก queue_channel[*].queue_config_schedule[*].employee
  // ═══════════════════════════════════════════════════════════════════

  group('QueueConfigCallQueueModel.scheduledDoctors', () {
    QueueConfigCallQueueModel parse(Map<String, dynamic> response) {
      // ผ่าน jsonEncode/Decode ให้ได้ Map แบบเดียวกับที่ service ได้จริง
      final json = Map.from(jsonDecode(jsonEncode(response)));
      return QueueConfigCallQueueModel(data: json['data']);
    }

    test('response จริง: หมอคนเดียวอยู่ 2 channel → ได้ 1 คน, ห้องไม่ซ้ำ', () {
      final doctors = parse(screeningCallQueueResponse()).scheduledDoctors;

      expect(doctors, hasLength(1));
      expect(doctors.single.employee.emp, 'EMP000001');
      expect(doctors.single.employee.fullnameWithMid, 'พญ. ธนวัฒน์ แก้วพรหม');
      expect(doctors.single.rooms, ['ช่อง 2']);
    });

    test('ไม่นับ data.employee (ไม่ได้อยู่ในตาราง)', () {
      final doctors = parse(screeningCallQueueResponse()).scheduledDoctors;

      expect(doctors.map((d) => d.employee.emp), isNot(contains('EMP000006')));
    });

    test('หลายคน หลายห้อง — เรียงตามลำดับที่เจอ', () {
      final drA = employee(
        id: 2,
        emp: 'EMP000002',
        firstname: 'ก',
        lastname: 'ข',
      );
      final response = screeningCallQueueResponse();
      (response['data'] as Map)['queue_channel'] = [
        channel(id: 1, roomTh: 'ห้อง 1', schedules: [schedule(drThanawat)]),
        channel(
          id: 2,
          roomTh: 'ห้อง 2',
          schedules: [schedule(drA), schedule(drThanawat)],
        ),
      ];

      final doctors = parse(response).scheduledDoctors;

      expect(doctors.map((d) => d.employee.emp), ['EMP000001', 'EMP000002']);
      expect(doctors.first.rooms, ['ห้อง 1', 'ห้อง 2']);
    });

    test('ไม่มีตารางเลย → รายการว่าง', () {
      final response = screeningCallQueueResponse();
      (response['data'] as Map)['queue_channel'] = [
        channel(id: 8, roomTh: 'ช่อง 1'),
      ];

      expect(parse(response).scheduledDoctors, isEmpty);
    });

    test('field วันที่เป็น null ไม่ throw (tryParse)', () {
      final channel = parse(screeningCallQueueResponse()).queueChannel.first;

      expect(channel.deletedAt, isNull);
      expect(channel.startDate, isNull);
      expect(channel.queueConfigSchedule, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // EmployeeInfoModel.fullnameWithMid
  // ═══════════════════════════════════════════════════════════════════

  test('fullnameWithMid ใส่ชื่อกลางเมื่อมี และข้ามเมื่อว่าง/null', () {
    String nameOf(String? mid) => EmployeeInfoModel(
      data: employee(
        id: 1,
        emp: 'E',
        firstname: 'สมชาย',
        midname: mid,
        lastname: 'ใจดี',
      ),
    ).fullnameWithMid;

    expect(nameOf('ธรรม'), 'พญ. สมชาย ธรรม ใจดี');
    expect(nameOf(''), 'พญ. สมชาย ใจดี');
    expect(nameOf(null), 'พญ. สมชาย ใจดี');
  });

  // ═══════════════════════════════════════════════════════════════════
  // QueueSlotSelection
  // ═══════════════════════════════════════════════════════════════════

  group('QueueSlotSelection', () {
    final eye = QueueConfigTypeModel(data: {'id': 1, 'name_th': 'แผนกตรวจตา'});
    final kids = QueueConfigTypeModel(data: {'id': 2, 'name_th': 'แผนกเด็ก'});
    final screening = QueueConfigModel(data: {'queue_type': 'screening'});
    final doctor = EmployeeInfoModel(data: drThanawat);

    final full = const QueueSlotSelection()
        .selectType(eye)
        .selectStation(screening)
        .selectDoctor(doctor)
        .withAutoRotation(false);

    test('เปลี่ยน TYPE → ล้าง STATION และ DOCTOR, เก็บ AUTO ROTATION', () {
      final changed = full.selectType(kids);

      expect(changed.type?.id, 2);
      expect(changed.station, isNull);
      expect(changed.doctor, isNull);
      expect(changed.autoRotation, isFalse);
    });

    test('เลือก TYPE เดิมซ้ำ → ไม่ล้างค่า', () {
      expect(full.selectType(eye).doctor, isNotNull);
    });

    test('เปลี่ยน STATION → ล้าง DOCTOR', () {
      final changed = full.selectStation(
        QueueConfigModel(data: {'queue_type': 'refraction'}),
      );

      expect(changed.type?.id, 1);
      expect(changed.doctor, isNull);
    });

    test('validate: TYPE บังคับ, STATION บังคับเมื่อปิด AUTO ROTATION, DOCTOR ไม่บังคับ', () {
      expect(const QueueSlotSelection().validate(), 'กรุณาเลือก TYPE');
      expect(QueueSlotSelection(type: eye).validate(), isNull);
      expect(
        QueueSlotSelection(type: eye, autoRotation: false).validate(),
        contains('STATION'),
      );
      expect(
        QueueSlotSelection(
          type: eye,
          station: screening,
          autoRotation: false,
        ).validate(),
        isNull,
      );
    });

    test('toJson → jsonEncode → fromJson ได้ค่าเดิม', () {
      final restored = QueueSlotSelection.fromJson(
        jsonDecode(jsonEncode(full.toJson())),
      );

      expect(restored.type?.id, 1);
      expect(restored.station?.queueType, 'screening');
      expect(restored.doctor?.emp, 'EMP000001');
      expect(restored.autoRotation, isFalse);
    });
  });
}
