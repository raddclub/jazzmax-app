import '../db/local_db.dart';

/// Enforces per-subscription daily download limits.
///
/// Limits by plan (matching Section 11 in JAZZMAX_MASTER.md):
///   free     → 0 downloads/day  (free users cannot download)
///   basic    → 5 downloads/day
///   standard → 15 downloads/day
///   premium  → unlimited
///
/// Counts are tracked locally in the downloads table (status='completed',
/// downloaded_at >= today midnight). The server enforces subscription status;
/// this is a UX gate so users get a friendly message before wasting bandwidth.
class DownloadQuotaService {
  static const Map<String, int> _planLimits = {
    'free': 0,
    'basic': 5,
    'standard': 15,
    'premium': -1, // -1 = unlimited
  };

  /// Returns [QuotaResult] — whether the user can start a new download.
  /// [planId] should be the plan from /api/subscription/status (e.g. "basic").
  static Future<QuotaResult> checkQuota(String planId) async {
    final limit = _planLimits[planId.toLowerCase()] ?? 0;

    // Unlimited plan — always allow
    if (limit == -1) {
      return QuotaResult(allowed: true, used: 0, limit: -1, planId: planId);
    }

    // Free plan — never allow downloads
    if (limit == 0) {
      return QuotaResult(
        allowed: false,
        used: 0,
        limit: 0,
        planId: planId,
        denyReason: 'Your plan does not include downloads.\nUpgrade to Basic or higher.',
      );
    }

    final used = await LocalDb.getTodayDownloadCount();
    if (used >= limit) {
      return QuotaResult(
        allowed: false,
        used: used,
        limit: limit,
        planId: planId,
        denyReason:
            'Daily download limit reached ($used/$limit).\nYour limit resets at midnight.',
      );
    }

    return QuotaResult(allowed: true, used: used, limit: limit, planId: planId);
  }

  /// Returns a human-readable label for today's usage, e.g. "3 / 5".
  static String usageLabel(QuotaResult q) {
    if (q.limit == -1) return 'Unlimited';
    if (q.limit == 0) return 'Not available';
    return '${q.used} / ${q.limit} today';
  }
}

class QuotaResult {
  final bool allowed;
  final int used;
  final int limit; // -1 = unlimited, 0 = none
  final String planId;
  final String? denyReason;

  const QuotaResult({
    required this.allowed,
    required this.used,
    required this.limit,
    required this.planId,
    this.denyReason,
  });

  bool get isUnlimited => limit == -1;
}
