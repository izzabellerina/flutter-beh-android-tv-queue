import 'package:flutter_android_tv_queue/helper/utf8_try_decode.dart';

class AppointmentQueueModel {
  final Map data;

  AppointmentQueueModel({required this.data});

  int get id => data['id'] ?? 0;

  String get bookNo => data['bookno'] ?? '';

  String get vn => data['vn'] ?? '';

  String get bookedDate => data['bookeddate'] ?? '';

  String get beginTime => data['begintime'] ?? '';

  String get docS => data['doc_s'] ?? '';

  String get preHn => data['pre_hn'] ?? '';

  String get hn => data['hn'] ?? '';

  String get hosp => data['hosp'] ?? '';

  String get dep => data['dep'] ?? '';

  String get pur => data['pur'] ?? '';

  String get appointmentStatus => Utf8TryDecode.decode(data['asta'] ?? '');

  String get bookedBy => data['bookedby'] ?? '';

  String get timeArrive => data['timearrive'] ?? '';

  String get ccLog => data['cclog'] ?? '';

  String get emp => data['emp'] ?? '';

  bool get follow => data['follow'] ?? false;

  bool get cc => data['cc'] ?? false;

  String get remark => data['remark'] ?? '';

  String get prevBookNo => data['prevbookno'] ?? '';

  DateTime? get createdAt => DateTime.tryParse(data['created_at'] ?? '');

  DateTime? get updatedAt => DateTime.tryParse(data['updated_at'] ?? '');

  DateTime? get deletedAt => DateTime.tryParse(data['deleted_at'] ?? '');

  List<String> get forStatus => List<String>.from(data['forstatus'] ?? []);

  bool get externalBooking => data['external_booking'] ?? false;

  bool get hasConfirm => data['has_confirm'] ?? false;

  String get confirmBy => data['confirm_by'] ?? '';

  List<String> get externalForStatus =>
      List<String>.from(data['external_forstatus'] ?? []);

  String get color => data['color'] ?? '';

  List<String> get reqDoc => List<String>.from(data['req_doc'] ?? []);

  List<String> get reqFinance => List<String>.from(data['req_finance'] ?? []);

  String get timeLeft => data['timeleft'] ?? '';

  DateTime? get canceledAt => DateTime.tryParse(data['canceled_at'] ?? '');

  List<String> get status => List<String>.from(data['status'] ?? []);

  DateTime? get admitAt => DateTime.tryParse(data['admit_at'] ?? '');

  String get admitBy => data['admit_by'] ?? '';

  String get an => data['an'] ?? '';

  DateTime? get preAdmitAt => DateTime.tryParse(data['pre_admit_at'] ?? '');

  String get queue => data['queue'] ?? '';

  String get tokenTelemed => data['token_telemed'] ?? '';

  String get publicQueue => data['public_queue'] ?? '';

  bool get showDoctorMemo => data['show_doctor_memo'] ?? false;

  List<int> get callQueueRoleIds =>
      List<int>.from(data['call_queue_role_ids'] ?? []);

  String get callQueueStatus => data['call_queue_status'] ?? '';

  String get waitingStatus => data['waiting_status'] ?? '';
}
