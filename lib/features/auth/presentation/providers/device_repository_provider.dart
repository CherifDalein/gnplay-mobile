import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/device_repository.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository();
});
