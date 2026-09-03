import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import 'auth_repository_provider.dart';

final forgotPasswordControllerProvider =
    StateNotifierProvider.autoDispose<ForgotPasswordController, AsyncValue<void>>(
      (ref) => ForgotPasswordController(ref.watch(authRepositoryProvider)),
    );

class ForgotPasswordController extends StateNotifier<AsyncValue<void>> {
  ForgotPasswordController(this._repository) : super(const AsyncData(null));

  final AuthRepository _repository;

  Future<bool> requestCode({required String phoneNumber}) async {
    state = const AsyncLoading();
    try {
      await _repository.requestPasswordReset(phoneNumber: phoneNumber);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> confirm({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.resetPassword(
        phoneNumber: phoneNumber,
        code: code,
        newPassword: newPassword,
      );
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
