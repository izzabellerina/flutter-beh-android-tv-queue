import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_android_tv_queue/models/queue_calling_voice_text_model.dart';
import 'package:flutter_android_tv_queue/models/queue_socket_event_model.dart';
import 'package:flutter_android_tv_queue/models/voice_model.dart';
import 'package:flutter_android_tv_queue/service/voice_player.dart';

typedef VoiceTemplateFetcher = Future<QueueCallingVoiceTextModel> Function();
typedef VoiceFetcher = Future<VoiceModel> Function({
  required String textTh,
  required String textEn,
});

/// คำที่ประกาศ 1 ครั้ง
class VoiceAnnouncement {
  final String bookNo;
  final String publicQueue;
  final String nameTh;
  final String nameEn;

  const VoiceAnnouncement({
    this.bookNo = '',
    required this.publicQueue,
    required this.nameTh,
    required this.nameEn,
  });

  factory VoiceAnnouncement.fromEvent(QueueSocketEventModel event) =>
      VoiceAnnouncement(
        bookNo: event.bookNo,
        publicQueue: event.publicQueue,
        nameTh: event.nameTh,
        nameEn: event.nameEn,
      );

  String get dedupeKey => '$bookNo|$publicQueue|$nameTh';
}

/// เสียงเรียกคิว (ตามที่ dev กำหนด)
///
/// socket `appointment_call_queue` + queue ขึ้นต้นด้วย prefix ของจอนี้ + `SERVING`
/// → ประกอบข้อความจาก template → get-voice (speaking_rate 0.7) → เล่น MP3
///
/// - คิวเสียงเล่นทีละอันตามลำดับ (เรียกติดกันไม่ทับกัน) ค้างเกิน [maxPending] ทิ้งอันเก่าสุด
/// - event เดียวกันซ้ำภายใน [duplicateWindow] เล่นครั้งเดียว (พยาบาลกดเรียกซ้ำทีหลัง = ประกาศใหม่)
/// - get-voice พลาด → ข้ามอันนั้น ไม่ค้างทั้งคิว
class QueueVoiceAnnouncer {
  static const speakingRate = 0.7;
  static const duplicateWindow = Duration(seconds: 5);
  static const maxPending = 5;
  static const templateRefresh = Duration(hours: 1);

  final VoiceTemplateFetcher fetchTemplate;
  final VoiceFetcher fetchVoice;
  final VoicePlayer player;

  /// prefix ของ station ที่จอนี้แสดง (คิวคู่ = รวม 2 ชุด, AUTO ROTATION = ทุก station)
  final Set<String> Function() prefixes;
  final DateTime Function() now;

  /// แจ้งเมื่อประกาศไม่สำเร็จ (เช่น ปุ่มทดสอบเสียงบอกผล)
  void Function(Object error)? onError;

  QueueVoiceAnnouncer({
    required this.fetchTemplate,
    required this.fetchVoice,
    required this.player,
    required this.prefixes,
    this.now = DateTime.now,
    this.onError,
  });

  /// เลขคิวที่กำลังประกาศอยู่ (null = เงียบ) — จอใช้ไฮไลต์เลข
  final announcing = ValueNotifier<String?>(null);

  QueueCallingVoiceTextModel? _template;
  final _pending = Queue<VoiceAnnouncement>();
  final _recent = <String, DateTime>{};
  Timer? _templateTimer;
  bool _playing = false;
  bool _disposed = false;

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  /// โหลด template + โหลดใหม่ทุกชั่วโมง (dev แก้ถ้อยคำได้โดยไม่ต้องเปิดแอปใหม่)
  Future<void> start() async {
    _templateTimer = Timer.periodic(templateRefresh, (_) => _loadTemplate());
    await _loadTemplate();
  }

  void dispose() {
    _disposed = true;
    _templateTimer?.cancel();
    _pending.clear();
    player.dispose();
    announcing.dispose();
  }

  Future<void> _loadTemplate() async {
    try {
      final template = await fetchTemplate();
      if (template.data.isNotEmpty) _template = template;
    } catch (e) {
      log('voice template failed: $e'); // ใช้ตัวล่าสุดที่มีต่อไป
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EVENTS
  // ══════════════════════════════════════════════════════════════════════════

  bool shouldAnnounce(QueueSocketEventModel event) =>
      event.isCallQueue &&
      event.isServing &&
      event.publicQueue.isNotEmpty &&
      prefixes().any(event.matchesPrefix);

  void onSocketEvent(QueueSocketEventModel event) {
    if (shouldAnnounce(event)) announce(VoiceAnnouncement.fromEvent(event));
  }

  /// ใส่คิวเสียง (ใช้ตรง ๆ กับปุ่ม "ทดสอบเสียง" ด้วย)
  void announce(VoiceAnnouncement item) {
    if (_disposed) return;

    final time = now();
    _recent.removeWhere((_, at) => time.difference(at) > duplicateWindow);
    if (_recent.containsKey(item.dedupeKey)) return;
    _recent[item.dedupeKey] = time;

    _pending.add(item);
    while (_pending.length > maxPending) {
      _pending.removeFirst();
    }
    _drain();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PLAY
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _drain() async {
    if (_playing) return;
    _playing = true;

    while (_pending.isNotEmpty && !_disposed) {
      final item = _pending.removeFirst();
      try {
        if (_template == null) await _loadTemplate();
        final text = buildText(_template, item);
        final voice = await fetchVoice(textTh: text.th, textEn: text.en);
        final bytes = base64Decode(voice.audioContent);
        if (_disposed) continue;
        if (bytes.isEmpty) throw const FormatException('empty audio_content');

        announcing.value = item.publicQueue;
        await player.play(bytes);
      } catch (e) {
        log('voice announce failed (${item.publicQueue}): $e');
        onError?.call(e);
      } finally {
        if (!_disposed) announcing.value = null;
      }
    }

    _playing = false;
  }

  /// TH = prefix_name_th + public_queue + middle_th + name_th + suffix_name_th
  /// EN = prefix_name_en + public_queue + middle_en + name_en + suffix_name_en
  /// เช่น "ขอเชิญหมายเลข LS0001 ที่ ช่อง 2 ค่ะ" — ข้ามส่วนที่ว่าง/null
  static ({String th, String en}) buildText(
    QueueCallingVoiceTextModel? template,
    VoiceAnnouncement item,
  ) {
    String join(List<String> parts) =>
        parts.map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');

    return (
      th: join([
        template?.prefixNameTh ?? '',
        item.publicQueue,
        template?.middleTh ?? '',
        item.nameTh,
        template?.suffixNameTh ?? '',
      ]),
      en: join([
        template?.prefixNameEn ?? '',
        item.publicQueue,
        template?.middleEn ?? '',
        item.nameEn,
        template?.suffixNameEn ?? '',
      ]),
    );
  }
}
