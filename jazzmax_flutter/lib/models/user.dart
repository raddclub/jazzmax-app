class AppUser {
  final int id;
  final String phone;
  final String? deviceId;
  final String? deviceName;
  final bool isActive;
  final bool isGuest;
  final String? createdAt;
  final String? lastLoginAt;
  final UserSubscription? subscription;

  const AppUser({
    required this.id,
    required this.phone,
    this.deviceId,
    this.deviceName,
    this.isActive = true,
    this.isGuest = false,
    this.createdAt,
    this.lastLoginAt,
    this.subscription,
  });

  factory AppUser.guest() {
    return const AppUser(id: 0, phone: 'guest', isGuest: true);
  }

  /// Used when app starts offline but user has a valid refresh token.
  /// Phone and plan are restored from locally cached SharedPreferences.
  factory AppUser.offline({required int id, required String phone, required String plan}) {
    return AppUser(
      id: id,
      phone: phone,
      isGuest: false,
      subscription: UserSubscription(
        plan: plan,
        isActive: true,
      ),
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] as Map<String, dynamic>? ?? json;
    final subData = json['subscription'] as Map<String, dynamic>?;

    return AppUser(
      id: userData['id'] as int? ?? 0,
      phone: userData['phone'] as String? ?? '',
      deviceId: userData['device_id'] as String?,
      deviceName: userData['device_name'] as String?,
      isActive: _parseBool(userData['is_active'], defaultValue: true),
      createdAt: userData['created_at']?.toString(),
      lastLoginAt: userData['last_login_at']?.toString(),
      subscription: subData != null ? UserSubscription.fromJson(subData) : null,
    );
  }

  static bool _parseBool(dynamic v, {bool defaultValue = false}) {
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is int) return v == 1;
    return defaultValue;
  }

  bool get hasActiveSubscription {
    if (subscription == null) return false;
    return subscription!.isActive;
  }

  String get planName => subscription?.plan ?? 'free';
}

class UserSubscription {
  final String plan;
  final String? expiresAt;
  final bool isActive;

  const UserSubscription({
    required this.plan,
    this.expiresAt,
    required this.isActive,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    final expiresAtRaw = json['expires_at'];
    final String? expiresAt = expiresAtRaw?.toString();
    bool active = json['is_active'] == true ||
        (json['is_active'] as int? ?? 0) == 1;

    if (active && expiresAtRaw != null) {
      try {
        // Server returns expires_at as Unix epoch seconds (int).
        // Fall back to ISO string parse for forward compatibility.
        DateTime expiry;
        final asInt = expiresAtRaw is int
            ? expiresAtRaw
            : int.tryParse(expiresAtRaw.toString());
        if (asInt != null) {
          expiry = DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
        } else {
          expiry = DateTime.parse(expiresAtRaw.toString());
        }
        active = expiry.isAfter(DateTime.now());
      } catch (_) {}
    }

    return UserSubscription(
      plan: json['plan'] as String? ?? 'free',
      expiresAt: expiresAt,
      isActive: active,
    );
  }

  String get displayName {
    switch (plan) {
      case 'basic': return 'Basic';
      case 'standard': return 'Standard';
      case 'premium': return 'Premium';
      default: return 'Free';
    }
  }
}
