import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final Map<String, Object?> responses;

  _Adapter({this.responses = const {}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data =
        responses[options.path] ??
        (options.path == DickServiceApi.epGetSubscribe
            ? {
                'plan_id': 3,
                'reset_price': 600,
                'subscribe_url': 'https://example.com/sub',
              }
            : {
                'plan': {'name': 'Example'},
                'expired_at': 2000000000,
              });
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
      expect(result.resetPrice, 600);
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

  test(
    'login uses the observed body and validates the subscription URL',
    () async {
      final adapter = _Adapter(
        responses: {
          DickServiceApi.epLogin: {'token': 'auth-token'},
        },
      );
      final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
        ..httpClientAdapter = adapter;
      final api = DickServiceApi(dio: dio);
      final session = await api.login('mail@example.com', 'secret');
      expect(session.token, 'auth-token');
      expect(adapter.requests.map((request) => request.path), [
        DickServiceApi.epLogin,
        DickServiceApi.epGetSubscribe,
      ]);
      expect(adapter.requests.first.data, {
        'email': 'mail@example.com',
        'password': 'secret',
      });
      expect(adapter.requests.last.headers['Authorization'], 'auth-token');
      dio.close();
    },
  );

  test('write methods use the AOT-observed bodies', () async {
    final adapter = _Adapter(
      responses: {
        DickServiceApi.epOrderSave: {'trade_no': 'T1'},
        DickServiceApi.epOrderCheckout: {'url': 'https://pay.example/T1'},
        DickServiceApi.epGiftCardRedeem: {'message': '兑换成功'},
        DickServiceApi.epTicketSave: const <String, Object?>{},
        DickServiceApi.epOrderCancel: const <String, Object?>{},
      },
    );
    final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
      ..httpClientAdapter = adapter;
    final api = DickServiceApi(dio: dio);

    final order = await api.createOrder(
      'auth',
      'month_price',
      7,
      couponCode: 'SAVE',
    );
    expect(order.tradeNo, 'T1');
    final checkout = await api.checkoutOrder('auth', 'T1', 3);
    expect(checkout.url, 'https://pay.example/T1');
    await api.redeemGiftCard('auth', 'GIFT');
    await api.createTicket(
      'auth',
      level: 2,
      message: 'body',
      subject: 'subject',
    );
    await api.cancelOrder('auth', 'T1');

    expect(adapter.requests[0].data, {
      'plan_id': 7,
      'period': 'month_price',
      'coupon_code': 'SAVE',
    });
    expect(adapter.requests[1].data, {'trade_no': 'T1', 'method': 3});
    expect(adapter.requests[2].data, {'code': 'GIFT'});
    expect(adapter.requests[3].data, {
      'subject': 'subject',
      'message': 'body',
      'level': 2,
    });
    expect(adapter.requests[4].data, {'trade_no': 'T1'});
    for (final request in adapter.requests) {
      expect(request.headers['Authorization'], 'auth');
    }
    dio.close();
  });
}
