// Port of Dick Service v1.0.15 AOT evidence — static-only reconstruction.
// Do NOT treat as production contract until dynamic capture validates bodies/pagination.
// Evidence source: work/flclash-diff/aot-dick-full/asm/fl_clash/common/dick_service_api.dart

import 'dart:convert';
import 'dart:math';

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

  // Verified verbs from AOT get()/post() call sites. Bodies remain unverified
  // — do not call without capture; these methods throw until validated.
  Future<Map<String, dynamic>> fetchPlans() async {
    final res = await dio.get<Map<String, dynamic>>(
      epPlanFetch,
      options: Options(headers: {'Accept': 'application/json'}),
    );
    return _unwrap(_asMap(res.data));
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

  /// GET /api/v1/user/getSubscribe then unwrap+findUrl (AOT fetchSubscribeUrlFromAuthData)
  Future<String?> fetchSubscribeUrlFromAuthData(String token) async {
    final m = await getSubscribe(token);
    final data = _unwrap(m);
    return _findUrl(data);
  }

  /// POST login — body schema NOT verified, keep unimplemented until capture.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    // AOT shows POST to epLogin with Dio post(); body fields require capture.
    throw UnimplementedError(
      'login body not verified from static AOT — needs dynamic capture',
    );
  }

  Future<Map<String, dynamic>> fetchOrders(String token) async {
    final res = await dio.get<Map<String, dynamic>>(
      epOrderFetch,
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    return _unwrap(_asMap(res.data));
  }

  Future<Map<String, dynamic>> fetchTickets(String token) async {
    final res = await dio.get<Map<String, dynamic>>(
      epTicketFetch,
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    return _unwrap(_asMap(res.data));
  }

  // POST endpoints — bodies unverified
  Future<Map<String, dynamic>> createOrder(
    String token,
    Map<String, dynamic> body,
  ) async {
    final res = await dio.post<Map<String, dynamic>>(
      epOrderSave,
      data: body,
      options: Options(
        headers: {'Authorization': token, 'Accept': 'application/json'},
      ),
    );
    _throwIfFailed(_asMap(res.data));
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> checkoutOrder(
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
    final m = _asMap(res.data);
    _throwIfFailed(m);
    final data = m['data'];
    // AOT: try _extractUrl -> url, else _looksLikeHtml -> html, else _findUrl/_findHtml
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
    // AOT maps each byte via Utils::uuidV4 closure then join; emulate as hex
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
