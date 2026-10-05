// Port of Dick Service v1.0.15 AOT models — static-only reconstruction.
// Evidence: aot-dick-full/asm/fl_clash/common/dick_service_api.dart
// Classes 2667..2675. Do NOT treat as production contract until capture.

int _intValue(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
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
  final av = _nullableInt(a[key]);
  if (av != null && av > 0) return av;
  final bv = _nullableInt(b == null ? null : b[key]);
  if (bv != null && bv > 0) return bv;
  return av ?? bv ?? 0;
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

// DickServiceTicket — size 0x28, fields: subject/status/replyStatus/level/updatedAt
// Default subject "未命名工单", replyStatusText logic verified.
class DickServiceTicket {
  final String subject;
  final int status;
  final int replyStatus;
  final int level;
  final String updatedAt;

  const DickServiceTicket({
    required this.subject,
    required this.status,
    required this.replyStatus,
    required this.level,
    required this.updatedAt,
  });

  factory DickServiceTicket.fromJson(Map<String, dynamic> json) {
    final subject = json['subject']?.toString() ?? '未命名工单';
    final status = _intValue(json['status']);
    final replyStatus = _intValue(json['reply_status']);
    final level = _intValue(json['level']);
    final updatedAt = _stringValue(json['updated_at']);
    return DickServiceTicket(
      subject: subject,
      status: status,
      replyStatus: replyStatus,
      level: level,
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
  final int resetPrice;
  final int planId;

  const DickServiceSubscribe({
    required this.planName,
    required this.hasActivePlan,
    required this.expiredAt,
    required this.transferEnable,
    required this.u,
    required this.d,
    this.resetDay,
    this.resetPrice = 0,
    required this.planId,
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
    final rawPrices = planMap?['prices'];
    final nestedResetTraffic = rawPrices is Map
        ? rawPrices['reset_traffic']
        : null;
    final resetPrice = _intValue(nestedResetTraffic ?? planMap?['reset_price']);

    String planName = '暂无套餐';
    if (planMap != null) {
      final n = planMap['name'];
      if (n != null && n.toString().trim().isNotEmpty) {
        planName = n.toString();
      }
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
      planId: planId,
    );
  }

  int normalizedExpiredAt() {
    // AOT 0x6865f8: no active plan returns expiredAt unchanged; an active
    // plan with a non-positive expiry is normalized to -1.
    if (hasActivePlan && expiredAt <= 0) return -1;
    return expiredAt;
  }

  DateTime expireTime() {
    final seconds = expiredAt < 0 ? 0 : expiredAt;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: false);
  }

  bool isTimeBasedExpired() {
    if (expiredAt <= 0) return false;
    return !expireTime().isAfter(DateTime.now());
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
    return transferEnable > 0 && remainingTrafficRatio() <= 0.1;
  }

  bool shouldWarnRenewal() {
    if (expiredAt <= 0) return false;
    final remaining = expireTime().difference(DateTime.now());
    if (remaining.isNegative) return false;
    return remaining.inDays <= 3;
  }

  String remainingTimeText() {
    if (!hasActivePlan) return '未开通/已过期';
    if (expiredAt <= 0) return '长期有效';
    final days = expireTime().difference(DateTime.now()).inDays;
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
    final decimals = d >= 100 || d == d.roundToDouble() ? 0 : 1;
    return '${d.toStringAsFixed(decimals)}${units[i]}';
  }

  String get formattedTotalTraffic => _formatBytes(transferEnable);
  String get formattedUsedTraffic => _formatBytes(u + d);
  String get formattedRemainingTraffic => _formatBytes(remainingTraffic());
}

class DickServiceGiftCardRedeemResult {
  final String message;
  final String templateName;
  final Map<String, dynamic> rewards;
  final Map<String, dynamic> inviteRewards;

  const DickServiceGiftCardRedeemResult({
    required this.message,
    required this.templateName,
    required this.rewards,
    required this.inviteRewards,
  });

  factory DickServiceGiftCardRedeemResult.fromJson(Map<String, dynamic> json) {
    final msg = json['message']?.toString() ?? '兑换成功';
    final tpl = _stringValue(json['template_name']);
    final rewards = json['rewards'] is Map
        ? Map<String, dynamic>.from(json['rewards'] as Map)
        : const <String, dynamic>{};
    final invite = json['invite_rewards'] is Map
        ? Map<String, dynamic>.from(json['invite_rewards'] as Map)
        : const <String, dynamic>{};
    return DickServiceGiftCardRedeemResult(
      message: msg,
      templateName: tpl,
      rewards: rewards,
      inviteRewards: invite,
    );
  }

  String get summary {
    final sections = <String>[];
    if (templateName.isNotEmpty) sections.add(templateName);
    if (rewards.isNotEmpty) sections.add(_formatRewards(rewards));
    if (inviteRewards.isNotEmpty) {
      sections.add('邀请奖励：${_formatRewards(inviteRewards)}');
    }
    return sections.isEmpty ? message : '$message：${sections.join('；')}';
  }

  static String _formatRewards(Map<String, dynamic> rewards) {
    return rewards.entries
        .where((entry) => entry.value?.toString().isNotEmpty ?? false)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('，');
  }
}

class DickServiceUserOrder {
  final String planName;
  final String tradeNo;
  final int status;
  final int totalAmount;
  final String? period;
  final String createdAt;

  const DickServiceUserOrder({
    required this.planName,
    required this.tradeNo,
    required this.status,
    required this.totalAmount,
    required this.period,
    required this.createdAt,
  });

  factory DickServiceUserOrder.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['plan'];
    final nestedPlanName = rawPlan is Map ? rawPlan['name'] : null;
    final planName = _stringValue(
      json['plan_name'] ?? json['planName'] ?? nestedPlanName,
      fallback: '未命名套餐',
    );
    final tradeNo = _stringValue(
      json['trade_no'] ?? json['tradeNo'] ?? json['id'],
    );
    final status = _intValue(json['status']);
    final totalAmount = _intValue(
      json['total_amount'] ?? json['totalAmount'] ?? json['amount'],
    );
    final period = json['period']?.toString();
    final createdAt = _stringValue(json['created_at'] ?? json['createdAt']);
    return DickServiceUserOrder(
      planName: planName,
      tradeNo: tradeNo,
      status: status,
      totalAmount: totalAmount,
      period: period,
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

  const DickServiceOrder({required this.tradeNo});

  factory DickServiceOrder.fromJson(Map<String, dynamic> json) {
    return DickServiceOrder(
      tradeNo: _stringValue(json['trade_no'] ?? json['tradeNo'] ?? json['id']),
    );
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

  const DickServicePriceOption({
    required this.id,
    required this.price,
    this.period,
  });

  String get formattedPrice => '¥${_formatCents(price)}';
}

class DickServicePlan {
  static const periodLabels = <String, String>{
    'month_price': '月付',
    'quarter_price': '季付',
    'half_year_price': '半年',
    'year_price': '年付',
    'two_year_price': '两年',
    'three_year_price': '三年',
    'onetime_price': '一次性',
  };

  final int id;
  final String name;
  final String content;
  final List<String> tags;
  final int transferEnable;
  final bool show;
  final Map<String, int> prices;

  const DickServicePlan({
    required this.id,
    required this.name,
    required this.content,
    required this.tags,
    required this.transferEnable,
    required this.show,
    required this.prices,
  });

  factory DickServicePlan.fromJson(Map<String, dynamic> json) {
    final id = _intValue(json['id']);
    final name = json['name']?.toString() ?? '未命名套餐';
    final content = _stringValue(json['content']);
    List<String> tags = const [];
    if (json['tags'] is List) {
      tags = (json['tags'] as List).map((e) => e.toString()).toList();
    }
    final prices = <String, int>{};
    for (final period in periodLabels.keys) {
      final price = _positivePlanPrice(json[period]);
      if (price > 0) {
        prices[period] = price;
      }
    }
    return DickServicePlan(
      id: id,
      name: name,
      content: content,
      tags: tags,
      transferEnable: _intValue(json['transfer_enable']),
      show: json['show'] != false,
      prices: prices,
    );
  }

  List<DickServicePriceOption> get priceOptions => prices.entries
      .map(
        (entry) => DickServicePriceOption(
          id: periodLabels[entry.key]!,
          price: entry.value,
          period: entry.key,
        ),
      )
      .toList(growable: false);

  String get contentPreview => content
      .replaceAll('*', '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

int _positivePlanPrice(dynamic value) {
  final parsed = value is String ? int.tryParse(value) ?? 0 : _intValue(value);
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
