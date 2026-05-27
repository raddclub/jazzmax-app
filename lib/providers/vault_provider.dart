import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/security/vault_service.dart';

class VaultState {
  final bool isUnlocked;
  final bool isPinSet;

  const VaultState({
    required this.isUnlocked,
    required this.isPinSet,
  });

  VaultState copyWith({bool? isUnlocked, bool? isPinSet}) => VaultState(
        isUnlocked: isUnlocked ?? this.isUnlocked,
        isPinSet: isPinSet ?? this.isPinSet,
      );
}

/// Manages vault session lock state.
/// Locks automatically when the app goes to background.
class VaultNotifier extends StateNotifier<VaultState>
    with WidgetsBindingObserver {
  VaultNotifier()
      : super(const VaultState(isUnlocked: false, isPinSet: false)) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final set = await VaultService.isPinSet();
    if (mounted) state = state.copyWith(isPinSet: set);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Lock vault whenever app goes background or is killed
    if (s == AppLifecycleState.paused || s == AppLifecycleState.detached) {
      if (state.isUnlocked) {
        state = state.copyWith(isUnlocked: false);
      }
    }
  }

  void unlock() => state = state.copyWith(isUnlocked: true);

  void lock() => state = state.copyWith(isUnlocked: false);

  Future<void> refresh() async {
    final set = await VaultService.isPinSet();
    if (mounted) state = state.copyWith(isPinSet: set);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final vaultProvider =
    StateNotifierProvider<VaultNotifier, VaultState>((ref) => VaultNotifier());
