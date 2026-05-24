import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/subscription_provider.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/jazz_text_field.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final _tidCtrl = TextEditingController();
  bool _submitting = false;
  String? _tidError;
  String? _tidSuccess;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).load();
    });
  }

  @override
  void dispose() { _tidCtrl.dispose(); super.dispose(); }

  Future<void> _submitTid() async {
    final tid = _tidCtrl.text.trim();
    if (tid.length < 6) {
      setState(() => _tidError = 'Enter a valid Transaction ID');
      return;
    }
    setState(() { _submitting = true; _tidError = null; _tidSuccess = null; });
    try {
      final msg = await ref.read(subscriptionProvider.notifier).submitTid(tid);
      setState(() { _tidSuccess = msg; _submitting = false; _tidCtrl.clear(); });
    } catch (e) {
      setState(() {
        _tidError = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);
    return LoadingOverlay(
      loading: _submitting,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Subscription', style: TextStyle(fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: state.loading
            ? const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary), strokeCap: StrokeCap.round))
            : _buildBody(state),
      ),
    );
  }

  Widget _buildBody(SubscriptionState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Active subscription status
        if (state.activeSubscription != null) _buildActiveCard(state.activeSubscription!),

        // Plans
        const Text('Choose a Plan', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3))
            .animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 6),
        const Text('Zero-rated streaming on Jazz network · Premium quality · All content',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13))
            .animate(delay: 80.ms).fadeIn(duration: 300.ms),
        const SizedBox(height: 20),

        if (state.plans.isEmpty)
          _buildPlansShimmer()
        else
          ...state.plans.asMap().entries.map((e) => _PlanCard(
            plan: e.value,
            isPopular: e.key == 1,
            isSelected: state.selectedPlanId == e.value.id,
            onSelect: () => ref.read(subscriptionProvider.notifier).selectPlan(e.value.id),
          ).animate(delay: (e.key * 80).ms).fadeIn(duration: 350.ms)
              .slideY(begin: 0.2, end: 0, duration: 350.ms, curve: AppCurves.standard)),

        const SizedBox(height: 24),

        // Payment methods
        if (state.selectedPlanId != null) ...[
          const Text('Pay With', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3))
              .animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 14),
          ...state.methods.where((m) => m.enabled).map((m) =>
              _PaymentMethodCard(method: m)
                  .animate().fadeIn(duration: 300.ms)
                  .slideY(begin: 0.15, end: 0, duration: 300.ms, curve: AppCurves.standard)),
          const SizedBox(height: 20),

          // TID submission
          const Text('Enter Transaction ID', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('After sending payment, paste the Transaction ID here for verification.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
          const SizedBox(height: 14),
          JazzTextField(
            controller: _tidCtrl,
            label: 'Transaction ID',
            hint: 'e.g. JAZ123456789',
            keyboardType: TextInputType.text,
            prefixIcon: Icons.receipt_long_outlined,
          ).animate().fadeIn(duration: 300.ms),
          if (_tidError != null) ...[
            const SizedBox(height: 8),
            Text(_tidError!, style: const TextStyle(color: AppColors.error, fontSize: 12))
                .animate().fadeIn(duration: 200.ms).shakeX(hz: 3, amount: 4),
          ],
          if (_tidSuccess != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.success.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_tidSuccess!, style: const TextStyle(
                    color: AppColors.success, fontSize: 12))),
              ]),
            ).animate().fadeIn(duration: 300.ms),
          ],
          const SizedBox(height: 14),
          Container(
            height: 52,
            decoration: BoxDecoration(gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.md), boxShadow: AppShadows.primary),
            child: Material(color: Colors.transparent,
              child: InkWell(borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: _submitting ? null : _submitTid,
                child: const Center(child: Text('Submit Transaction',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))))),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 32),
        ],

        // Feature comparison table
        const _FeatureTable(),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _buildActiveCard(ActiveSubscription sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.success.withOpacity(0.15), AppColors.success.withOpacity(0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success.withOpacity(0.15)),
          child: const Center(child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Active: ${sub.planName}', style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          if (sub.expiresAt != null)
            Text('Expires ${sub.expiresAt}', style: const TextStyle(
                color: AppColors.textMuted, fontSize: 12)),
        ])),
      ]),
    ).animate().fadeIn(duration: 400.ms)
        .slideY(begin: -0.2, end: 0, duration: 400.ms, curve: AppCurves.standard);
  }

  Widget _buildPlansShimmer() {
    return Column(children: List.generate(3, (_) => Container(
      height: 110, margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md)),
    )));
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isPopular, isSelected;
  final VoidCallback onSelect;
  const _PlanCard({required this.plan, required this.isPopular,
      required this.isSelected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.glassBorder,
              width: isSelected ? 1.5 : 0.5),
          boxShadow: isSelected ? AppShadows.primary : null,
        ),
        child: Row(children: [
          // Radio
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? AppColors.primary : Colors.transparent,
              border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.textMuted, width: 2)),
            child: isSelected ? const Center(
                child: Icon(Icons.check_rounded, size: 12, color: Colors.white)) : null,
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(plan.name, style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 16, fontWeight: FontWeight.w700)),
              if (isPopular) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4)),
                  child: const Text('POPULAR', style: TextStyle(
                      color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(plan.features.join(' · '), style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11), maxLines: 2),
          ])),
          // Price
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Rs. ${plan.priceStr}', style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 17, fontWeight: FontWeight.w800)),
            Text('/${plan.period}', style: const TextStyle(
                color: AppColors.textMuted, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }
}

// ── Payment Method Card ────────────────────────────────────────────────────────
class _PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  const _PaymentMethodCard({required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(method.name, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (method.accountNumber != null)
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(method.accountNumber!, style: const TextStyle(
                    color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: method.accountNumber!));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)));
                  },
                  child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                ),
              ]),
            ),
          ]),
        if (method.instructions != null) ...[
          const SizedBox(height: 8),
          Text(method.instructions!, style: const TextStyle(
              color: AppColors.textMuted, fontSize: 12, height: 1.5)),
        ],
      ]),
    );
  }
}

// ── Feature Table ─────────────────────────────────────────────────────────────
class _FeatureTable extends StatelessWidget {
  const _FeatureTable();

  static const _rows = [
    ('Zero-data streaming',   true, true, true),
    ('Offline catalog',       true, true, true),
    ('HD 720p quality',       false, true, true),
    ('Full HD 1080p',         false, false, true),
    ('All content',           false, true, true),
    ('Free content',          true, true, true),
    ('Multiple devices',      false, false, true),
  ];
  static const _heads = ['Basic', 'Standard', 'Premium'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.glassBorder)),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            const Expanded(flex: 3, child: Padding(
              padding: EdgeInsets.only(left: 16),
              child: Text('Feature', style: TextStyle(color: AppColors.textMuted,
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)))),
            ...List.generate(3, (i) => Expanded(
              child: Center(child: Text(_heads[i], style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700))),
            )),
          ]),
        ),
        const Divider(height: 1),
        ..._rows.asMap().entries.map((e) {
          final row = e.value;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Expanded(flex: 3, child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(row.$1, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)))),
                _cell(row.$2), _cell(row.$3), _cell(row.$4),
              ]),
            ),
            if (e.key < _rows.length - 1) const Divider(height: 1, indent: 16),
          ]);
        }),
      ]),
    );
  }

  Widget _cell(bool yes) => Expanded(child: Center(child: Icon(
    yes ? Icons.check_circle_rounded : Icons.remove_rounded,
    size: 18,
    color: yes ? AppColors.success : AppColors.textDisabled)));
}
