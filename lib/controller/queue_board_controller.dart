import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_android_tv_queue/helper/queue_date.dart';
import 'package:flutter_android_tv_queue/models/queue_config_model.dart';
import 'package:flutter_android_tv_queue/models/queue_slot_selection.dart';
import 'package:flutter_android_tv_queue/models/queue_socket_event_model.dart';
import 'package:flutter_android_tv_queue/models/station_board_model.dart';

typedef StationsFetcher = Future<List<QueueConfigModel>> Function();
typedef BoardFetcher = Future<StationBoardModel> Function(
  QueueConfigModel station,
);

/// สมองของจอคิว 1 ชุด (คิวคู่มี 2 ตัว)
///
/// - ปิด AUTO ROTATION: แสดง STATION ที่เลือก, refresh เมื่อมี event + ทุก 60 วิ กัน socket เงียบหาย
/// - เปิด AUTO ROTATION: วนทุก STATION ของ TYPE
///   - เปลี่ยน station → fetch ทุกครั้ง
///   - ไม่มีคิวเลย → ค้าง 10 วิ แล้วไปต่อ
///   - มีคิว → ค้าง 30 วิ → fetch ใหม่ → เปลี่ยน = ค้างต่ออีก 30 วิ, เหมือนเดิม = ไปต่อ
///   - socket เรียกคิวของ station อื่น → ตัดไป station นั้น
/// - เที่ยงคืนเวลาไทย → โหลดใหม่ (วันที่ใน API เปลี่ยน)
class QueueBoardController extends ChangeNotifier {
  static const emptyDwell = Duration(seconds: 10);
  static const busyDwell = Duration(seconds: 30);
  static const fixedRefresh = Duration(seconds: 60);
  static const debounce = Duration(milliseconds: 500);

  final QueueSlotSelection slot;
  final StationsFetcher fetchStations;
  final BoardFetcher fetchBoard;
  final DateTime Function() now;

  QueueBoardController({
    required this.slot,
    required this.fetchStations,
    required this.fetchBoard,
    this.now = DateTime.now,
  });

  List<QueueConfigModel> stations = [];

  /// station ที่กำลังแสดง — เปลี่ยนพร้อม [board] หลังโหลดเสร็จ (ไม่โชว์ข้อมูลผิด station ระหว่างโหลด)
  int index = 0;
  StationBoardModel? board;

  /// โหลดล่าสุดไม่สำเร็จ — ยังแสดงข้อมูลเดิมไว้ ไม่ทำให้จอว่าง
  String? error;

  Timer? _dwellTimer;
  Timer? _debounceTimer;
  Timer? _midnightTimer;
  int? _pendingIndex;

  /// เพิ่มทุกครั้งที่เริ่มโหลดใหม่ — ผลของการโหลดเก่าที่มาถึงทีหลังจะถูกทิ้ง
  int _generation = 0;
  bool _disposed = false;

  bool get rotating => slot.autoRotation && stations.length > 1;

  // ══════════════════════════════════════════════════════════════════════════
  // START / STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> start() async {
    _scheduleMidnight();
    await _loadStations();
    if (_disposed) return;

    if (stations.isEmpty) {
      error ??= 'ไม่มี STATION ให้แสดง';
      _notify();
      _dwellTimer = Timer(emptyDwell, start);
      return;
    }

    final selected = slot.station?.queueType;
    final i = stations.indexWhere((s) => s.queueType == selected);
    await _show(i < 0 ? 0 : i);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _dwellTimer?.cancel();
    _debounceTimer?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EVENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// เงื่อนไข (ตกลงกับผู้ใช้): เกี่ยวกับ station ที่แสดงอยู่ถ้า bookno อยู่ในข้อมูล
  /// (คิวออก/เปลี่ยนสถานะ) **หรือ** queue ขึ้นต้นด้วย prefix (คิวเข้า)
  void onSocketEvent(QueueSocketEventModel event) {
    if (!event.isCallQueue || stations.isEmpty || _disposed) return;

    final current = board;
    final concernsCurrent =
        (current != null &&
            (current.containsBookNo(event.bookNo) ||
                event.matchesPrefix(current.queuePrefix))) ||
        event.matchesPrefix(stations[index].prefix);
    if (concernsCurrent) {
      _queueShow(index);
      return;
    }

    if (!rotating) return;
    final target = stations.indexWhere((s) => event.matchesPrefix(s.prefix));
    if (target >= 0) _queueShow(target);
  }

  /// โหลด station ที่แสดงอยู่ใหม่ (เช่น socket ต่อกลับมาได้ — event ระหว่างหลุดหายไปแล้ว)
  void refresh() {
    if (stations.isNotEmpty) _queueShow(index);
  }

  /// รวมหลาย event ที่มาติด ๆ กันเป็นการโหลดครั้งเดียว
  void _queueShow(int i) {
    _pendingIndex = i;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      final target = _pendingIndex;
      _pendingIndex = null;
      if (target != null) _show(target);
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOAD / ROTATE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadStations() async {
    final selected = slot.station;
    if (!slot.autoRotation) {
      stations = selected == null ? [] : [selected];
      return;
    }

    try {
      final list = await fetchStations();
      if (list.isNotEmpty) stations = list;
    } catch (_) {
      error = 'โหลดรายการ STATION ไม่สำเร็จ';
    }
    if (stations.isEmpty && selected != null) stations = [selected];
  }

  Future<void> _show(int i) async {
    if (_disposed || stations.isEmpty) return;
    final generation = ++_generation;
    _dwellTimer?.cancel();
    final target = i.clamp(0, stations.length - 1);

    final StationBoardModel fresh;
    try {
      fresh = await fetchBoard(stations[target]);
    } catch (_) {
      if (generation != _generation || _disposed) return;
      error = 'อัปเดตข้อมูลไม่สำเร็จ กำลังลองใหม่';
      _notify();
      _dwellTimer = Timer(
        emptyDwell,
        () => _show(rotating ? _next(target) : target),
      );
      return;
    }
    if (generation != _generation || _disposed) return;

    index = target;
    board = fresh;
    error = null;
    _notify();
    _scheduleDwell();
  }

  void _scheduleDwell() {
    _dwellTimer?.cancel();
    if (!rotating) {
      _dwellTimer = Timer(fixedRefresh, () => _show(index));
      return;
    }
    _dwellTimer = Timer(board!.isEmpty ? emptyDwell : busyDwell, _onDwellEnd);
  }

  Future<void> _onDwellEnd() async {
    final shown = board!;
    if (shown.isEmpty) return _show(_next(index));

    // มีคิวค้าง: fetch ซ้ำก่อนตัดสินใจ
    final generation = ++_generation;
    final StationBoardModel fresh;
    try {
      fresh = await fetchBoard(stations[index]);
    } catch (_) {
      if (generation != _generation || _disposed) return;
      return _show(_next(index));
    }
    if (generation != _generation || _disposed) return;

    board = fresh;
    error = null;
    _notify();

    final changed = fresh.signature != shown.signature;
    if (changed && !fresh.isEmpty) {
      _scheduleDwell();
    } else {
      await _show(_next(index));
    }
  }

  int _next(int i) => (i + 1) % stations.length;

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    _midnightTimer = Timer(QueueDate.untilNextDay(now: now()), () async {
      final shownType = board?.station.queueType;
      await _loadStations();
      if (_disposed || stations.isEmpty) return;
      final i = stations.indexWhere((s) => s.queueType == shownType);
      await _show(max(i, 0));
      _scheduleMidnight();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
