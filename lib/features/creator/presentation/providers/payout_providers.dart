import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/repositories.dart';
import '../../domain/payout_provider.dart';
import '../../domain/payout_request.dart';

final payoutProviderOptionsProvider =
    FutureProvider.autoDispose<List<PayoutProviderOption>>((ref) {
      return ref.watch(payoutRepositoryProvider).listProviders();
    });

final payoutsProvider = FutureProvider.autoDispose<List<PayoutRequestRecord>>((
  ref,
) {
  return ref.watch(payoutRepositoryProvider).list();
});

final payoutDetailProvider = FutureProvider.autoDispose
    .family<PayoutRequestRecord, String>((ref, payoutId) {
      return ref.watch(payoutRepositoryProvider).get(payoutId);
    });
