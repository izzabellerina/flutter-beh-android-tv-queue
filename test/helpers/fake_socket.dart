// test/helpers/fake_socket.dart
//
// socket ปลอมแทน WebSocket จริง — test ส่ง message / ตัดการเชื่อมต่อเองได้

import 'dart:async';
import 'dart:convert';

import 'package:flutter_android_tv_queue/service/queue_socket_service.dart';

class FakeSocketConnection implements SocketConnection {
  final Uri uri;
  final _controller = StreamController<dynamic>();
  final _ready = Completer<void>();
  bool closed = false;

  FakeSocketConnection(this.uri);

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  void close() {
    closed = true;
    if (!_controller.isClosed) _controller.close();
  }

  /// ต่อสำเร็จ + server ส่ง "connected" แบบของจริง
  void open() {
    if (!_ready.isCompleted) _ready.complete();
    send({'message': 'Connected to updates', 'type': 'connected'});
  }

  void fail() {
    if (!_ready.isCompleted) _ready.completeError(Exception('refused'));
  }

  void send(Map<String, dynamic> message) =>
      _controller.add(jsonEncode(message));

  void callQueue({required String bookNo, required String queue}) => send({
    'type': 'appointment_call_queue',
    'data': {'bookno': bookNo, 'queue': queue},
  });

  /// server ตัดการเชื่อมต่อ
  void drop() => _controller.close();
}

class FakeSocketServer {
  final connections = <FakeSocketConnection>[];

  /// true = เปิดให้ทันทีที่ต่อ (สะดวกใน widget test)
  bool autoOpen;

  FakeSocketServer({this.autoOpen = true});

  FakeSocketConnection get last => connections.last;

  SocketConnection connect(Uri uri) {
    final connection = FakeSocketConnection(uri);
    connections.add(connection);
    if (autoOpen) scheduleMicrotask(connection.open);
    return connection;
  }
}
