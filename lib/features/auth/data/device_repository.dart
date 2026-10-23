import 'dart:io' show Platform;

import '../../../core/network/api_client.dart';
import '../domain/device.dart';

/// Appareils autorisés à lire des vidéos. Le backend garde au plus 3
/// appareils actifs : enregistrer un nouvel appareil désactive le plus ancien.
class DeviceRepository {
  DeviceRepository(this._api);

  final ApiClient _api;

  /// Enregistre (ou réactive) cet appareil — requis avant toute session de
  /// lecture. Idempotent pour un `device_id` déjà connu.
  Future<Device> registerDevice({required String deviceId}) async {
    final json = await _api.post(
      '/api/v1/devices/register',
      json: {
        'device_id': deviceId,
        'platform': _platformLabel(),
        'device_name': _deviceName(),
      },
    );
    return Device.fromJson(json.asObject);
  }

  Future<List<Device>> listDevices() async {
    final json = await _api.get('/api/v1/devices');
    return json.asObjectList.map(Device.fromJson).toList();
  }

  Future<void> revokeDevice(String deviceId) =>
      _api.delete('/api/v1/devices/$deviceId');

  String? _platformLabel() {
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
      if (Platform.isMacOS) return 'macOS';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isLinux) return 'Linux';
    } catch (_) {
      // Platform indisponible (web) : laisse le backend sans valeur.
    }
    return null;
  }

  String? _deviceName() {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return null;
    }
  }
}
