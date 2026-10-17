import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../domain/device.dart';

class DeviceRepository {
  DeviceRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Enregistre cet appareil auprès du backend — requis avant toute session
  /// de lecture vidéo (`POST /videos/{id}/playback-session`), qui refuse les
  /// appareils non enregistrés. Idempotent côté backend pour un device_id
  /// déjà connu.
  Future<Device> registerDevice({
    required String accessToken,
    required String deviceId,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/register'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({
        'device_id': deviceId,
        'platform': _platformLabel(),
        'device_name': _deviceName(),
      }),
    );

    if (_isSuccess(response)) {
      return Device.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  Future<List<Device>> listDevices(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/devices'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Device.fromJson)
          .toList();
    }
    return const [];
  }

  Future<void> revokeDevice(String accessToken, String deviceRowId) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/$deviceRowId'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }
  }

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

  Map<String, String> _authHeaders(String accessToken) {
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  bool _isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Réponse API invalide.');
  }

  ApiException _apiException(http.Response response) {
    return ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }
    } on FormatException {
      return 'Impossible de lire la réponse du serveur.';
    }
    return 'La requête a échoué.';
  }
}
