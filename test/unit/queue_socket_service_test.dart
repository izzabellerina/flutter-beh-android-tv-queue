// test/unit/queue_socket_service_test.dart

import 'package:fake_async/fake_async.dart';
import 'package:flutter_android_tv_queue/models/queue_socket_event_model.dart';
import 'package:flutter_android_tv_queue/service/queue_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_socket.dart';

void main() {
  late FakeSocketServer server;
  late QueueSocketService socket;
  late String token;

  setUp(() {
    server = FakeSocketServer(autoOpen: false);
    token = 'token-1';
  });

  QueueSocketService create() =>
      QueueSocketService(token: () => token, connector: server.connect);

  test('URL = wss://…/general-api/api/v3/websocket/<token>', () {
    expect(
      QueueSocketService.uriFor('abc').toString(),
      'wss://beh.devforu.link/general-api/api/v3/websocket/abc',
    );
  });

  test('connected → สถานะ connected; ส่งต่อเฉพาะ event เรียกคิว', () {
    fakeAsync((async) {
      socket = create()..start();
      final events = <QueueSocketEventModel>[];
      socket.callEvents.listen(events.add);

      server.last.open();
      async.flushMicrotasks();
      expect(socket.status.value, SocketStatus.connected);

      server.last.send({'type': 'something_else', 'data': {}});
      server.last.callQueue(bookNo: 'BKN1', queue: '2SCR0001');
      server.last.send({
        'type': 'appointment_call_queue',
      }); // ไม่มี data ก็ไม่พัง
      async.flushMicrotasks();

      expect(events.map((e) => e.bookNo), ['BKN1', '']);
      expect(events.first.queue, '2SCR0001');
      socket.dispose();
    });
  });

  test('message ที่ไม่ใช่ JSON ไม่ทำให้พัง', () {
    expect(QueueSocketEventModel.tryParse('not json'), isNull);
    expect(QueueSocketEventModel.tryParse('[1,2]'), isNull);
  });

  test('หลุด → ต่อใหม่ (2 วิ, 4 วิ …) → ต่อได้แล้วแจ้ง reconnected', () {
    fakeAsync((async) {
      socket = create()..start();
      var reconnects = 0;
      socket.reconnected.listen((_) => reconnects++);

      server.last.open();
      async.flushMicrotasks();
      expect(reconnects, 0, reason: 'ต่อครั้งแรกไม่นับ');

      server.last.drop();
      async.flushMicrotasks();
      expect(socket.status.value, SocketStatus.disconnected);
      expect(server.connections, hasLength(1));

      async.elapse(const Duration(seconds: 2));
      expect(server.connections, hasLength(2));

      server.last.fail(); // ครั้งที่ 2 ยังไม่ได้
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      expect(server.connections, hasLength(2), reason: 'รอบนี้หน่วง 4 วิ');
      async.elapse(const Duration(seconds: 1));
      expect(server.connections, hasLength(3));

      server.last.open();
      async.flushMicrotasks();
      expect(socket.status.value, SocketStatus.connected);
      expect(reconnects, 1);
      socket.dispose();
    });
  });

  test('reconnectNow ใช้ token ใหม่ และปิดตัวเก่า', () {
    fakeAsync((async) {
      socket = create()..start();
      server.last.open();
      async.flushMicrotasks();
      final old = server.last;

      token = 'token-2';
      socket.reconnectNow();
      async.flushMicrotasks();

      expect(old.closed, isTrue);
      expect(server.last.uri.pathSegments.last, 'token-2');
      socket.dispose();
    });
  });
}
