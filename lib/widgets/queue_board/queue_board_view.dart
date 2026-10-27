import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/controller/queue_board_controller.dart';
import 'package:flutter_android_tv_queue/models/appointment_queue_model.dart';
import 'package:flutter_android_tv_queue/models/employee_info_model.dart';
import 'package:flutter_android_tv_queue/widgets/queue_slot_form.dart';

/// สีจอคิว — สว่าง = แบบจอจริงของ รพ. (teal/ขาว), มืด = teal บนพื้นกรมท่า
class QueueBoardColors {
  final Color header;
  final Color onHeader;
  final Color doctorBand;
  final Color onDoctorBand;
  final Color body;
  final Color label;
  final Color number;
  final Color box;
  final Color boxTitle;
  final Color boxItem;

  const QueueBoardColors({
    required this.header,
    required this.onHeader,
    required this.doctorBand,
    required this.onDoctorBand,
    required this.body,
    required this.label,
    required this.number,
    required this.box,
    required this.boxTitle,
    required this.boxItem,
  });

  static const light = QueueBoardColors(
    header: Color(0xff2ba8b5),
    onHeader: Colors.white,
    doctorBand: Color(0xff1e6f7f),
    onDoctorBand: Colors.white,
    body: Colors.white,
    label: Color(0xff1e2a3a),
    number: Color(0xff1a9ba8),
    box: Color(0xffddf1f3),
    boxTitle: Color(0xff1e6f7f),
    boxItem: Color(0xff137c88),
  );

  static const dark = QueueBoardColors(
    header: Color(0xff127c88),
    onHeader: Colors.white,
    doctorBand: Color(0xff0e4e5a),
    onDoctorBand: Color(0xffe8eef5),
    body: Color(0xff0f1b2b),
    label: Color(0xffe8eef5),
    number: Color(0xff5fd3dd),
    box: Color(0xff15303c),
    boxTitle: Color(0xff8fd9e0),
    boxItem: Color(0xffbdeff3),
  );

  static QueueBoardColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// จอคิว 1 ชุด เรียงบนลงล่าง: ห้อง → แพทย์ → กำลังตรวจ → คิวรอ → ติดต่อเคาน์เตอร์
/// ใช้กับคิวคู่ (คอลัมน์ละชุด) และคิวเดี่ยวแนวตั้ง — ขนาดทุกอย่างคิดจากความกว้างที่ได้
class QueueBoardView extends StatelessWidget {
  final QueueBoardController controller;

  /// แพทย์ที่เลือกในหน้าตั้งค่า — null = ไม่แสดงการ์ดแพทย์
  final EmployeeInfoModel? doctor;

  /// แถวของคิวรอ (คอลัมน์ละ 3)
  final int waitingRows;
  final int counterRows;

  /// เลขที่กำลังประกาศเสียง (null = ปิดเสียง) — ตรงกับกำลังตรวจ → ไฮไลต์
  final ValueListenable<String?>? announcing;

  const QueueBoardView({
    super.key,
    required this.controller,
    required this.doctor,
    this.waitingRows = 2,
    this.counterRows = 2,
    this.announcing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = QueueBoardColors.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final unit = (constraints.maxWidth / 28).clamp(10.0, 26.0);
          final board = controller.board;

          return ClipRRect(
            borderRadius: BorderRadius.circular(unit),
            child: ColoredBox(
              color: colors.body,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(controller: controller, colors: colors, unit: unit),
                  if (doctor != null)
                    _DoctorBand(doctor: doctor!, colors: colors, unit: unit),
                  Expanded(
                    child: board == null
                        ? _Loading(
                            controller: controller,
                            colors: colors,
                            unit: unit,
                          )
                        : _CurrentQueue(
                            queue: board.current,
                            announcing: announcing,
                            colors: colors,
                            unit: unit,
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(unit, 0, unit, unit * 0.6),
                    child: Column(
                      children: [
                        _QueueBox(
                          title: 'คิวที่รอ (Waiting)',
                          items: board?.waiting ?? const [],
                          rows: waitingRows,
                          colors: colors,
                          unit: unit,
                        ),
                        SizedBox(height: unit * 0.6),
                        _QueueBox(
                          title: 'ติดต่อเคาน์เตอร์ (Contact Counter)',
                          items: board?.counter ?? const [],
                          rows: counterRows,
                          colors: colors,
                          unit: unit,
                        ),
                      ],
                    ),
                  ),
                  if (controller.error != null && board != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: unit * 0.4),
                      child: Text(
                        controller.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: unit * 0.8,
                          color: colors.label.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final QueueBoardController controller;
  final QueueBoardColors colors;
  final double unit;

  const _Header({
    required this.controller,
    required this.colors,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final board = controller.board;
    final stations = controller.stations;

    return Container(
      color: colors.header,
      padding: EdgeInsets.symmetric(horizontal: unit, vertical: unit * 0.5),
      child: Column(
        children: [
          Text(
            board?.roomNameTh ?? ' ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: unit * 2.1,
              fontWeight: FontWeight.w700,
              color: colors.onHeader,
              height: 1.15,
            ),
          ),
          if ((board?.roomNameEn ?? '').isNotEmpty)
            Text(
              board!.roomNameEn.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: unit * 1.0,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: colors.onHeader.withValues(alpha: 0.9),
              ),
            ),
          // AUTO ROTATION: จุดบอกว่ากำลังวนอยู่ที่ station ไหน
          if (controller.rotating)
            Padding(
              padding: EdgeInsets.only(top: unit * 0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < stations.length; i++)
                    Container(
                      width: unit * (i == controller.index ? 1.4 : 0.5),
                      height: unit * 0.5,
                      margin: EdgeInsets.symmetric(horizontal: unit * 0.15),
                      decoration: BoxDecoration(
                        color: colors.onHeader.withValues(
                          alpha: i == controller.index ? 1 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(unit),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DoctorBand extends StatelessWidget {
  final EmployeeInfoModel doctor;
  final QueueBoardColors colors;
  final double unit;

  const _DoctorBand({
    required this.doctor,
    required this.colors,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final license = doctor.licenseNumber.trim();
    final showLicense = license.isNotEmpty && license.toLowerCase() != 'none';

    TextStyle style(double size, {FontWeight weight = FontWeight.w400}) =>
        TextStyle(
          fontSize: unit * size,
          fontWeight: weight,
          color: colors.onDoctorBand,
          height: 1.2,
        );

    return Container(
      color: colors.doctorBand,
      padding: EdgeInsets.symmetric(horizontal: unit, vertical: unit * 0.5),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(unit * 0.15),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: DoctorAvatar(path: doctor.avatarImagePath, size: unit * 3.6),
          ),
          SizedBox(width: unit * 0.8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.fullnameWithMid,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style(1.45, weight: FontWeight.w700),
                ),
                if (doctor.fullnameEnWithMid.isNotEmpty)
                  Text(
                    doctor.fullnameEnWithMid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style(1.0),
                  ),
                if (showLicense)
                  Text('License Number : $license', style: style(0.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentQueue extends StatelessWidget {
  final AppointmentQueueModel? queue;
  final ValueListenable<String?>? announcing;
  final QueueBoardColors colors;
  final double unit;

  const _CurrentQueue({
    required this.queue,
    required this.announcing,
    required this.colors,
    required this.unit,
  });

  /// กำลังประกาศเลขนี้ → กรอบ + พื้นเน้น (ช่วยคนที่ไม่ได้ยินเสียง)
  Widget _highlight(String number, Widget child) {
    final listenable = announcing;
    if (listenable == null || number.isEmpty) return child;

    return ValueListenableBuilder<String?>(
      valueListenable: listenable,
      builder: (context, value, _) {
        final on = value == number;
        return AnimatedContainer(
          key: on ? const ValueKey('announcing-highlight') : null,
          duration: const Duration(milliseconds: 300),
          margin: EdgeInsets.only(top: unit * 0.3),
          decoration: BoxDecoration(
            color: on ? colors.box : Colors.transparent,
            borderRadius: BorderRadius.circular(unit),
            border: Border.all(
              width: unit * 0.25,
              color: on ? colors.number : Colors.transparent,
            ),
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final number = queue?.publicQueue ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: unit, vertical: unit * 0.4),
      child: Column(
        children: [
          Text(
            'กำลังตรวจ',
            style: TextStyle(
              fontSize: unit * 1.6,
              fontWeight: FontWeight.w700,
              color: colors.label,
              height: 1.1,
            ),
          ),
          Text(
            '(Providing Care)',
            style: TextStyle(fontSize: unit * 0.95, color: colors.label),
          ),
          Expanded(
            // เลขใหม่ → ขยาย + จางเข้า ให้คนในห้องรอสังเกตเห็น
            child: _highlight(
              number,
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween(begin: 1.35, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: FittedBox(
                  key: ValueKey(number),
                  fit: BoxFit.scaleDown,
                  child: Text(
                    number.isEmpty ? '—' : number,
                    style: TextStyle(
                      // ไม่มีคิว: ขีดเล็ก ไม่ให้ดูเหมือนแท่งสี่เหลี่ยม
                      fontSize: unit * (number.isEmpty ? 3 : 7),
                      fontWeight: FontWeight.w700,
                      color: colors.number,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueBox extends StatelessWidget {
  static const columns = 3;

  final String title;
  final List<AppointmentQueueModel> items;
  final int rows;
  final QueueBoardColors colors;
  final double unit;

  const _QueueBox({
    required this.title,
    required this.items,
    required this.rows,
    required this.colors,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final capacity = rows * columns;
    final overflow = items.length > capacity;
    final shown = overflow ? items.take(capacity - 1).toList() : items;
    final labels = [
      ...shown.map((e) => e.publicQueue.isNotEmpty ? e.publicQueue : e.queue),
      if (overflow) '+${items.length - shown.length}',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: unit * 0.8,
        vertical: unit * 0.4,
      ),
      decoration: BoxDecoration(
        color: colors.box,
        borderRadius: BorderRadius.circular(unit * 0.7),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: unit * 1.05,
              fontWeight: FontWeight.w600,
              color: colors.boxTitle,
            ),
          ),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < columns; c++)
                  Expanded(
                    child: Text(
                      _labelAt(labels, r * columns + c, isFirstRow: r == 0),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: unit * 1.55,
                        fontWeight: FontWeight.w700,
                        color: colors.boxItem,
                        height: 1.25,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// ช่องว่างเว้นไว้ให้กล่องสูงคงที่ — ไม่มีคิวเลยแสดง "—" ช่องกลางแถวแรก
  String _labelAt(List<String> labels, int i, {required bool isFirstRow}) {
    if (i < labels.length) return labels[i];
    if (labels.isEmpty && isFirstRow && i == 1) return '—';
    return '';
  }
}

class _Loading extends StatelessWidget {
  final QueueBoardController controller;
  final QueueBoardColors colors;
  final double unit;

  const _Loading({
    required this.controller,
    required this.colors,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final error = controller.error;
    return Center(
      child: error == null
          ? CircularProgressIndicator(color: colors.number)
          : Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: unit * 1.1, color: colors.label),
            ),
    );
  }
}
