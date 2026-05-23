class SubscriptionPlan {
  final String id;
  final String name;
  final int priceMonthly; // PKR
  final String description;
  final int downloadsPerDay;
  final bool hdAccess;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.description,
    required this.downloadsPerDay,
    required this.hdAccess,
    required this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final featuresRaw = json['features'] as List<dynamic>? ?? [];
    return SubscriptionPlan(
      id: json['id'] as String? ?? json['plan_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceMonthly: json['price'] as int? ?? json['price_monthly'] as int? ?? 0,
      description: json['description'] as String? ?? '',
      downloadsPerDay: json['downloads_per_day'] as int? ?? 0,
      // Server may return bool or int — handle both
      hdAccess: json['hd_access'] == true || json['hd_access'] == 1,
      features: featuresRaw.cast<String>(),
    );
  }

  String get displayPrice =>
      priceMonthly == 0 ? 'Free' : 'PKR $priceMonthly/month';
}

class SubscriptionStatus {
  final String plan;
  final bool isActive;
  final String? expiresAt;
  final int downloadsUsedToday;
  final int downloadsLimit;

  const SubscriptionStatus({
    required this.plan,
    required this.isActive,
    this.expiresAt,
    this.downloadsUsedToday = 0,
    this.downloadsLimit = 0,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'] as Map<String, dynamic>? ?? json;
    return SubscriptionStatus(
      plan: sub['plan'] as String? ?? 'free',
      // Server returns Python bool (true/false) — handle both bool and int
      isActive: sub['is_active'] == true || sub['is_active'] == 1,
      expiresAt: sub['expires_at'] as String?,
      downloadsUsedToday: sub['downloads_used_today'] as int? ?? 0,
      downloadsLimit: sub['downloads_limit'] as int? ?? 1,
    );
  }
}
