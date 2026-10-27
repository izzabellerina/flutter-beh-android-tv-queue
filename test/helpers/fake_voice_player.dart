// test/helpers/fake_voice_player.dart
//
// ตัวเล่นเสียงปลอม — เก็บสิ่งที่เล่น (decode เป็นข้อความ) และเล่นจบเมื่อ test สั่ง

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_android_tv_queue/service/voice_player.dart';

class FakePlayer implements VoicePlayer {
  final played = <String>[];
  Completer<void>? _current;
  bool disposed = false;

  bool get isPlaying => _current != null && !_current!.isCompleted;

  @override
  Future<void> play(Uint8List mp3) {
    played.add(utf8.decode(mp3, allowMalformed: true));
    _current = Completer();
    return _current!.future;
  }

  void finish() {
    if (isPlaying) _current!.complete();
  }

  @override
  void dispose() => disposed = true;
}
