import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../models/subscription.dart';
import '../widgets/loading_overlay.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  String? _selectedPlan;
  bool _showTidForm = false;
  final _tidCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _paymentMethod = 'jazzcash';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).loadPlans();
      ref.read(subscriptionProvider.notifier).loadStatus();
    });
    // Pre-fill phone from logged-in user
    final user = ref.read(authProvider).user;
    if (user != null) _phoneCtrl.text = user.phone;
  }

  @override
  void dispose() {
    _tidCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);

    return LoadingOverlay(
      loading: sub.loading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Subscription'),
          backgroundColor: AppColors.background,
        ),
        body: sub.loading && sub.plans.isEmpty
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Current plan banner ──────────────────────────────
                  if (sub.status != null)
                    _CurrentPlanBanner(status: sub.status!),
                  const SizedBox(height: 20),

                  // ── Plans ────────────────────────────────────────────
                  const Text(
                    'Choose a Plan',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...sub.plans.map(
                    (plan) => _PlanCard(
                      plan: plan,
                      isSelected: _selectedPlan == plan.id,
                      onTap: () => setState(() {
                        _selectedPlan = plan.id;
                        _showTidForm = false;
                      }),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (_selectedPlan != null && _selectedPlan != 'free') ...[
                    // ── Payment Instructions ──────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How to Pay',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _PayStep(
                            step: '1',
                            text:
                                'Send payment via JazzCash or Easypaisa to:',
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '03286839827',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      'Muhammad Rehan',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.copy_outlined,
                                    color: AppColors.textMuted, size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _PayStep(
                            step: '2',
                            text:
                                'Note the Transaction ID (TID) from your payment receipt',
                          ),
                          const SizedBox(height: 10),
                          const _PayStep(
                            step: '3',
                            text: 'Enter the TID below — we verify within minutes',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          setState(() => _showTidForm = !_showTidForm),
                      child: Text(
                        _showTidForm ? 'Hide TID Form' : 'I have paid — Enter TID',
                      ),
                    ),
                  ],

                  // ── TID Form ─────────────────────────────────────────
                  if (_showTidForm) ...[
                    const SizedBox(height: 16),
                    _TidForm(
                      tidCtrl: _tidCtrl,
                      phoneCtrl: _phoneCtrl,
                      paymentMethod: _paymentMethod,
                      onPaymentMethodChanged: (v) =>
                          setState(() => _paymentMethod = v),
                      onSubmit: () async {
                        final ok = await ref
                            .read(subscriptionProvider.notifier)
                            .submitTid(
                              phone: _phoneCtrl.text.trim(),
                              tid: _tidCtrl.text.trim(),
                              plan: _selectedPlan!,
                              paymentMethod: _paymentMethod,
                            );
                        if (ok && context.mounted) {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              title: const Text('TID Submitted',
                                  style:
                                      TextStyle(color: AppColors.textPrimary)),
                              content: const Text(
                                'Your payment is being verified.\nSubscription will be activated within minutes.',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],

                  if (sub.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      sub.error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}

class _CurrentPlanBanner extends StatelessWidget {
  final dynamic status;
  const _CurrentPlanBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'Current plan: ${status.plan.toUpperCase()}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: plan.id,
              groupValue: isSelected ? plan.id : null,
              onChanged: (_) => onTap(),
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    plan.description,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              plan.displayPrice,
              style: TextStyle(
                color: plan.priceMonthly == 0
                    ? AppColors.success
                    : AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayStep extends StatelessWidget {
  final String step;
  final String text;
  const _PayStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppColors.primary,
          child: Text(step,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
        ),
      ],
    );
  }
}

class _TidForm extends StatelessWidget {
  final TextEditingController tidCtrl;
  final TextEditingController phoneCtrl;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onSubmit;

  const _TidForm({
    required this.tidCtrl,
    required this.phoneCtrl,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Submit Your TID',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Your Phone Number',
            prefixIcon:
                Icon(Icons.phone_outlined, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: tidCtrl,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Transaction ID (TID)',
            hintText: 'e.g. TXN123456789',
            prefixIcon: Icon(Icons.receipt_outlined, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PayMethodChip(
              label: 'JazzCash',
              selected: paymentMethod == 'jazzcash',
              onTap: () => onPaymentMethodChanged('jazzcash'),
            ),
            const SizedBox(width: 8),
            _PayMethodChip(
              label: 'Easypaisa',
              selected: paymentMethod == 'easypaisa',
              onTap: () => onPaymentMethodChanged('easypaisa'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onSubmit,
          child: const Text('Submit TID for Verification'),
        ),
      ],
    );
  }
}

class _PayMethodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PayMethodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
