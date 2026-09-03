import '../../../shared/utils/json_helpers.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body,
    this.videoId,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final String? videoId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: jsonString(json['id'], fallback: ''),
      type: jsonString(json['type'], fallback: ''),
      title: jsonString(json['title'], fallback: ''),
      body: jsonNullableString(json['body']),
      videoId: jsonNullableString(json['video_id']),
      readAt: jsonDate(json['read_at']),
      createdAt: jsonDate(json['created_at']) ?? DateTime.now(),
    );
  }

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      createdAt: createdAt,
      body: body,
      videoId: videoId,
      readAt: readAt ?? this.readAt,
    );
  }
}
