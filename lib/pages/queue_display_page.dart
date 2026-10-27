import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_android_tv_queue/controller/queue_board_controller.dart';
import 'package:flutter_android_tv_queue/controller/queue_voice_announcer.dart';
import 'package:flutter_android_tv_queue/enum/queue_mode.dart';
import 'package:flutter_android_tv_queue/helper/queue_date.dart';
import 'package:flutter_android_tv_queue/helper/screen_helper.dart';
import 'package:flutter_android_tv_queue/helper/queue_voice_helper.dart';
import 'package:flutter_android_tv_queue/helper/session_helper.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_android_tv_queue/models/response_model.dart';
import 'package:flutter_android_tv_queue/models/station_board_model.dart';
import 'package:flutter_android_tv_queue/provider/common_provider.dart';
import 'package:flutter_android_tv_queue/service/customer_service.dart';
import 'package:flutter_android_tv_queue/service/general_service.dart';
import 'package:flutter_android_tv_queue/service/queue_socket_service.dart';
import 'package:flutter_android_tv_queue/theme/app_theme.dart';
import 'package:flutter_android_tv_queue/widgets/queue_board/queue_board_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// หน้าจอคิว — คิวเดี่ยว (ทีวีแนวตั้ง หมุนภาพในแอป) / คิวคู่ (แนวนอน ซ้าย–ขวา)
/// Back บนรีโมท = กลับหน้าตั้งค่าคิว
class QueueDisplayPage extends ConsumerStatefulWidget {
  const QueueDisplayPage({super.key});

  @override
  ConsumerState<QueueDisplayPage> createState() => _QueueDisplayPageState();
}

class _QueueDisplayPageState extends ConsumerState<QueueDisplayPage>
    with QueueVoiceMixin {
  static const _reloginCooldown = Duration(minutes: 5);

  late final List<QueueSlotSelection> _slots;
  late final List<QueueBoardController> _controllers;
  late final QueueSocketService _socket;

  /// null = ปิดเสียงเรียกคิวในหน้าตั้งค่า
  QueueVoiceAnnouncer? _announcer;
  final _subscriptions = <StreamSubscription>[];
  DateTime? _lastRelogin;

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    ScreenHelper.setKeepScreenOn(true);

    _slots = ref.read(queueSlotsProvider);
    _socket = QueueSocketService(
      token: () => ref.read(loginProvider).token,
      connector: ref.read(socketConnectorProvider),
    );
    _controllers = [
      for (final slot in _slots)
        QueueBoardController(
          slot: slot,
          fetchStations: () => _fetchStations(slot),
          fetchBoard: _fetchBoard,
        ),
    ];

    _subscriptions
      ..add(
        _socket.callEvents.listen((event) {
          for (final controller in _controllers) {
            controller.onSocketEvent(event);
          }
          _announcer?.onSocketEvent(event);
        }),
      )
      ..add(
        _socket.reconnected.listen((_) {
          for (final controller in _controllers) {
            controller.refresh();
          }
        }),
      );

    if (ref.read(voiceEnabledProvider)) {
      _announcer = createVoiceAnnouncer(prefixes: _coveredPrefixes)..start();
    }

    _socket.start();
    for (final controller in _controllers) {
      controller.start();
    }
  }

  @override
  void dispose() {
    ScreenHelper.setKeepScreenOn(false);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _socket.dispose();
    _announcer?.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// ประกาศเฉพาะคิวที่จะขึ้น "กำลังตรวจ" บนจอนี้: station ที่แสดง
  /// (AUTO ROTATION = ทุก station ของ TYPE — จอจะตัดไปพร้อมเสียง; คิวคู่ = รวม 2 ชุด)
  Set<String> _coveredPrefixes() => {
    for (final controller in _controllers) ...[
      ...controller.stations.map((s) => s.prefix),
      ?controller.board?.queuePrefix,
    ],
  }..removeWhere((prefix) => prefix.isEmpty);

  // ══════════════════════════════════════════════════════════════════════════
  // DATA
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<QueueConfigModel>> _fetchStations(QueueSlotSelection slot) {
    return _withSession(() async {
      if (!mounted) throw StateError('QueueDisplayPage disposed');
      final response = await GeneralService.getAllQueueConfig(
        context,
        queueConfigTypeId: slot.type!.id,
        client: ref.read(httpClientProvider),
      );
      if (response.responseEnum != ResponseEnum.success) {
        throw Exception('getAllQueueConfig failed');
      }
      return response.data;
    });
  }

  /// get-one (ห้อง/กำลังตรวจ/prefix) → CALLING + DENIED ด้วย prefix จาก get-one
  Future<StationBoardModel> _fetchBoard(QueueConfigModel station) {
    return _withSession(() async {
      final client = ref.read(httpClientProvider);
      final date = QueueDate.today();

      if (!mounted) throw StateError('QueueDisplayPage disposed');
      final callQueue =
          await CustomerService.getOneQueueConfigCallQueueByQueueType(
            context,
            queueType: station.queueType,
            date: date,
            client: client,
          );
      if (callQueue.responseEnum != ResponseEnum.success) {
        throw Exception('getOneQueueConfigCallQueueByQueueType failed');
      }

      final prefix = callQueue.data.prefix.isNotEmpty
          ? callQueue.data.prefix
          : station.prefix;

      if (!mounted) throw StateError('QueueDisplayPage disposed');
      final lists = await Future.wait([
        for (final status in const ['CALLING', 'DENIED'])
          CustomerService.getAllAppointmentBookedDateByQueue(
            context,
            bookedDate: date,
            queuePrefix: prefix,
            callQueueStatus: status,
            client: client,
          ),
      ]);
      if (lists.any((r) => r.responseEnum != ResponseEnum.success)) {
        throw Exception('getAllAppointmentBookedDateByQueue failed');
      }

      return StationBoardModel(
        station: station,
        callQueue: callQueue.data,
        waiting: lists[0].data,
        counter: lists[1].data,
      );
    });
  }

  /// token ใกล้หมด → login ใหม่ก่อน; เรียกไม่สำเร็จ → login ใหม่แล้วลองอีกครั้ง
  /// (ไม่เกิน 1 ครั้งทุก 5 นาที — กันยิง login รัว ๆ ตอนเน็ตล่ม)
  Future<T> _withSession<T>(Future<T> Function() request) async {
    if (SessionHelper.tokenExpiringSoon(ref.read(loginProvider))) {
      await _relogin();
    }
    try {
      return await request();
    } catch (_) {
      if (await _relogin()) return request();
      rethrow;
    }
  }

  Future<bool> _relogin() async {
    final now = DateTime.now();
    final last = _lastRelogin;
    if (last != null && now.difference(last) < _reloginCooldown) return false;
    _lastRelogin = now;

    final ok = await SessionHelper.relogin(ref);
    if (ok && mounted) _socket.reconnectNow();
    return ok;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(queueModeProvider);
    final rotation = ref.watch(displayRotationProvider);

    final Widget content;
    if (mode == QueueMode.dual) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _controllers.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(
              child: QueueBoardView(
                controller: _controllers[i],
                doctor: _slots[i].doctor,
                announcing: _announcer?.announcing,
              ),
            ),
          ],
        ],
      );
    } else {
      final board = QueueBoardView(
        controller: _controllers.first,
        doctor: _slots.first.doctor,
        announcing: _announcer?.announcing,
        waitingRows: 3,
      );
      content = rotation.isPortrait
          ? RotatedBox(quarterTurns: rotation.quarterTurns, child: board)
          // คิวเดี่ยวบนทีวีแนวนอน: บอร์ดสัดส่วนแนวตั้งกลางจอ
          : Center(child: AspectRatio(aspectRatio: 0.62, child: board));
    }

    return Scaffold(
      body: Padding(
        padding: AppTheme.overscanPadding,
        child: Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              top: 6,
              right: 6,
              child: _ConnectionDot(status: _socket.status),
            ),
          ],
        ),
      ),
    );
  }
}

/// จุดเล็กมุมจอบอกสถานะ socket — เขียว = realtime, เหลือง = กำลังต่อ, แดง = หลุด (ยัง refresh ทุก 60 วิ)
class _ConnectionDot extends StatelessWidget {
  final ValueNotifier<SocketStatus> status;

  const _ConnectionDot({required this.status});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: status,
      builder: (context, value, _) => Container(
        key: ValueKey('socket-${value.name}'),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: switch (value) {
            SocketStatus.connected => const Color(0xff2ecc71),
            SocketStatus.connecting => const Color(0xfff5b041),
            SocketStatus.disconnected => const Color(0xffe74c3c),
          },
        ),
      ),
    );
  }
}
