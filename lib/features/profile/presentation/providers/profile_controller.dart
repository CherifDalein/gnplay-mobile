import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/repositories.dart';
import '../../../auth/domain/user_read.dart';
import '../../../creator/presentation/providers/creator_dashboard_provider.dart';
import 'current_user_provider.dart';

final profileControllerProvider =
    StateNotifierProvider.autoDispose<ProfileController, AsyncValue<UserRead?>>(
      (ref) => ProfileController(ref),
    );

class ProfileController extends StateNotifier<AsyncValue<UserRead?>> {
  ProfileController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> updateProfile({
    String? fullName,
    String? pageName,
    String? bio,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final user = await _ref
          .read(profileRepositoryProvider)
          .update(fullName: fullName, pageName: pageName, bio: bio);
      _refreshAccount();
      return user;
    });
    if (mounted) state = result;
    return !result.hasError;
  }

  Future<bool> uploadAvatar(File file) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<UserRead?>(() async {
      await _ref
          .read(profileRepositoryProvider)
          .uploadProfilePicture(file.path);
      _refreshAccount();
      return null;
    });
    if (mounted) state = result;
    return !result.hasError;
  }

  void _refreshAccount() {
    _ref.invalidate(currentUserProvider);
    _ref.invalidate(creatorDashboardProvider);
  }
}
