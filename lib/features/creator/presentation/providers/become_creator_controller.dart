import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/repositories.dart';
import '../../../auth/domain/user_read.dart';
import '../../../profile/presentation/providers/current_user_provider.dart';
import 'creator_dashboard_provider.dart';

final becomeCreatorControllerProvider =
    StateNotifierProvider<BecomeCreatorController, AsyncValue<UserRead?>>(
      (ref) => BecomeCreatorController(ref),
    );

class BecomeCreatorController extends StateNotifier<AsyncValue<UserRead?>> {
  BecomeCreatorController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<UserRead?> becomeCreator() async {
    state = const AsyncLoading();
    try {
      final user = await _ref.read(profileRepositoryProvider).becomeCreator();
      _ref.invalidate(currentUserProvider);
      _ref.invalidate(creatorDashboardProvider);
      if (mounted) state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      if (mounted) state = AsyncError(error, stackTrace);
      return null;
    }
  }
}
