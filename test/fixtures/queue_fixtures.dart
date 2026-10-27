// test/fixtures/queue_fixtures.dart
//
// ย่อมาจาก response จริงของ DEV server (ผู้ใช้ส่งมา 27/10/69)
// get-one-queue-config-call-queue-by-queue-type/screening/{date}

Map<String, dynamic> employee({
  required int id,
  required String emp,
  required String firstname,
  required String lastname,
  String? midname,
  String pefxTh = 'พญ.',
  String avatar = '',
}) => {
  'id': id,
  'emp': emp,
  'pefx': 'Dr.',
  'pefx_th': pefxTh,
  'firstname': firstname,
  'midname': midname,
  'lastname': lastname,
  'avatar_image_path': avatar,
};

Map<String, dynamic> schedule(Map<String, dynamic> employee) => {
  'id': 124,
  'emp': employee['emp'],
  'queue_room_id': 2,
  'day_of_week': 'Tuesday',
  'start_date': '2026-10-19T00:00:00Z',
  'end_date': '2026-11-08T00:00:00Z',
  'deleted_at': null,
  'employee': employee,
};

Map<String, dynamic> channel({
  required int id,
  required String roomTh,
  List<Map<String, dynamic>> schedules = const [],
}) => {
  'id': id,
  'queue_type': 'screening',
  'deleted_at': null,
  'start_date': null,
  'end_date': null,
  'channel_priority': 'PRIMARY',
  'queue_room': {'id': id, 'name_en': roomTh, 'name_th': roomTh},
  'queue_config_schedule': schedules,
};

final drThanawat = employee(
  id: 1,
  emp: 'EMP000001',
  firstname: 'ธนวัฒน์',
  midname: '',
  lastname: 'แก้วพรหม',
  avatar: '7e42bf64edd74d7ba3ae5e64f5964a41.jpg',
);

/// เหมือน response จริง: channel 1 กับ ห้อง 4 ไม่มีตาราง, หมอคนเดียวกันอยู่ 2 channel
Map<String, dynamic> screeningCallQueueResponse() => {
  'code': 200,
  'status': 'Success',
  'data': {
    'queue_type': 'screening',
    'prefix': '2SCR',
    'description': 'Screening 1',
    'sequent': null,
    'queue_config_type_id': 1,
    // หัวหน้าแผนก — ไม่ใช่แพทย์ในตาราง ต้องไม่ถูกนับ
    'employee': employee(
      id: 6,
      emp: 'EMP000006',
      firstname: 'ทรัพย์ธนิดา',
      lastname: 'อินทรประสาท',
    ),
    'queue_channel': [
      channel(id: 8, roomTh: 'ช่อง 1'),
      channel(id: 35, roomTh: 'ห้อง 4'),
      channel(id: 17, roomTh: 'ช่อง 2', schedules: [schedule(drThanawat)]),
      channel(id: 19, roomTh: 'ช่อง 2', schedules: [schedule(drThanawat)]),
    ],
  },
};

Map<String, dynamic> queueConfigTypesResponse() => {
  'code': 200,
  'data': [
    {'id': 1, 'name_th': 'แผนกตรวจตา', 'name_en': 'Eye', 'deleted_at': null},
    {'id': 2, 'name_th': 'แผนกเด็ก', 'name_en': 'Kids', 'deleted_at': null},
  ],
};

Map<String, dynamic> queueConfigsResponse(int typeId) => {
  'code': 200,
  'data': typeId == 1
      ? [
          {
            'queue_type': 'screening',
            'prefix': '2SCR',
            'description': 'Screening 1',
            'queue_config_type_id': 1,
          },
          {
            'queue_type': 'refraction',
            'prefix': '2REF',
            'description': 'Refraction',
            'queue_config_type_id': 1,
          },
        ]
      : [
          {
            'queue_type': 'kids',
            'prefix': '3KID',
            'description': 'Kids 1',
            'queue_config_type_id': 2,
          },
        ],
};
