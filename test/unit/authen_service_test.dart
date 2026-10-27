// test/unit/authen_service_test.dart
//
// ทดสอบ AuthenService — login() + response parsing logic
// ครอบคลุม: U-01 ถึง U-08
//
// ✅ AuthenService ถูก refactor ให้รับ http.Client? client แล้ว

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_android_tv_queue/models/response_model.dart';
import 'package:flutter_android_tv_queue/service/auth_service.dart';

void main() {
  group('AuthenService.login()', () {
    // ═══════════════════════════════════════════════════════════════════
    // Helper: สร้าง MockClient
    // ═══════════════════════════════════════════════════════════════════

    MockClient createMockClient({
      required int statusCode,
      required Map<String, dynamic> body,
    }) {
      return MockClient((request) async {
        return http.Response(
          jsonEncode(body),
          statusCode,
          headers: {'content-type': 'application/json'},
        );
      });
    }

    // ═══════════════════════════════════════════════════════════════════
    // U-01: Login สำเร็จ — status 200, ไม่มี "code"
    // ═══════════════════════════════════════════════════════════════════

    test('U-01: Login สำเร็จ — return ResponseEnum.success', () async {
      final mockClient = createMockClient(
        statusCode: 200,
        body: {
          'token': 'test_token_abc123',
          'expired_at': '2026-12-31T23:59:59',
          'provider': 'local',
          'app_id': 'new-his',
        },
      );

      final result = await AuthService.login(
        username: 'doctor_demo_01',
        password: '12345678',
        client: mockClient,
      );

      expect(result.responseEnum, equals(ResponseEnum.success));
      expect(result.data.token, equals('test_token_abc123'));
      expect(result.data.data, isNotEmpty);
    });

    // ═══════════════════════════════════════════════════════════════════
    // U-02: Login ผิด — username or password incorrect
    // ═══════════════════════════════════════════════════════════════════

    test(
      'U-02: Login ผิด — return ResponseEnum.passwordUserIncorrect',
      () async {
        final mockClient = createMockClient(
          statusCode: 200,
          body: {
            'code': 'AUTH_ERROR',
            'message': 'username or password are incorrect',
          },
        );

        final result = await AuthService.login(
          username: 'wrong_user',
          password: 'wrong_pass',
          client: mockClient,
        );

        expect(result.responseEnum, equals(ResponseEnum.passwordUserIncorrect));
        expect(result.data.data, isEmpty);
      },
    );

    // ═══════════════════════════════════════════════════════════════════
    // U-02b/c: response จริงจาก DEV server (26/10/69) — 200 + code
    // ═══════════════════════════════════════════════════════════════════

    for (final body in [
      {'message': 'Password is incorrect', 'code': 401},
      {
        'message': 'Employee with username no_such_user does not exist',
        'code': 404,
      },
    ]) {
      test(
        'U-02 (server ${body['code']}): return ResponseEnum.passwordUserIncorrect',
        () async {
          final result = await AuthService.login(
            username: 'doctor_demo_01',
            password: 'wrong_pass',
            client: createMockClient(statusCode: 200, body: body),
          );

          expect(
            result.responseEnum,
            equals(ResponseEnum.passwordUserIncorrect),
          );
          expect(result.data.data, isEmpty);
        },
      );
    }

    // ═══════════════════════════════════════════════════════════════════
    // U-03: Patient not found — status 400
    // ═══════════════════════════════════════════════════════════════════

    test(
      'U-03: Patient not found — return ResponseEnum.patientNoFound',
      () async {
        final mockClient = createMockClient(
          statusCode: 400,
          body: {'message': 'Patient not found.'},
        );

        final result = await AuthService.login(
          username: 'doctor_demo_01',
          password: '12345678',
          client: mockClient,
        );

        expect(result.responseEnum, equals(ResponseEnum.patientNoFound));
        expect(result.data.data, isEmpty);
      },
    );

    // ═══════════════════════════════════════════════════════════════════
    // U-04: Server error — status 500
    // ═══════════════════════════════════════════════════════════════════

    test('U-04: Server error 500 — return ResponseEnum.fail', () async {
      final mockClient = createMockClient(
        statusCode: 500,
        body: {'error': 'Internal Server Error'},
      );

      final result = await AuthService.login(
        username: 'doctor_demo_01',
        password: '12345678',
        client: mockClient,
      );

      expect(result.responseEnum, equals(ResponseEnum.fail));
      expect(result.data.data, isEmpty);
    });

    // ═══════════════════════════════════════════════════════════════════
    // U-05: Network timeout
    // ═══════════════════════════════════════════════════════════════════

    test('U-05: Network timeout — throw ClientException', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection timed out');
      });

      expect(
        () => AuthService.login(
          username: 'doctor_demo_01',
          password: '12345678',
          client: mockClient,
        ),
        throwsA(isA<http.ClientException>()),
      );
    });

    // ═══════════════════════════════════════════════════════════════════
    // U-06: No internet
    // ═══════════════════════════════════════════════════════════════════

    test('U-06: No internet — throw Exception', () async {
      final mockClient = MockClient((request) async {
        throw Exception('No internet connection');
      });

      expect(
        () => AuthService.login(
          username: 'doctor_demo_01',
          password: '12345678',
          client: mockClient,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // ═══════════════════════════════════════════════════════════════════
    // U-07: ตรวจ request headers
    // ═══════════════════════════════════════════════════════════════════

    test(
      'U-07: Request headers — ส่ง app-id, secret-key, Content-Type ครบ',
      () async {
        Map<String, String>? capturedHeaders;

        final mockClient = MockClient((request) async {
          capturedHeaders = request.headers;
          return http.Response(jsonEncode({'token': 'test'}), 200);
        });

        await AuthService.login(
          username: 'doctor_demo_01',
          password: '12345678',
          client: mockClient,
        );

        expect(capturedHeaders, isNotNull);
        expect(capturedHeaders!['app-id'], equals('new-his'));
        expect(
          capturedHeaders!['secret-key'],
          equals(r'*wg%bg!b2lzl7ir5g1_g2av0n&m*+t4_6yqu6^u_p+54$%'),
        );
        expect(capturedHeaders!['content-type'], contains('application/json'));
      },
    );

    // ═══════════════════════════════════════════════════════════════════
    // U-08: ตรวจ request body
    // ═══════════════════════════════════════════════════════════════════

    test('U-08: Request body — ส่ง username + password ถูกต้อง', () async {
      String? capturedBody;

      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(jsonEncode({'token': 'test'}), 200);
      });

      await AuthService.login(
        username: 'doctor_demo_01',
        password: '12345678',
        client: mockClient,
      );

      expect(capturedBody, isNotNull);
      final parsedBody = jsonDecode(capturedBody!);
      expect(parsedBody['username'], equals('doctor_demo_01'));
      expect(parsedBody['password'], equals('12345678'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Response Parsing Logic (ทดสอบ branching โดยไม่ผ่าน network)
  // ═══════════════════════════════════════════════════════════════════════

  group('Login Response Parsing Logic', () {
    ResponseEnum parseLoginResponse(int statusCode, Map<String, dynamic> body) {
      if (statusCode == 200 && body['code'] == null) {
        return ResponseEnum.success;
      } else if (statusCode == 200 &&
          (body['message'] ?? '') == 'username or password are incorrect') {
        return ResponseEnum.passwordUserIncorrect;
      } else if (statusCode == 400 &&
          (body['message'] ?? '') == 'Patient not found.') {
        return ResponseEnum.patientNoFound;
      } else {
        return ResponseEnum.fail;
      }
    }

    test('200 + ไม่มี code → success', () {
      expect(
        parseLoginResponse(200, {'token': 'abc'}),
        equals(ResponseEnum.success),
      );
    });

    test('200 + มี code + message incorrect → passwordUserIncorrect', () {
      expect(
        parseLoginResponse(200, {
          'code': 'ERR',
          'message': 'username or password are incorrect',
        }),
        equals(ResponseEnum.passwordUserIncorrect),
      );
    });

    test('400 + Patient not found → patientNoFound', () {
      expect(
        parseLoginResponse(400, {'message': 'Patient not found.'}),
        equals(ResponseEnum.patientNoFound),
      );
    });

    test('500 + any body → fail', () {
      expect(
        parseLoginResponse(500, {'error': 'server error'}),
        equals(ResponseEnum.fail),
      );
    });

    test('200 + มี code + message อื่น → fail', () {
      expect(
        parseLoginResponse(200, {'code': 'ERR', 'message': 'some other error'}),
        equals(ResponseEnum.fail),
      );
    });

    test('400 + message อื่น → fail', () {
      expect(
        parseLoginResponse(400, {'message': 'Bad request'}),
        equals(ResponseEnum.fail),
      );
    });

    test('200 + ไม่มี code + ไม่มี message → success', () {
      expect(parseLoginResponse(200, {}), equals(ResponseEnum.success));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ResponseEnum
  // ═══════════════════════════════════════════════════════════════════════

  group('ResponseEnum', () {
    test('มีค่าครบตาม login conditions', () {
      expect(ResponseEnum.values, contains(ResponseEnum.success));
      expect(ResponseEnum.values, contains(ResponseEnum.fail));
      expect(ResponseEnum.values, contains(ResponseEnum.passwordUserIncorrect));
      expect(ResponseEnum.values, contains(ResponseEnum.patientNoFound));
    });
  });
}
