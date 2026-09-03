import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/domain/user_read.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/presentation/providers/auth_repository_provider.dart';
import '../../../creator/presentation/providers/creator_dashboard_provider.dart';

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
    state = await AsyncValue.guard(() async {
      final accessToken = await _requireAccessToken();
      final user = await _ref
          .read(authRepositoryProvider)
          .updateProfile(
            accessToken: accessToken,
            fullName: fullName,
            pageName: pageName,
            bio: bio,
          );
      _ref.invalidate(creatorDashboardProvider);
      return user;
    });
    return !state.hasError;
  }

  Future<bool> uploadAvatar(File file) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final accessToken = await _requireAccessToken();
      await _ref
          .read(authRepositoryProvider)
          .uploadProfilePicture(accessToken: accessToken, file: file);
      _ref.invalidate(creatorDashboardProvider);
      return null;
    });
    return !state.hasError;
  }

  Future<String> _requireAccessToken() async {
    final token = _ref.read(authControllerProvider).valueOrNull;
    if (token == null) {
      throw const ApiException('Vous devez vous connecter.');
    }
    return token.accessToken;
  }
}
