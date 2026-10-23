import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/repositories.dart';
import '../../../auth/domain/device.dart';
import '../../../auth/presentation/providers/token_storage_provider.dart';

final devicesProvider = FutureProvider.autoDispose<List<Device>>((ref) {
  return ref.watch(deviceRepositoryProvider).listDevices();
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
    final result = await AsyncValue.guard(() async {
      await _ref.read(deviceRepositoryProvider).revokeDevice(deviceRowId);
      _ref.invalidate(devicesProvider);
    });
    if (mounted) state = result;
  }
}
