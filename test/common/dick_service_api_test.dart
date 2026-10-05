import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/dick_service_api.dart';
import 'package:fl_clash/common/dick_service_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final Map<String, Object?> responses;
  final Map<String, int> statusCodes;

  _Adapter({this.responses = const {}, this.statusCodes = const {}});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data =
        responses[options.path] ??
        responses[options.uri.path] ??
        (options.uri.path == DickServiceApi.epGetSubscribe
            ? {
                'plan_id': 3,
                'plan': {'name': 'Example', 'reset_price': 600},
                'subscribe_url': 'https://example.com/sub',
              }
            : {
                'plan': {'name': 'Example'},
                'expired_at': 2000000000,
              });
    final statusCode =
        statusCodes[options.path] ?? statusCodes[options.uri.path] ?? 200;
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      statusCode,
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
      expect(adapter.requests.map((r) => r.uri.path), [
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
    'subscription tolerates user-info failure like the AOT catch path',
    () async {
      final adapter = _Adapter(statusCodes: {DickServiceApi.epUserInfo: 500});
      final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
        ..httpClientAdapter = adapter;
      final api = DickServiceApi(dio: dio);

      final result = await api.fetchSubscribe('example-token');

      expect(result.planId, 3);
      expect(result.planName, 'Example');
      expect(result.expiredAt, 0);
      expect(adapter.requests.map((request) => request.uri.path), [
        DickServiceApi.epGetSubscribe,
        DickServiceApi.epUserInfo,
      ]);
      dio.close();
    },
  );

  test('AOT plan prices are period-keyed positive cents', () {
    final plan = DickServicePlan.fromJson({
      'id': 7,
      'name': 'Example',
      'month_price': 100,
      'quarter_price': '250',
      'half_year_price': 0,
      'year_price': -1,
      'two_year_price': '1.5',
    });
    expect(plan.priceOptions.map((option) => option.id), ['月付', '季付']);
    expect(plan.priceOptions.map((option) => option.period), [
      'month_price',
      'quarter_price',
    ]);
    expect(plan.priceOptions.map((option) => option.price), [100, 250]);
    expect(plan.priceOptions.first.formattedPrice, '¥1');
    expect(plan.priceOptions[1].formattedPrice, '¥2.50');
  });

  test('typed list methods unwrap AOT response shapes', () async {
    final adapter = _Adapter(
      responses: {
        DickServiceApi.epPlanFetch: [
          {'id': 1, 'name': 'Plan', 'month_price': 100},
        ],
        DickServiceApi.epOrderFetch: {
          'orders': [
            {'trade_no': 'T1', 'plan_name': 'Plan', 'status': 6},
          ],
        },
        DickServiceApi.epTicketFetch: [
          {'id': 2, 'subject': 'Help', 'status': 0},
        ],
      },
    );
    final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
      ..httpClientAdapter = adapter;
    final api = DickServiceApi(dio: dio);

    final plans = await api.fetchPlans();
    final orders = await api.fetchOrders('auth');
    final tickets = await api.fetchTickets('auth');
    expect(plans.single.priceOptions.single.id, '月付');
    expect(plans.single.priceOptions.single.period, 'month_price');
    expect(orders.single.planName, 'Plan');
    expect(orders.single.statusText, '已关闭');
    expect(tickets.single.subject, 'Help');
    dio.close();
  });

  test(
    'typed list methods reject non-map elements like AOT conversion',
    () async {
      final adapter = _Adapter(
        responses: {
          DickServiceApi.epPlanFetch: ['invalid'],
          DickServiceApi.epOrderFetch: {
            'orders': ['invalid'],
          },
          DickServiceApi.epTicketFetch: {
            'tickets': ['invalid'],
          },
        },
      );
      final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
        ..httpClientAdapter = adapter;
      final api = DickServiceApi(dio: dio);

      await expectLater(api.fetchPlans(), throwsA(isA<TypeError>()));
      await expectLater(api.fetchOrders('auth'), throwsA(isA<TypeError>()));
      await expectLater(api.fetchTickets('auth'), throwsA(isA<TypeError>()));
      dio.close();
    },
  );

  test('subscribe derived values follow AOT semantics', () {
    final subscribe = DickServiceSubscribe.fromJson({
      'plan_id': 1,
      'transfer_enable': 0,
      'prices': {'reset_traffic': 4096},
    });
    expect(subscribe.resetPrice, 0);
    final selectedPlan = DickServiceSubscribe.fromJson({
      'plan_id': 1,
      'plan': {
        'prices': {'reset_traffic': 4096, 'reset_price': 600},
        'reset_price': 700,
      },
    });
    expect(
      selectedPlan.resetPrice,
      4096,
      reason:
          'AOT 0x686e28 prefers plan.prices.reset_traffic even though Mine '
          'uses the resulting field as the reset order price',
    );
    expect(
      DickServiceSubscribe.fromJson({
        'plan_id': 1,
        'plan': {
          'prices': {'reset_price': 600},
          'reset_price': 700,
        },
      }).resetPrice,
      700,
      reason:
          'AOT 0x686e54 falls back to plan.reset_price, not '
          'plan.prices.reset_price',
    );
    expect(subscribe.remainingTrafficRatio(), 1.0);
    expect(subscribe.shouldWarnTrafficReset(), isFalse);
    expect(
      const DickServiceSubscribe(
        planName: 'Threshold',
        hasActivePlan: true,
        expiredAt: 0,
        transferEnable: 100,
        u: 90,
        d: 0,
        planId: 1,
      ).shouldWarnTrafficReset(),
      isTrue,
      reason: 'AOT 0x88c8fc and 0xab13f0 include the exact 10% boundary',
    );
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expect(
      DickServiceSubscribe(
        planName: 'Expires now',
        hasActivePlan: true,
        expiredAt: nowSeconds,
        transferEnable: 0,
        u: 0,
        d: 0,
        planId: 1,
      ).isTimeBasedExpired(),
      isTrue,
      reason: 'AOT 0x685fa0 negates expireTime.isAfter(now)',
    );
    expect(
      const DickServiceSubscribe(
        planName: 'Negative expiry',
        hasActivePlan: false,
        expiredAt: -1,
        transferEnable: 0,
        u: 0,
        d: 0,
        planId: 0,
      ).expireTime().millisecondsSinceEpoch,
      0,
      reason: 'AOT 0x685ff8 clamps negative expiry seconds to the epoch',
    );
    expect(
      DickServiceSubscribe(
        planName: 'Renewal threshold',
        hasActivePlan: true,
        expiredAt: nowSeconds + 3 * 24 * 3600 + 12 * 3600,
        transferEnable: 0,
        u: 0,
        d: 0,
        planId: 1,
      ).shouldWarnRenewal(),
      isTrue,
      reason: 'AOT 0x88cdb8 compares truncated inDays <= 3',
    );
    expect(
      DickServiceSubscribe(
        planName: 'Outside renewal threshold',
        hasActivePlan: true,
        expiredAt: nowSeconds + 4 * 24 * 3600 + 3600,
        transferEnable: 0,
        u: 0,
        d: 0,
        planId: 1,
      ).shouldWarnRenewal(),
      isFalse,
    );
    expect(
      const DickServiceSubscribe(
        planName: 'Traffic formatting',
        hasActivePlan: true,
        expiredAt: 0,
        transferEnable: 102912,
        u: 0,
        d: 0,
        planId: 1,
      ).formattedTotalTraffic,
      '101KB',
      reason: 'AOT 0xab0bf8 uses zero decimals from 100 units upward',
    );
    expect(subscribe.remainingTimeText(), '长期有效');
    expect(
      subscribe.normalizedExpiredAt(),
      -1,
      reason: 'AOT 0x6865f8 normalizes an active plan without expiry',
    );
    expect(
      const DickServiceSubscribe(
        planName: 'No plan',
        hasActivePlan: false,
        expiredAt: 0,
        transferEnable: 0,
        u: 0,
        d: 0,
        planId: 0,
      ).normalizedExpiredAt(),
      0,
      reason: 'AOT preserves non-positive expiry when no plan is active',
    );
    expect(
      const DickServiceSubscribe(
        planName: 'No plan',
        hasActivePlan: false,
        expiredAt: -7,
        transferEnable: 0,
        u: 0,
        d: 0,
        planId: 0,
      ).normalizedExpiredAt(),
      -7,
      reason: 'AOT preserves negative expiry when no plan is active',
    );
    expect(
      const DickServiceSubscribe(
        planName: 'Plan',
        hasActivePlan: true,
        expiredAt: 0,
        transferEnable: 1024 * 1024 * 1024 * 1024 * 1024 * 2,
        u: 0,
        d: 0,
        planId: 1,
      ).formattedTotalTraffic,
      '2PB',
    );
  });

  test('gift summary includes invite rewards using AOT delimiters', () {
    final result = DickServiceGiftCardRedeemResult.fromJson({
      'message': '兑换成功',
      'template_name': '会员礼品卡',
      'rewards': {'套餐': '月付', '空值': ''},
      'invite_rewards': {'余额': 100},
    });
    expect(result.summary, '兑换成功：会员礼品卡；套餐: 月付；邀请奖励：余额: 100');
  });

  test('plan parsing preserves APK root price keys and visibility', () {
    final plan = DickServicePlan.fromJson({
      'id': 7,
      'name': ' Plan ',
      'content': '* line one *\n\n line two ',
      'transfer_enable': '4096',
      'show': false,
      'month_price': '100',
      'quarter_price': 0,
      'prices': {'month_price': 999},
    });
    expect(plan.name, ' Plan ');
    expect(plan.transferEnable, 4096);
    expect(plan.show, isFalse);
    expect(plan.contentPreview, 'line one\nline two');
    expect(plan.priceOptions.single.id, '月付');
    expect(plan.priceOptions.single.period, 'month_price');
    expect(plan.priceOptions.single.price, 100);
  });

  test('model string and order fallbacks preserve AOT behavior', () {
    expect(
      DickServiceTicket.fromJson({'subject': ' Ticket '}).subject,
      ' Ticket ',
    );
    expect(DickServiceTicket.fromJson({'subject': ''}).subject, '');
    expect(DickServiceTicket.fromJson({'subject': 42}).subject, '42');
    expect(
      DickServiceTicket.fromJson({
        'created_at': 'old',
        'updated_at': 'new',
      }).updatedAt,
      'new',
    );
    expect(
      DickServiceSubscribe.fromJson({
        'plan': {'name': ' Plan '},
      }).planName,
      ' Plan ',
    );
    final userOrder = DickServiceUserOrder.fromJson({
      'id': 42,
      'plan': {'name': 'Nested plan'},
    });
    expect(userOrder.tradeNo, '42');
    expect(userOrder.planName, 'Nested plan');
    expect(DickServiceOrder.fromJson({'id': 43}).tradeNo, '43');
    expect(
      DickServiceUserOrder.fromJson({'status': '1.5'}).status,
      0,
      reason: 'AOT _intValue at 0x686ff0 uses int.tryParse only',
    );
    expect(
      DickServiceSubscribe.fromJson({'plan_id': -7}).planId,
      -7,
      reason:
          'AOT _firstPositiveInt at 0x6872b8 preserves the first non-null '
          'value when neither candidate is positive',
    );
    expect(
      DickServiceSubscribe.fromJson({'plan_id': -7}, {'plan_id': 9}).planId,
      9,
    );
  });

  test('checkout rejects malformed payload with service error', () {
    expect(
      () => DickServiceApi.parseCheckoutResponse({
        'data': {'html': null},
      }),
      throwsA(predicate((error) => error.toString().contains('支付链接返回为空'))),
    );
    expect(
      () => DickServiceApi.parseCheckoutResponse({
        'data': {
          'nested': [
            {'url': 'https://pay.example/must-not-be-found'},
          ],
        },
      }),
      throwsA(predicate((error) => error.toString().contains('支付链接返回为空'))),
      reason: 'AOT map recursion does not descend into list values',
    );
  });

  test('signature nonce is UUID v4 formatted', () async {
    final adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
      ..httpClientAdapter = adapter;
    final api = DickServiceApi(dio: dio);
    await api.fetchUserInfo('auth');
    final nonce = adapter.requests.single.headers['X-Client-Nonce'] as String;
    expect(
      nonce,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    dio.close();
  });

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
      expect(adapter.requests.map((request) => request.uri.path), [
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

  test('login maps only HTTP 401 and 422 to invalid credentials', () async {
    final adapter = _Adapter(statusCodes: {DickServiceApi.epLogin: 422});
    final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
      ..httpClientAdapter = adapter;
    final api = DickServiceApi(dio: dio);
    await expectLater(
      api.login('mail@example.com', 'secret'),
      throwsA(predicate((error) => error.toString().contains('账号或密码错误'))),
    );
    dio.close();
  });

  test(
    'login wraps non-credential failures after exhausting endpoints',
    () async {
      final adapter = _Adapter(
        responses: {DickServiceApi.epLogin: const <String, Object?>{}},
      );
      final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
        ..httpClientAdapter = adapter;
      final api = DickServiceApi(dio: dio);
      await expectLater(
        api.login('mail@example.com', 'secret'),
        throwsA(
          predicate(
            (error) =>
                error.toString() ==
                'Exception: 没有可用的 Dick Service 登录入口，请稍后重试：'
                    'Exception: Login succeeded but auth data is missing',
          ),
        ),
      );
      dio.close();
    },
  );

  test('login does not search list values for auth data', () async {
    final adapter = _Adapter(
      responses: {
        DickServiceApi.epLogin: {
          'nested': [
            {'token': 'must-not-be-found'},
          ],
        },
      },
    );
    final dio = Dio(BaseOptions(baseUrl: DickServiceApi.baseUrl))
      ..httpClientAdapter = adapter;
    final api = DickServiceApi(dio: dio);
    await expectLater(
      api.login('mail@example.com', 'secret'),
      throwsA(
        predicate(
          (error) => error.toString().contains(
            'Login succeeded but auth data is missing',
          ),
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
    dio.close();
  });

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
    final resetOrder = await api.createTrafficResetOrder('auth', 7);
    expect(resetOrder.tradeNo, 'T1');
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
    expect(adapter.requests[1].data, {'plan_id': 7, 'period': 'reset_price'});
    expect(adapter.requests[2].data, {'trade_no': 'T1', 'method': 3});
    expect(adapter.requests[3].data, {'code': 'GIFT'});
    expect(adapter.requests[4].data, {
      'subject': 'subject',
      'message': 'body',
      'level': 2,
    });
    expect(adapter.requests[5].data, {'trade_no': 'T1'});
    for (final request in adapter.requests) {
      expect(request.headers['Authorization'], 'auth');
    }
    dio.close();
  });
}
