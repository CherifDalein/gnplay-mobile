import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/http_client_provider.dart';
import '../../data/device_repository.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(client: ref.watch(authenticatedClientProvider));
});
