import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/user_read.dart';
import '../../../auth/presentation/providers/auth_repository_provider.dart';
import '../../../auth/presentation/providers/token_storage_provider.dart';
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
      final token = await _ref.read(tokenStorageProvider).read();
      if (token == null) {
        throw Exception('Vous devez vous connecter.');
      }
      final user = await _ref
          .read(authRepositoryProvider)
          .becomeCreator(accessToken: token.accessToken);
      _ref.invalidate(creatorDashboardProvider);
      state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }
}
