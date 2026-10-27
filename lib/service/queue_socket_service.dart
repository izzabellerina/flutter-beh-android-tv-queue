import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_android_tv_queue/models/queue_socket_event_model.dart';
import 'package:flutter_android_tv_queue/service/configuration.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// การเชื่อมต่อ 1 ครั้ง — แยกออกมาให้ test ใส่ตัวปลอมแทน WebSocket จริงได้
abstract class SocketConnection {
  Future<void> get ready;
  Stream<dynamic> get stream;
  void close();
}

typedef SocketConnector = SocketConnection Function(Uri uri);

class WebSocketConnection implements SocketConnection {
  final WebSocketChannel _channel;

  WebSocketConnection(Uri uri) : _channel = WebSocketChannel.connect(uri);

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void close() => _channel.sink.close();
}

enum SocketStatus { connecting, connected, disconnected }

/// socket เดียวของแอป — ต่อใหม่เองเมื่อหลุด (หน่วง 2, 4, 8 … สูงสุด 30 วิ)
///
/// ทีวีเปิดทั้งวัน เน็ตหลุด/server restart ได้ → ทุกครั้งที่ต่อกลับมาได้จะยิง [reconnected]
/// ให้จอ refresh เพราะ event ระหว่างที่หลุดหายไปแล้ว
class QueueSocketService {
  final SocketConnector connector;
  final String Function() token;

  final _events = StreamController<QueueSocketEventModel>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final status = ValueNotifier(SocketStatus.connecting);

  SocketConnection? _connection;
  StreamSubscription? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _everConnected = false;
  bool _disposed = false;

  QueueSocketService({required this.token, SocketConnector? connector})
    : connector = connector ?? WebSocketConnection.new;

  /// event เรียกคิว (type == appointment_call_queue) เท่านั้น
  Stream<QueueSocketEventModel> get callEvents => _events.stream;

  Stream<void> get reconnected => _reconnected.stream;

  static Uri uriFor(String token) =>
      Uri.parse(BehConfig.webSocket(path: 'v3/websocket/$token'));

  void start() => _connect();

  /// ต่อใหม่ทันที เช่น หลัง login ใหม่ได้ token ใหม่
  void reconnectNow() {
    _closeCurrent();
    _retryTimer?.cancel();
    _attempt = 0;
    _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    status.value = SocketStatus.connecting;

    final connection = connector(uriFor(token()));
    _connection = connection;

    try {
      await connection.ready;
    } catch (e) {
      log('socket connect failed: $e');
      if (identical(connection, _connection)) _scheduleRetry();
      return;
    }
    if (_disposed || !identical(connection, _connection)) {
      connection.close();
      return;
    }

    _subscription = connection.stream.listen(
      _onMessage,
      onError: (Object e) {
        log('socket error: $e');
        if (identical(connection, _connection)) _scheduleRetry();
      },
      onDone: () {
        if (identical(connection, _connection)) _scheduleRetry();
      },
    );
  }

  void _onMessage(dynamic message) {
    final event = QueueSocketEventModel.tryParse(message);
    if (event == null) return;

    if (event.isConnected) {
      status.value = SocketStatus.connected;
      _attempt = 0;
      if (_everConnected) _reconnected.add(null);
      _everConnected = true;
      return;
    }

    if (event.isCallQueue) {
      log('socket call queue: bookno=${event.bookNo} queue=${event.queue}');
      _events.add(event);
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _closeCurrent();
    status.value = SocketStatus.disconnected;

    final seconds = (2 << _attempt).clamp(2, 30);
    _attempt = (_attempt + 1).clamp(0, 10);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), _connect);
  }

  void _closeCurrent() {
    _subscription?.cancel();
    _subscription = null;
    _connection?.close();
    _connection = null;
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _closeCurrent();
    _events.close();
    _reconnected.close();
    status.dispose();
  }
}
