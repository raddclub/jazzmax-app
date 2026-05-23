import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    final name = await DeviceIdentifier.getDeviceName();
    if (mounted) setState(() => _deviceName = name);
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
                    radius: 44,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      user?.phone.isNotEmpty == true
                          ? user!.phone[0].toUpperCase()
                          : 'G',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.phone ?? 'Guest',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (user?.planName ?? 'free').toUpperCase(),
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
                _ActionRow(
                  icon: Icons.star_outline,
                  label: user?.planName == 'free' || user == null
                      ? 'Subscribe to Unlock All'
                      : 'Upgrade Plan',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.subscription),
                  iconColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── My Content ────────────────────────────────────────────
            _Section(
              title: 'My Content',
              children: [
                _ActionRow(
                  icon: Icons.bookmark_outlined,
                  label: 'My Watchlist',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.watchlist),
                ),
                const Divider(color: AppColors.divider, height: 1),
                _ActionRow(
                  icon: Icons.history_rounded,
                  label: 'Watch History',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.history),
                ),
                const Divider(color: AppColors.divider, height: 1),
                _ActionRow(
                  icon: Icons.download_outlined,
                  label: 'Downloads',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.downloads),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Payment ───────────────────────────────────────────────
            _Section(
              title: 'Payment',
              children: [
                _ActionRow(
                  icon: Icons.receipt_outlined,
                  label: 'Check Payment Status (TID)',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.subscription),
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

            // ── Account ───────────────────────────────────────────────
            _Section(
              title: 'Account',
              children: [
                if (user == null) ...[
                  _ActionRow(
                    icon: Icons.login_rounded,
                    label: 'Sign In',
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.login),
                    iconColor: AppColors.primary,
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _ActionRow(
                    icon: Icons.person_add_outlined,
                    label: 'Create Account',
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.register),
                  ),
                ] else
                  _ActionRow(
                    icon: Icons.logout,
                    label: 'Sign Out',
                    onTap: _loggingOut ? null : _logout,
                    iconColor: AppColors.error,
                    labelColor: AppColors.error,
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // ── App info ──────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                      children: [
                        TextSpan(
                          text: 'Jazz',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        TextSpan(
                          text: 'MAX',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'v1.0.0 — Pakistan ka entertainment, data-free',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
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
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
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
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon,
          color: iconColor ?? AppColors.textMuted, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor ?? AppColors.textPrimary,
          fontSize: 14,
        ),
      ),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textMuted, size: 20),
      onTap: onTap,
    );
  }
}
