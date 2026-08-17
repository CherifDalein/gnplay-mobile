import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'creator_dashboard_provider.dart';
import 'creator_repository_provider.dart';
import 'creator_wallet_provider.dart';

final payoutControllerProvider =
    StateNotifierProvider<PayoutController, AsyncValue<void>>((ref) {
      return PayoutController(ref);
    });

class PayoutController extends StateNotifier<AsyncValue<void>> {
  PayoutController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> requestPayout({
    required int amount,
    required String operator,
    String? destinationPhone,
  }) async {
    state = const AsyncLoading();
    try {
      await _ref
          .read(creatorRepositoryProvider)
          .requestPayout(
            amount: amount,
            operator: operator,
            destinationPhone: destinationPhone,
          );
      _ref.invalidate(creatorDashboardProvider);
      _ref.invalidate(creatorWalletLedgerProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
