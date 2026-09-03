import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/payout_provider.dart';
import '../../domain/payout_request.dart';
import 'creator_repository_provider.dart';

final payoutProviderOptionsProvider =
    FutureProvider.autoDispose<List<PayoutProviderOption>>((ref) async {
      return ref.watch(creatorRepositoryProvider).listPayoutProviders();
    });

final payoutsProvider = FutureProvider.autoDispose<List<PayoutRequestRecord>>((
  ref,
) async {
  return ref.watch(creatorRepositoryProvider).listPayouts();
});

final payoutDetailProvider = FutureProvider.autoDispose
    .family<PayoutRequestRecord, String>((ref, payoutId) {
      return ref.watch(creatorRepositoryProvider).getPayout(payoutId);
    });
