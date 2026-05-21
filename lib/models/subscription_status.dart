/// Ответ [GET .../subscription/status.php].
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.isPro,
    this.subscription,
  });

  final bool isPro;
  final ActiveSubscription? subscription;

  static SubscriptionStatus fromJson(Map<String, dynamic> json) {
    final Object? sub = json['subscription'];
    ActiveSubscription? active;
    if (sub is Map<String, dynamic>) {
      active = ActiveSubscription.fromJson(sub);
    }
    final Object? rawPro = json['is_pro'];
    final bool pro = rawPro == true ||
        rawPro == 1 ||
        rawPro == '1' ||
        rawPro == 'true';
    return SubscriptionStatus(isPro: pro, subscription: active);
  }
}

class ActiveSubscription {
  const ActiveSubscription({
    required this.id,
    required this.planCode,
    required this.planTitle,
    required this.status,
    required this.priceRub,
    this.startedAt,
    this.expiresAt,
  });

  final int id;
  final String planCode;
  final String planTitle;
  final String status;
  final double priceRub;
  final String? startedAt;
  final String? expiresAt;

  static ActiveSubscription fromJson(Map<String, dynamic> json) {
    return ActiveSubscription(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      planCode: '${json['plan_code'] ?? ''}',
      planTitle: '${json['plan_title'] ?? ''}',
      status: '${json['status'] ?? ''}',
      priceRub: double.tryParse('${json['price_rub'] ?? 0}') ?? 0,
      startedAt: json['started_at']?.toString(),
      expiresAt: json['expires_at']?.toString(),
    );
  }
}
