import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/device.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/presentation/providers/device_repository_provider.dart';
import '../../../auth/presentation/providers/token_storage_provider.dart';
import '../../../../core/network/api_exception.dart';

final devicesProvider = FutureProvider.autoDispose<List<Device>>((ref) async {
  final repository = ref.watch(deviceRepositoryProvider);
  final accessToken = await _requireAccessToken(ref);
  return repository.listDevices(accessToken);
});

final currentDeviceIdProvider = FutureProvider.autoDispose<String>((ref) {
  return ref.watch(tokenStorageProvider).readOrCreateDeviceId();
});

final deviceRevokeControllerProvider =
    StateNotifierProvider.autoDispose<DeviceRevokeController, AsyncValue<void>>(
      (ref) => DeviceRevokeController(ref),
    );

class DeviceRevokeController extends StateNotifier<AsyncValue<void>> {
  DeviceRevokeController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> revoke(String deviceRowId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = _ref.read(deviceRepositoryProvider);
      final accessToken = await _requireAccessToken(_ref);
      await repository.revokeDevice(accessToken, deviceRowId);
      _ref.invalidate(devicesProvider);
    });
  }
}

Future<String> _requireAccessToken(Ref ref) async {
  final token = ref.read(authControllerProvider).valueOrNull;
  if (token == null) {
    throw const ApiException('Vous devez vous connecter.');
  }
  return token.accessToken;
}
