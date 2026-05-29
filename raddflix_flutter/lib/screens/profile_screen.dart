import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../services/vault_service.dart';
import '../core/security/device_id.dart';
import '../core/theme/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../core/api/subscription_api.dart';
import '../widgets/loading_overlay.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loggingOut = false;
  String? _deviceName;
  bool _hasInternet = true;
  String _appVersion = 'v1.0.0';
  int? _daysLeft;
  bool _subExpiring = false;
  late final _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChange);

  @override
  void initState() {
    super.initState();
    DeviceIdentifier.getDeviceName().then((n) {
      if (mounted) setState(() => _deviceName = n);
    });
    _checkConnectivity();
    _connectivitySub; // activate listener
    _loadExtras();
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _hasInternet = result != ConnectivityResult.none);
  }

  void _onConnectivityChange(List<ConnectivityResult> results) {
    if (mounted) setState(() => _hasInternet = results.isNotEmpty && results.first != ConnectivityResult.none);
  }

  Future<void> _loadExtras() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = 'v\${info.version}');
    } catch (_) {}
    try {
      final status = await SubscriptionApi.getStatus();
      if (!mounted) return;
      final expiresAt = status.expiresAt;
      if (expiresAt != null && status.isActive) {
        final dt = DateTime.tryParse(expiresAt);
        if (dt != null) {
          final diff = dt.difference(DateTime.now()).inDays;
          if (mounted) setState(() {
            _daysLeft = diff > 0 ? diff : 0;
            _subExpiring = diff <= 7;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Sign Out'),
      content: const Text('Are you sure you want to sign out?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error))),
      ],
    ));
    if (ok != true) return;
    setState(() => _loggingOut = true);
    await ref.read(authProvider.notifier).logout();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user  = ref.watch(authProvider).user;
    final theme = ref.watch(themeProvider);
    final initial = user?.phone.isNotEmpty == true ? user!.phone[0].toUpperCase() : 'U';

    return LoadingOverlay(
      loading: _loggingOut,
      child: Scaffold(
        backgroundColor: null,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(children: [
                    const Text('Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary, letterSpacing: -0.5)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted)),
                  ]),
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

            // Avatar & plan
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(children: [
                  // Avatar
                  Container(
                    width: 86, height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: AppShadows.glow,
                    ),
                    child: Center(child: Text(initial, style: const TextStyle(
                        color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900))),
                  ).animate().scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1),
                      duration: 400.ms, curve: AppCurves.enter),
                  const SizedBox(height: 14),
                  Text(user?.phone ?? '—', style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700,
                      letterSpacing: -0.3))
                      .animate(delay: 100.ms).fadeIn(duration: 300.ms),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.round),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      (user?.planName ?? 'FREE').toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontSize: 11,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
                ]),
              ),
            ),

            // Subscription card
            if (user?.subscription != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.star_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Active Subscription', style: TextStyle(
                            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                        if (user!.subscription!.expiresAt != null)
                          Text('Expires ${_fmt(user.subscription!.expiresAt!)}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        if (_daysLeft != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _subExpiring
                                ? '⚠ ${_daysLeft}d remaining — renew soon'
                                : '${_daysLeft}d remaining',
                            style: TextStyle(
                              color: _subExpiring
                                  ? const Color(0xFFFFB300)
                                  : const Color(0xFF00C853),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ])),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.subscription),
                        child: const Text('Manage', style: TextStyle(fontSize: 12))),
                    ]),
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 350.ms)
                    .slideY(begin: 0.2, end: 0, duration: 350.ms, curve: AppCurves.standard),
              ),

            // Sections
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  // Appearance
                  _Section(title: 'Appearance', children: [
                    _SectionTile(
                      icon: Icons.palette_outlined,
                      label: 'Theme',
                      trailing: Text(ref.watch(themeProvider.notifier).displayName,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      onTap: () => _showThemePicker(context),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Device
                  _Section(title: 'Device', children: [
                    _SectionTile(
                      icon: Icons.smartphone_rounded,
                      label: 'Device',
                      trailing: Text(_deviceName ?? '…',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Account
                  _Section(title: 'Account', children: [
                    _SectionTile(
                      icon: Icons.workspace_premium_outlined,
                      iconColor: AppColors.primary,
                      label: 'Upgrade Plan',
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.subscription),
                    ),
                    _divider(),
                    _SectionTile(
                      icon: Icons.lock_rounded,
                      iconColor: const Color(0xFF7C5CFF),
                      label: 'Private Vault',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x207C5CFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PRIVATE', style: TextStyle(
                            color: Color(0xFF7C5CFF), fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                      onTap: () async {
                        final hasPin = await VaultService.hasPin();
                        if (!context.mounted) return;
                        if (hasPin) {
                          if (VaultService.isUnlocked) {
                            Navigator.of(context).pushNamed(AppRoutes.vault);
                          } else {
                            Navigator.of(context).pushNamed(AppRoutes.vaultLock);
                          }
                        } else {
                          Navigator.of(context).pushNamed(AppRoutes.vaultLock,
                              arguments: {'setup': true});
                        }
                      },
                    ),
                    _divider(),
                    _SectionTile(
                      icon: Icons.download_outlined,
                      label: 'Downloads',
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.downloads),
                    ),
                    if (user?.isGuest != true && _hasInternet) ...[
                      _divider(),
                      _SectionTile(
                        icon: Icons.cloud_download_outlined,
                        iconColor: const Color(0xFF3B82F6),
                        label: 'Server Downloads',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x223B82F6),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('ADMIN', style: TextStyle(
                              color: Color(0xFF3B82F6), fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.adminQueue),
                      ),
                    ],
                    _divider(),
                    _SectionTile(
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.error,
                      label: 'Sign Out',
                      labelColor: AppColors.error,
                      onTap: _loggingOut ? null : _logout,
                    ),
                  ]),
                  const SizedBox(height: 32),
                  Text('$_appVersion · Pakistan ka entertainment, data-free',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 40),
                ]),
              ).animate(delay: 250.ms).fadeIn(duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 52);

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(context: context, builder: (_) => _ThemePicker());
  }

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return iso; }
  }
}

class _ThemePicker extends ConsumerWidget {
  static const _options = [
    (JazzTheme.dark,   '🌙', 'Dark',   'Deep dark background'),
    (JazzTheme.amoled, '⬛', 'AMOLED', 'Pure black for OLED screens'),
    (JazzTheme.light,  '☀️', 'Light',  'Light background'),
    (JazzTheme.auto,   '🔄', 'Auto',   'Follows time of day'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider).mode;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
        const Text('Choose Theme', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        ..._options.map((opt) => _ThemeOption(
          icon: opt.$2, title: opt.$3, subtitle: opt.$4,
          isSelected: current == opt.$1,
          onTap: () {
            ref.read(themeProvider.notifier).setTheme(opt.$1);
            Navigator.pop(context);
          },
        )),
      ]),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String icon, title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  const _ThemeOption({required this.icon, required this.title, required this.subtitle,
      required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.glassBorder)),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 15)),
            Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ])),
          if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(), style: const TextStyle(
            color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1))),
      Container(
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.glassBorder)),
        child: Column(children: children),
      ),
    ]);
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SectionTile({required this.icon, this.iconColor, required this.label,
      this.labelColor, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(width: 36, height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: (iconColor ?? AppColors.textMuted).withOpacity(0.12)),
        child: Icon(icon, size: 18, color: iconColor ?? AppColors.textMuted)),
      title: Text(label, style: TextStyle(
          color: labelColor ?? AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: trailing ?? (onTap != null
          ? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20)
          : null),
      onTap: onTap,
    );
  }
}
