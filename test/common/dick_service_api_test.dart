import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = options.path == DickServiceApi.epGetSubscribe
        ? {'plan_id': 3, 'subscribe_url': 'https://example.com/sub'}
        : {
            'plan': {'name': 'Example'},
            'expired_at': 2000000000,
          };
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'subscription joins both observed GET payloads and signs the requests',
    () async {
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
        ..httpClientAdapter = adapter;
      final api = DickServiceApi(dio: dio);
      final result = await api.fetchSubscribe('example-token');
      expect(result.planId, 3);
      expect(result.planName, 'Example');
      expect(result.expiredAt, 2000000000);
      expect(adapter.requests.map((r) => r.path), [
        DickServiceApi.epGetSubscribe,
        DickServiceApi.epUserInfo,
      ]);
      for (final request in adapter.requests) {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'example-token');
        final canonical = [
          'GET',
          request.uri.path,
          request.headers['X-Client-Ts'],
          request.headers['X-Client-Nonce'],
          sha256.convert(const <int>[]).toString(),
        ].join('\n');
        expect(
          request.headers['X-Client-Sign'],
          Hmac(
            sha256,
            utf8.encode(DickServiceApi.hmacKeyHexLike),
          ).convert(utf8.encode(canonical)).toString(),
        );
      }
      dio.close();
    },
  );

  test('unsupported writes cannot reach the transport', () async {
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final api = DickServiceApi(dio: dio);
    await expectLater(
      api.login(email: 'a', password: 'b'),
      throwsUnimplementedError,
    );
    await expectLater(api.createOrder('a', {}), throwsUnimplementedError);
    await expectLater(api.checkoutOrder('a', 'b', 1), throwsUnimplementedError);
    expect(adapter.requests, isEmpty);
    dio.close();
  });
}
