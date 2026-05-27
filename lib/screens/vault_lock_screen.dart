import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../core/security/vault_service.dart';
import '../providers/vault_provider.dart';

enum _Mode { chooseLength, setPin, confirmPin, unlock }

class VaultLockScreen extends ConsumerStatefulWidget {
  const VaultLockScreen({super.key});

  @override
  ConsumerState<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends ConsumerState<VaultLockScreen> {
  _Mode _mode = _Mode.unlock;
  int _pinLength = 6;
  String _pin = '';
  String _firstPin = '';
  String _errorMsg = '';
  bool _bioAvailable = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final pinSet = await VaultService.isPinSet();
    final bio = await VaultService.isBiometricAvailable();
    final len = await VaultService.getPinLength();
    if (!mounted) return;
    setState(() {
      _mode = pinSet ? _Mode.unlock : _Mode.chooseLength;
      _bioAvailable = bio;
      _pinLength = len;
      _initializing = false;
    });
    if (pinSet && bio) _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    final ok = await VaultService.authenticateBiometric();
    if (!mounted) return;
    if (ok) _onUnlockSuccess();
  }

  void _onKey(String digit) {
    if (_pin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += digit;
      _errorMsg = '';
    });
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 100), _onPinComplete);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onDeleteAll() {
    HapticFeedback.mediumImpact();
    setState(() => _pin = '');
  }

  Future<void> _onPinComplete() async {
    if (!mounted) return;
    switch (_mode) {
      case _Mode.setPin:
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _mode = _Mode.confirmPin;
        });
        break;

      case _Mode.confirmPin:
        if (_pin == _firstPin) {
          await VaultService.setPin(_pin);
          await ref.read(vaultProvider.notifier).refresh();
          ref.read(vaultProvider.notifier).unlock();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.vault);
          }
        } else {
          HapticFeedback.vibrate();
          setState(() {
            _errorMsg = 'PINs do not match — try again';
            _pin = '';
            _firstPin = '';
            _mode = _Mode.setPin;
          });
        }
        break;

      case _Mode.unlock:
        final ok = await VaultService.verifyPin(_pin);
        if (ok) {
          _onUnlockSuccess();
        } else {
          HapticFeedback.vibrate();
          setState(() {
            _errorMsg = 'Incorrect PIN';
            _pin = '';
          });
        }
        break;

      default:
        break;
    }
  }

  void _onUnlockSuccess() {
    ref.read(vaultProvider.notifier).unlock();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.vault);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }
    if (_mode == _Mode.chooseLength) return _buildChooseLength();
    return _buildPinScreen();
  }

  // ── Choose PIN length (first-time setup) ──────────────────────────────────

  Widget _buildChooseLength() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LockIcon(),
                const SizedBox(height: 24),
                const Text(
                  'Set Up Vault',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your vault PIN length',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                const SizedBox(height: 48),
                Row(
                  children: [
                    Expanded(
                      child: _PinLengthCard(
                        digits: 4,
                        subtitle: 'Quick access',
                        onTap: () => setState(() {
                          _pinLength = 4;
                          _mode = _Mode.setPin;
                        }),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _PinLengthCard(
                        digits: 6,
                        subtitle: 'More secure',
                        recommended: true,
                        onTap: () => setState(() {
                          _pinLength = 6;
                          _mode = _Mode.setPin;
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── PIN entry screen ──────────────────────────────────────────────────────

  Widget _buildPinScreen() {
    final titles = {
      _Mode.setPin: ('Create PIN', 'Enter $_pinLength-digit PIN'),
      _Mode.confirmPin: ('Confirm PIN', 'Re-enter your PIN to confirm'),
      _Mode.unlock: ('Vault', 'Enter your PIN'),
    };
    final t = titles[_mode]!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 56),
            _LockIcon(),
            const SizedBox(height: 20),
            Text(
              t.$1,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.$2,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 36),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: filled ? AppColors.primary : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            // Error
            AnimatedOpacity(
              opacity: _errorMsg.isNotEmpty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
            ),
            const Spacer(),
            // Numpad
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Column(
                children: [
                  _numRow(['1', '2', '3']),
                  const SizedBox(height: 14),
                  _numRow(['4', '5', '6']),
                  const SizedBox(height: 14),
                  _numRow(['7', '8', '9']),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Left: biometric or blank
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: _mode == _Mode.unlock && _bioAvailable
                            ? _ActionKey(
                                icon: Icons.fingerprint_rounded,
                                color: AppColors.primary,
                                onTap: _tryBiometric,
                              )
                            : const SizedBox.shrink(),
                      ),
                      _DigitKey(digit: '0', onTap: _onKey),
                      // Right: backspace
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: _ActionKey(
                          icon: Icons.backspace_outlined,
                          color: AppColors.textMuted,
                          onTap: _onDelete,
                          onLongPress: _onDeleteAll,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Row _numRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _DigitKey(digit: d, onTap: _onKey)).toList(),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _LockIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 36),
    );
  }
}

class _PinLengthCard extends StatelessWidget {
  final int digits;
  final String subtitle;
  final bool recommended;
  final VoidCallback onTap;

  const _PinLengthCard({
    required this.digits,
    required this.subtitle,
    this.recommended = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: recommended
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: recommended
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Text(
              '$digits',
              style: TextStyle(
                color: recommended ? AppColors.primary : AppColors.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'digits',
              style: TextStyle(
                color: recommended ? AppColors.primary : AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            if (recommended) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Recommended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  final String digit;
  final void Function(String) onTap;
  const _DigitKey({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(38),
        child: InkWell(
          borderRadius: BorderRadius.circular(38),
          onTap: () => onTap(digit),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _ActionKey({
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(38),
      child: InkWell(
        borderRadius: BorderRadius.circular(38),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Center(
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}
