import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../domain/register_request.dart';
import '../../domain/user_read.dart';
import '../../../../core/network/repositories.dart';

final registerControllerProvider =
    StateNotifierProvider<RegisterController, AsyncValue<UserRead?>>((ref) {
      return RegisterController(ref.watch(authRepositoryProvider));
    });

class RegisterController extends StateNotifier<AsyncValue<UserRead?>> {
  RegisterController(this._repository) : super(const AsyncData(null));

  final AuthRepository _repository;

  Future<bool> requestOtp({required String phoneNumber}) async {
    state = const AsyncLoading();
    try {
      await _repository.requestRegisterOtp(phoneNumber: phoneNumber);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.verifyRegisterOtp(phoneNumber: phoneNumber, code: code);
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<UserRead?> register(RegisterRequest request) async {
    state = const AsyncLoading();
    try {
      final user = await _repository.register(request);
      state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }
}
