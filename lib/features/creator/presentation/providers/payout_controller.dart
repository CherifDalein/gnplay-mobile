import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/repositories.dart';
import '../../domain/payout_request.dart';
import 'creator_dashboard_provider.dart';
import 'creator_wallet_provider.dart';
import 'payout_providers.dart';

final payoutControllerProvider =
    StateNotifierProvider<PayoutController, AsyncValue<PayoutRequestRecord?>>((
      ref,
    ) {
      return PayoutController(ref);
    });

class PayoutController extends StateNotifier<AsyncValue<PayoutRequestRecord?>> {
  PayoutController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<PayoutRequestRecord?> requestPayout({
    required int amount,
    required String operator,
    String? destinationPhone,
  }) async {
    state = const AsyncLoading();
    try {
      final record = await _ref
          .read(payoutRepositoryProvider)
          .request(
            amount: amount,
            operator: operator,
            destinationPhone: destinationPhone,
          );
      _ref.invalidate(creatorDashboardProvider);
      _ref.invalidate(creatorWalletLedgerProvider);
      _ref.invalidate(payoutsProvider);
      state = AsyncData(record);
      return record;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }
}
