// Port of Dick Service v1.0.15 AOT models — static-only reconstruction.
// Evidence: aot-dick-full/asm/fl_clash/common/dick_service_api.dart
// Classes 2667..2675. Do NOT treat as production contract until capture.

int _intValue(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v.trim())?.toInt() ?? 0;
  return 0;
}

int? _nullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return num.tryParse(t)?.toInt();
  }
  return null;
}

int? _firstNullableInt(Map a, Map? b, String key) {
  final av = a[key];
  final bv = b == null ? null : b[key];
  return _nullableInt(av) ?? _nullableInt(bv);
}

int _firstPositiveInt(Map a, Map? b, String key) {
  final v = _firstNullableInt(a, b, key);
  if (v == null || v <= 0) return 0;
  return v;
}

Map<String, dynamic>? _firstMap(Map a, Map? b, String key) {
  final av = a[key];
  if (av is Map) return Map<String, dynamic>.from(av);
  final bv = b == null ? null : b[key];
  if (bv is Map) return Map<String, dynamic>.from(bv);
  return null;
}

String _stringValue(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

// DickServiceTicket — size 0x28, fields: subject/status/replyStatus/level/createdAt/updatedAt/id
// Default subject "未命名工单", replyStatusText logic verified.
class DickServiceTicket {
  final int id;
  final String subject;
  final int status;
  final int replyStatus;
  final int level;
  final String createdAt;
  final String updatedAt;

  const DickServiceTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.replyStatus,
    required this.level,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DickServiceTicket.fromJson(Map<String, dynamic> json) {
    final id = _intValue(json['id']);
    final rawSubject = json['subject'];
    String subject;
    if (rawSubject is String && rawSubject.trim().isNotEmpty) {
      subject = rawSubject.trim();
    } else {
      subject = '未命名工单';
    }
    final status = _intValue(json['status']);
    final replyStatus = _intValue(json['reply_status']);
    final level = _intValue(json['level']);
    final createdAt = _stringValue(json['created_at']);
    final updatedAt = _stringValue(json['updated_at']);
    return DickServiceTicket(
      id: id,
      subject: subject,
      status: status,
      replyStatus: replyStatus,
      level: level,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String get replyStatusText {
    if (replyStatus == 0) return '等待回复';
    if (replyStatus == 2) return '已回复';
    return '回复状态 $replyStatus';
  }
}

// DickServiceSubscribe — size 0x40, tolerant fromJson with aliases
class DickServiceSubscribe {
  final String planName;
  final bool hasActivePlan;
  final int expiredAt; // seconds since epoch, 0 if none
  final int transferEnable;
  final int u;
  final int d;
  final int? resetDay;
  final int? resetPrice;
  final int? resetTraffic;
  final int planId;
  final Map<String, dynamic>? plan;

  const DickServiceSubscribe({
    required this.planName,
    required this.hasActivePlan,
    required this.expiredAt,
    required this.transferEnable,
    required this.u,
    required this.d,
    this.resetDay,
    this.resetPrice,
    this.resetTraffic,
    required this.planId,
    this.plan,
  });

  // AOT tolerant: checks "plan" map vs root, "plan_id", "expired_at", "transfer_enable", "u"/"d", "reset_day", "name"
  factory DickServiceSubscribe.fromJson(
    Map<String, dynamic> a, [
    Map<String, dynamic>? b,
  ]) {
    final planMap = _firstMap(a, b, 'plan');
    final planId = _firstPositiveInt(a, b, 'plan_id');
    final expiredAt = _firstNullableInt(a, b, 'expired_at') ?? 0;
    final transferEnable = _firstNullableInt(a, b, 'transfer_enable') ?? 0;
    final u = _firstNullableInt(a, b, 'u') ?? 0;
    final d = _firstNullableInt(a, b, 'd') ?? 0;
    final resetDay = _firstNullableInt(a, b, 'reset_day');
    final prices = planMap == null ? null : _firstMap(planMap, null, 'prices');
    final resetPrice =
        _nullableInt(prices?['reset_price']) ??
        _nullableInt(planMap?['reset_price']);
    final resetTraffic = _nullableInt(prices?['reset_traffic']);

    String planName = '暂无套餐';
    if (planMap != null) {
      final n = planMap['name'];
      if (n is String && n.trim().isNotEmpty) planName = n.trim();
    }
    final hasActivePlan = planId > 0 || planMap != null;
    return DickServiceSubscribe(
      planName: planName,
      hasActivePlan: hasActivePlan,
      expiredAt: expiredAt,
      transferEnable: transferEnable,
      u: u,
      d: d,
      resetDay: resetDay,
      resetPrice: resetPrice,
      resetTraffic: resetTraffic,
      planId: planId,
      plan: planMap,
    );
  }

  int normalizedExpiredAt() {
    // AOT 0x6865f8: no active plan returns expiredAt unchanged; an active
    // plan with a non-positive expiry is normalized to -1.
    if (hasActivePlan && expiredAt <= 0) return -1;
    return expiredAt;
  }

  DateTime? expireTime() {
    if (expiredAt <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000, isUtc: false);
  }

  bool isTimeBasedExpired() {
    if (expiredAt <= 0) return false;
    final et = expireTime();
    if (et == null) return false;
    return DateTime.now().isAfter(et);
  }

  bool isExpired() {
    if (!hasActivePlan) return true;
    return isTimeBasedExpired();
  }

  // AOT derived helpers (simplified but evidence-aligned)
  double remainingTrafficRatio() {
    if (transferEnable <= 0) return 1.0;
    final ratio = (remainingTraffic() / transferEnable).toDouble();
    return ratio.clamp(0.0, 1.0);
  }

  int remainingTraffic() {
    final r = transferEnable - u - d;
    return r < 0 ? 0 : r;
  }

  bool shouldWarnTrafficReset() {
    return transferEnable > 0 && remainingTrafficRatio() < 0.1;
  }

  bool shouldWarnRenewal() {
    if (expiredAt <= 0) return false;
    final rem = expiredAt * 1000 - DateTime.now().millisecondsSinceEpoch;
    // warn within 3 days
    return rem > 0 && rem < 3 * 24 * 3600 * 1000;
  }

  String remainingTimeText() {
    if (!hasActivePlan) return '未开通/已过期';
    if (expiredAt <= 0) return '长期有效';
    final et = expireTime();
    final days = et!.difference(DateTime.now()).inDays;
    if (days < 0) return '已过期';
    if (days == 0) return '今天到期';
    return '剩余 $days 天';
  }

  static String _formatBytes(int v) {
    if (v <= 0) return '0B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    double d = v.toDouble();
    int i = 0;
    while (d >= 1024 && i < units.length - 1) {
      d /= 1024;
      i++;
    }
    final decimals = d == d.truncateToDouble() ? 0 : 1;
    return '${d.toStringAsFixed(decimals)}${units[i]}';
  }

  String get formattedTotalTraffic => _formatBytes(transferEnable);
  String get formattedUsedTraffic => _formatBytes(u + d);
  String get formattedRemainingTraffic => _formatBytes(remainingTraffic());
  String get contentPreview =>
      '$planName · $formattedRemainingTraffic / $formattedTotalTraffic';
}

class DickServiceGiftCardRedeemResult {
  final String message;
  final String templateName;
  final int? planId;
  final List<dynamic> rewards;
  final List<dynamic> inviteRewards;

  const DickServiceGiftCardRedeemResult({
    required this.message,
    required this.templateName,
    this.planId,
    required this.rewards,
    required this.inviteRewards,
  });

  factory DickServiceGiftCardRedeemResult.fromJson(Map<String, dynamic> json) {
    final msg =
        json['message'] is String &&
            (json['message'] as String).trim().isNotEmpty
        ? (json['message'] as String).trim()
        : '兑换成功';
    final tpl = _stringValue(json['template_name']);
    final pid = _nullableInt(json['plan_id']);
    List<dynamic> rewards = const [];
    if (json['rewards'] is List) {
      rewards = List<dynamic>.from(json['rewards'] as List);
    }
    List<dynamic> invite = const [];
    if (json['invite_rewards'] is List) {
      invite = List<dynamic>.from(json['invite_rewards'] as List);
    }
    return DickServiceGiftCardRedeemResult(
      message: msg,
      templateName: tpl,
      planId: pid,
      rewards: rewards,
      inviteRewards: invite,
    );
  }

  String get summary {
    final sections = <String>[];
    if (rewards.isNotEmpty) sections.add(_formatRewards(rewards));
    if (inviteRewards.isNotEmpty) {
      sections.add('邀请奖励：${_formatRewards(inviteRewards)}');
    }
    return sections.isEmpty ? message : sections.join('；');
  }

  static String _formatRewards(List<dynamic> list) {
    if (list.isEmpty) return '兑换成功';
    return list.map((e) => e.toString()).join('，');
  }
}

class DickServiceUserOrder {
  final int? id;
  final String plan;
  final String planName;
  final String tradeNo;
  final String name;
  final int status;
  final int totalAmount; // cents?
  final String period;
  final List<String> tags;
  final String? createdAt;

  const DickServiceUserOrder({
    this.id,
    required this.plan,
    required this.planName,
    required this.tradeNo,
    required this.name,
    required this.status,
    required this.totalAmount,
    required this.period,
    required this.tags,
    this.createdAt,
  });

  factory DickServiceUserOrder.fromJson(Map<String, dynamic> json) {
    final plan = _stringValue(json['plan']);
    final planName = _stringValue(
      json['plan_name'] ?? json['planName'] ?? json['name'],
    );
    final tradeNo = _stringValue(json['trade_no'] ?? json['tradeNo']);
    final name = _stringValue(json['name']);
    final status = _intValue(json['status']);
    final totalAmount = _intValue(
      json['total_amount'] ?? json['totalAmount'] ?? json['amount'],
    );
    final period = _stringValue(json['period']);
    List<String> tags = const [];
    if (json['tags'] is List) {
      tags = (json['tags'] as List).map((e) => e.toString()).toList();
    }
    final createdAt = json['created_at'] is String
        ? json['created_at'] as String
        : json['createdAt'] is String
        ? json['createdAt'] as String
        : null;
    return DickServiceUserOrder(
      plan: plan,
      planName: planName,
      id: _nullableInt(json['id']),
      tradeNo: tradeNo,
      name: name,
      status: status,
      totalAmount: totalAmount,
      period: period,
      tags: tags,
      createdAt: createdAt,
    );
  }

  String get formattedAmount => '¥${_formatCents(totalAmount)}';
  String get statusText {
    switch (status) {
      case 0:
        return '待支付';
      case 1:
        return '已支付';
      case 2:
        return '已取消';
      case 6:
        return '已关闭';
      default:
        return '状态 $status';
    }
  }
}

class DickServiceOrder {
  final String tradeNo;
  final String? tradeNoAlt;

  const DickServiceOrder({required this.tradeNo, this.tradeNoAlt});

  factory DickServiceOrder.fromJson(Map<String, dynamic> json) {
    final a = _stringValue(json['trade_no']);
    final b = _stringValue(json['tradeNo']);
    final v = a.isNotEmpty ? a : b;
    return DickServiceOrder(tradeNo: v, tradeNoAlt: b.isEmpty ? null : b);
  }
}

class DickServiceCheckout {
  final String? url;
  final String? html;

  const DickServiceCheckout._({this.url, this.html});
  factory DickServiceCheckout.url(String url) =>
      DickServiceCheckout._(url: url);
  factory DickServiceCheckout.html(String html) =>
      DickServiceCheckout._(html: html);
}

class DickServicePriceOption {
  final String id;
  final int price; // cents
  final String? period;
  final int? resetPrice;

  const DickServicePriceOption({
    required this.id,
    required this.price,
    this.period,
    this.resetPrice,
  });

  String get formattedPrice => '¥${_formatCents(price)}';
}

class DickServicePlan {
  final int id;
  final String name;
  final String content;
  final List<String> tags;
  final List<DickServicePriceOption> prices;

  const DickServicePlan({
    required this.id,
    required this.name,
    required this.content,
    required this.tags,
    required this.prices,
  });

  factory DickServicePlan.fromJson(Map<String, dynamic> json) {
    final id = _intValue(json['id']);
    final name =
        json['name'] is String && (json['name'] as String).trim().isNotEmpty
        ? (json['name'] as String).trim()
        : '未命名套餐';
    final content = _stringValue(json['content']);
    List<String> tags = const [];
    if (json['tags'] is List) {
      tags = (json['tags'] as List).map((e) => e.toString()).toList();
    }
    final prices = <DickServicePriceOption>[];
    final rawPrices = json['prices'];
    if (rawPrices is Map) {
      for (final entry in rawPrices.entries) {
        final period = entry.key.toString();
        final price = _positiveInt(entry.value);
        if (price > 0) {
          prices.add(
            DickServicePriceOption(id: period, price: price, period: period),
          );
        }
      }
    }
    return DickServicePlan(
      id: id,
      name: name,
      content: content,
      tags: tags,
      prices: prices,
    );
  }

  List<DickServicePriceOption> get priceOptions => prices;
}

int _positiveInt(dynamic value) {
  final parsed = _intValue(value);
  return parsed > 0 ? parsed : 0;
}

String _formatCents(int cents) {
  final amount = cents / 100;
  final rounded = amount.roundToDouble();
  return amount == rounded
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}

class AuthSession {
  final String token;
  const AuthSession({required this.token});
}
