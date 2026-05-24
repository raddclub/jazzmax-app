import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/constants.dart';
import '../core/security/device_id.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_overlay.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loggingOut = false;
  String? _deviceName;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _loadVersion();
  }

  Future<void> _loadDeviceInfo() async {
    final name = await DeviceIdentifier.getDeviceName();
    if (mounted) setState(() => _deviceName = name);
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'v${info.version} (build ${info.buildNumber})');
      }
    } catch (_) {
      if (mounted) setState(() => _appVersion = 'v1.1.0');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign Out',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loggingOut = true);
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return LoadingOverlay(
      loading: _loggingOut,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: AppColors.background,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Avatar + name ─────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      user?.phone.isNotEmpty == true
                          ? user!.phone[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.phone ?? '—',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user?.planName.toUpperCase() ?? 'FREE',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Subscription info ─────────────────────────────────────
            _Section(
              title: 'Subscription',
              children: [
                _InfoRow(
                  label: 'Plan',
                  value: user?.subscription?.displayName ?? 'Free',
                ),
                if (user?.subscription?.expiresAt != null)
                  _InfoRow(
                    label: 'Expires',
                    value: _formatDate(user!.subscription!.expiresAt!),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Device info ───────────────────────────────────────────
            _Section(
              title: 'Device',
              children: [
                _InfoRow(
                  label: 'Device',
                  value: _deviceName ?? '...',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Actions ───────────────────────────────────────────────
            _Section(
              title: 'Account',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star_outline,
                      color: AppColors.primary),
                  title: const Text('Upgrade Plan',
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textMuted),
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.subscription),
                ),
                const Divider(color: AppColors.divider, height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: const Text('Sign Out',
                      style: TextStyle(color: AppColors.error)),
                  onTap: _loggingOut ? null : _logout,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── App info — real version from package, server URL ──────
            _Section(
              title: 'App Info',
              children: [
                _InfoRow(label: 'Version', value: _appVersion.isEmpty ? '...' : _appVersion),
                _InfoRow(label: 'Server', value: AppConstants.apiBaseUrl),
              ],
            ),
            const SizedBox(height: 24),

            Center(
              child: Text(
                'JazzMAX — Pakistan ka entertainment, data-free',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      // Server returns expires_at as Unix epoch seconds (int string).
      // Fall back to ISO string parse for forward compatibility.
      final asInt = int.tryParse(isoDate);
      final dt = asInt != null
          ? DateTime.fromMillisecondsSinceEpoch(asInt * 1000)
          : DateTime.parse(isoDate);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
