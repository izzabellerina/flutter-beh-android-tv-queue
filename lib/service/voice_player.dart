import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// เล่นเสียงประกาศ 1 ไฟล์ — Future จบเมื่อเล่นจบ (ให้คิวเสียงเล่นทีละอัน)
/// แยกเป็น interface ให้ test ใส่ตัวปลอมได้
abstract class VoicePlayer {
  Future<void> play(Uint8List mp3);
  void dispose();
}

class AudioplayersVoicePlayer implements VoicePlayer {
  /// กันค้างถ้าไม่ได้รับ event เล่นจบ (ไฟล์เสีย/อุปกรณ์เสียงมีปัญหา)
  static const maxDuration = Duration(seconds: 30);

  final _player = AudioPlayer();

  @override
  Future<void> play(Uint8List mp3) async {
    // ใช้ Completer<void> เอง — `onPlayerComplete.first` ตอนรันจริงเป็น Future<AudioEvent>
    // ใส่ onTimeout ที่คืน Future<void> แล้ว throw ทันที (เจอบน TV emulator)
    final finished = Completer<void>();
    final subscription = _player.onPlayerComplete.listen((_) {
      if (!finished.isCompleted) finished.complete();
    });

    try {
      await _player.play(BytesSource(mp3, mimeType: 'audio/mpeg'));
      await finished.future.timeout(maxDuration);
    } on TimeoutException {
      await _player.stop();
    } finally {
      await subscription.cancel();
    }
  }

  @override
  void dispose() => _player.dispose();
}
