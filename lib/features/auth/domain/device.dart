import '../../../shared/utils/json_helpers.dart';

class Device {
  const Device({
    required this.id,
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.isActive,
    this.lastSeenAt,
  });

  final String id;
  final String deviceId;
  final String? platform;
  final String? deviceName;
  final bool isActive;
  final DateTime? lastSeenAt;

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: jsonString(json['id'], fallback: ''),
      deviceId: jsonString(json['device_id'], fallback: ''),
      platform: jsonNullableString(json['platform']),
      deviceName: jsonNullableString(json['device_name']),
      isActive: jsonBool(json['is_active']),
      lastSeenAt: jsonDate(json['last_seen_at']),
    );
  }
}
