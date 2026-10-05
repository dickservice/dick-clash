// Port of Dick Service v1.0.15 AOT evidence.
// Evidence source: work/flclash-diff/aot-dick-full/asm/fl_clash/common/dick_service_api.dart

import 'dart:convert';
import 'dart:math';
import 'dick_service_models.dart';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Verified from AOT:
/// baseUrl, UA, client id, signing key, header names, join("\n") HMAC.
class DickServiceApi {
  static const String baseUrl = 'https://airport.dicksupport.top';
  static const String userAgent =
      'AuroraDeck/7.4.2 (Android; ndk-aurora-74; rv:20260630)';
  static const String clientId = 'ndk-aurora-74';
  // utf8 bytes of this hex-like string are the HMAC key — from AOT pp+0x23428
  static const String hmacKeyHexLike =
      'c9f1f637772c44f72f6914d02db94f5e4e0d3d9a833af0d6c70ba0a6e56bb7a4';

  // Endpoints confirmed as string literals in AOT
  static const String epLogin = '/api/v1/passport/auth/login';
  static const String epGetSubscribe = '/api/v1/user/getSubscribe';
  static const String epUserInfo = '/api/v1/user/info';
  static const String epPlanFetch = '/api/v1/guest/plan/fetch';
  static const String epOrderFetch = '/api/v1/user/order/fetch';
  static const String epOrderSave = '/api/v1/user/order/save';
  static const String epOrderCheckout = '/api/v1/user/order/checkout';
  static const String epOrderCancel = '/api/v1/user/order/cancel';
  static const String epTicketFetch = '/api/v1/user/ticket/fetch';
  static const String epTicketSave = '/api/v1/user/ticket/save';
  static const String epGiftCardRedeem = '/api/v1/user/gift-card/redeem';
  static const String epResetSecurity = '/api/v1/user/resetSecurity';
  static const String _invalidCredentials = '账号或密码错误';

  final Dio dio;

  DickServiceApi({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              headers: {'User-Agent': userAgent},
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (s) => s != null && s < 500,
            ),
          ) {
    this.dio.interceptors.add(_ClientSignatureInterceptor());
  }

  // Verified verbs, bodies, headers, and response handling from AOT call sites.
  Future<List<DickServicePlan>> fetchPlans() async {
    final res = await dio.get<Map<String, dynamic>>(
      epPlanFetch,
      options: Options(headers: {'Accept': 'application/json'}),
    );
    final response = _asMap(res.data);
    final data = response['data'];
    if (data is! List) throw Exception('套餐列表返回格式异常');
    return data
        .map((e) => DickServicePlan.fromJson(Map<String, dynamic>.from(e)))
        .where((plan) => plan.show)
        .toList();
  }

  Future<Map<String, dynamic>> fetchUserInfo(String token) async {
    final res = await dio.get<Map<String, dynamic>>(
      epUserInfo,
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    return _unwrap(_asMap(res.data));
  }

  Future<Map<String, dynamic>> getSubscribe(String token) async {
    final res = await dio.get<Map<String, dynamic>>(
      epGetSubscribe,
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    final m = _asMap(res.data);
    _throwIfFailed(m);
    return m;
  }

  /// AOT fetchSubscribe combines subscription and account fields.
  Future<DickServiceSubscribe> fetchSubscribe(String token) async {
    final subscribe = _unwrap(await getSubscribe(token));
    final info = await fetchUserInfo(token);
    return DickServiceSubscribe.fromJson(subscribe, info);
  }

  /// GET /api/v1/user/getSubscribe then unwrap+findUrl (AOT fetchSubscribeUrlFromAuthData)
  Future<String?> fetchSubscribeUrlFromAuthData(String token) async {
    final m = await getSubscribe(token);
    final data = _unwrap(m);
    return _findUrl(data);
  }

  Future<AuthSession> login(String email, String password) async {
    final endpoints = await _resolveEndpointCandidates();
    Object? lastError;
    for (final endpoint in endpoints) {
      try {
        return await _loginWithEndpoint(endpoint, email, password);
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if (status == 401 || status == 422) {
          throw Exception(_invalidCredentials);
        }
        lastError = error;
      } on Exception catch (error) {
        if (error.toString().contains(_invalidCredentials)) {
          rethrow;
        }
        // Preserve AOT server message / missing auth errors; do not swallow
        // into the generic endpoint-exhaustion message.
        rethrow;
      }
    }
    if (lastError != null) {
      // Keep the original network/protocol error visible while preserving
      // the AOT exhaustion wording for the single-candidate case.
      throw Exception('没有可用的 Dick Service 登录入口，请稍后重试：$endpoints ($lastError)');
    }
    throw Exception('没有可用的 Dick Service 登录入口，请稍后重试：$endpoints');
  }

  Future<List<DickServiceUserOrder>> fetchOrders(String token) async {
    final res = await dio.get<Map<String, dynamic>>(
      epOrderFetch,
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    final response = _asMap(res.data);
    _throwIfFailed(response);
    final data = response['data'];
    final raw = data is Map ? data['orders'] : data;
    if (raw is! List) throw Exception('订单列表返回格式异常');
    return raw
        .map((e) => DickServiceUserOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<DickServiceTicket>> fetchTickets(String token) async {
    final res = await dio.get<Map<String, dynamic>>(
      epTicketFetch,
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    final response = _asMap(res.data);
    _throwIfFailed(response);
    final data = response['data'];
    final raw = data is Map ? data['tickets'] : data;
    if (raw is! List) throw Exception('工单列表返回格式异常');
    return raw
        .map((e) => DickServiceTicket.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DickServiceOrder> createOrder(
    String token,
    String period,
    int planId, {
    String? couponCode,
  }) async {
    final body = <String, Object>{'plan_id': planId, 'period': period};
    if (couponCode != null && couponCode.isNotEmpty) {
      body['coupon_code'] = couponCode;
    }
    final res = await dio.post<Map<String, dynamic>>(
      epOrderSave,
      data: body,
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    return DickServiceOrder.fromJson(_unwrap(_asMap(res.data)));
  }

  /// AOT reset flow creates an order using the special `reset_price` period.
  Future<DickServiceOrder> createTrafficResetOrder(String token, int planId) =>
      createOrder(token, 'reset_price', planId);

  Future<DickServiceCheckout> checkoutOrder(
    String token,
    String tradeNo,
    int method,
  ) async {
    final res = await dio.post<Map<String, dynamic>>(
      epOrderCheckout,
      data: {'trade_no': tradeNo, 'method': method},
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    final parsed = parseCheckoutResponse(_asMap(res.data));
    final url = parsed['url'];
    if (url is String) return DickServiceCheckout.url(url);
    final html = parsed['html'];
    if (html is String) return DickServiceCheckout.html(html);
    throw Exception('支付链接返回为空');
  }

  Future<DickServiceGiftCardRedeemResult> redeemGiftCard(
    String token,
    String code,
  ) async {
    final res = await dio.post<Map<String, dynamic>>(
      epGiftCardRedeem,
      data: {'code': code},
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    final response = _asMap(res.data);
    _throwIfFailed(response);
    final data = response['data'];
    return DickServiceGiftCardRedeemResult.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : response,
    );
  }

  Future<void> createTicket(
    String token, {
    required int level,
    required String message,
    required String subject,
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      epTicketSave,
      data: {'subject': subject, 'message': message, 'level': level},
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    _throwIfFailed(_asMap(res.data));
  }

  Future<void> cancelOrder(String token, String tradeNo) async {
    final res = await dio.post<Map<String, dynamic>>(
      epOrderCancel,
      data: {'trade_no': tradeNo},
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    _throwIfFailed(_asMap(res.data));
  }

  Future<String> resetSecurity(String token) async {
    final res = await dio.get<Map<String, dynamic>>(
      epResetSecurity,
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    final response = _asMap(res.data);
    _throwIfFailed(response);
    final data = response['data'];
    final url = _findUrl(data is Map ? data : response);
    if (url == null) throw Exception('重置成功，但新订阅链接返回为空');
    return url;
  }

  /// Response-only parser; does not issue an unverified payment request.
  static Map<String, dynamic> parseCheckoutResponse(Map<String, dynamic> m) {
    _throwIfFailed(m);
    final data = m['data'];
    if (data is String) {
      final u = _extractUrl(data);
      if (u != null) return {'url': u};
      if (_looksLikeHtml(data)) return {'html': data};
    }
    if (data is Map) {
      final u = _findUrl(data);
      if (u != null) return {'url': u};
      final h = _findHtml(data);
      if (h != null) return {'html': h};
    }
    throw Exception('支付链接返回为空');
  }

  Future<List<_LoginEndpoint>> _resolveEndpointCandidates() async => [
    const _LoginEndpoint('https://airport.dicksupport.top'),
  ];

  Future<AuthSession> _loginWithEndpoint(
    _LoginEndpoint endpoint,
    String email,
    String password,
  ) async {
    final res = await dio.post<Map<String, dynamic>>(
      endpoint.uri(epLogin).toString(),
      data: {'email': email, 'password': password},
      options: Options(
        headers: {'Accept': 'application/json'},
        // Ensure 401/422 surface as DioException so login can map them to
        // 账号或密码错误, matching AOT 0x88ba8c-0x88bb2c; global validateStatus
        // is <500 and would otherwise swallow them as normal responses.
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final response = _asMap(res.data);
    final data = _unwrap(response);
    final token = _findAuthData(data);
    if (token == null || token.isEmpty) {
      throw Exception('Login succeeded but auth data is missing');
    }
    final subscribe = await dio.get<Map<String, dynamic>>(
      endpoint.uri(epGetSubscribe).toString(),
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    if (_findUrl(_unwrap(_asMap(subscribe.data))) == null) {
      throw Exception('Subscription URL is missing');
    }
    return AuthSession(token: token);
  }

  // --- helpers mirroring AOT ---

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    throw Exception(v is String && v.contains('入口 ') ? v : '返回格式异常');
  }

  static void _throwIfFailed(Map<String, dynamic> m) {
    final status = m['status']?.toString().toLowerCase();
    if (status == 'fail' || status == 'error') {
      final msg = m['message']?.toString() ?? '请求失败';
      throw Exception(msg);
    }
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> m) {
    _throwIfFailed(m);
    final d = m['data'];
    if (d is Map<String, dynamic>) return d;
    if (d is Map) return Map<String, dynamic>.from(d);
    return m;
  }

  static String? _extractUrl(String s) {
    s = s.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final m = RegExp(
      r'https?://[^\s"'
      '<>]+',
    ).firstMatch(s);
    return m?.group(0);
  }

  static bool _looksLikeHtml(String s) {
    final t = s.trimLeft().toLowerCase();
    return t.startsWith('<!doctype html') ||
        t.startsWith('<html') ||
        t.startsWith('<form') ||
        t.startsWith('<script');
  }

  static const _urlKeys = [
    'subscribe_url',
    'subscribeUrl',
    'payment_url',
    'paymentUrl',
    'checkout_url',
    'checkoutUrl',
    'pay_url',
    'payUrl',
    'payurl',
    'url',
    'qrcode',
    'qr_code',
    'clash',
    'clash_url',
  ];

  static String? _findUrl(dynamic v) {
    if (v is String) return _extractUrl(v);
    if (v is Map) {
      for (final k in _urlKeys) {
        final val = v[k];
        if (val is String) {
          final u = _extractUrl(val);
          if (u != null) return u;
        }
      }
      for (final val in v.values) {
        if (val is Map || val is String) {
          final u = _findUrl(val);
          if (u != null) return u;
        }
        if (val is List) {
          for (final e in val) {
            final u = _findUrl(e);
            if (u != null) return u;
          }
        }
      }
    }
    if (v is List) {
      for (final e in v) {
        final u = _findUrl(e);
        if (u != null) return u;
      }
    }
    return null;
  }

  static const _htmlKeys = ['html', 'form', 'content', 'data'];

  static const _authKeys = [
    'auth_data',
    'authData',
    'authorization',
    'Authorization',
    'token',
    'access_token',
    'accessToken',
  ];

  static String? _findAuthData(dynamic value) {
    if (value is Map) {
      for (final key in _authKeys) {
        final candidate = value[key];
        if (candidate is String && candidate.isNotEmpty) return candidate;
      }
      for (final candidate in value.values) {
        if (candidate is Map || candidate is List) {
          final result = _findAuthData(candidate);
          if (result != null) return result;
        }
      }
    } else if (value is List) {
      for (final candidate in value) {
        final result = _findAuthData(candidate);
        if (result != null) return result;
      }
    }
    return null;
  }

  static String? _findHtml(dynamic v) {
    if (v is String && _looksLikeHtml(v)) return v;
    if (v is Map) {
      for (final k in _htmlKeys) {
        final val = v[k];
        if (val is String && _looksLikeHtml(val)) return val;
      }
      for (final val in v.values) {
        final h = _findHtml(val);
        if (h != null) return h;
      }
    }
    if (v is List) {
      for (final e in v) {
        final h = _findHtml(e);
        if (h != null) return h;
      }
    }
    return null;
  }
}

class _ClientSignatureInterceptor extends Interceptor {
  final Random _secure = Random.secure();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final tsSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ts = tsSec.toString();
    final nonce = _nonce();
    final bodyBytes = _canonicalBody(options.data);
    final bodyHash = _sha256Hex(bodyBytes);
    final pathWithQuery = options.uri.query.isEmpty
        ? options.uri.path
        : '${options.uri.path}?${options.uri.query}';
    final method = (options.method.isEmpty
        ? '/'
        : options.method.toUpperCase());
    // AOT joins 5 parts with "\n": [method, pathWithQuery, ts, nonce, bodyHash]
    // order derived from GrowableList join("\n") with 5 slots.
    final stringToSign = [
      method,
      pathWithQuery,
      ts,
      nonce,
      bodyHash,
    ].join('\n');
    final keyBytes = utf8.encode(DickServiceApi.hmacKeyHexLike);
    final hmac = Hmac(sha256, keyBytes);
    final sign = hmac.convert(utf8.encode(stringToSign)).toString();
    options.headers['User-Agent'] = DickServiceApi.userAgent;
    options.headers['X-Client-Id'] = DickServiceApi.clientId;
    options.headers['X-Client-Ts'] = ts;
    options.headers['X-Client-Nonce'] = nonce;
    options.headers['X-Client-Sign-Version'] = 'v1';
    options.headers['X-Client-Sign'] = sign;
    handler.next(options);
  }

  String _sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  List<int> _canonicalBody(dynamic data) {
    if (data == null) return const [];
    if (data is Map) return utf8.encode(jsonEncode(data));
    if (data is List<int>) return data;
    if (data is String) return utf8.encode(data);
    return utf8.encode(data.toString());
  }

  String _nonce() {
    final bytes = List<int>.generate(16, (_) => _secure.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10).join()}';
  }
}

class _LoginEndpoint {
  final String baseUrl;
  const _LoginEndpoint(this.baseUrl);

  Uri uri(String path) => Uri.parse('$baseUrl$path');
  @override
  String toString() => baseUrl;
}
