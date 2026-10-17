import '../../../shared/utils/json_helpers.dart';

class VideoWithStats {
  const VideoWithStats({
    required this.id,
    required this.title,
    required this.viewCount,
    required this.likesCount,
    required this.revenue,
    required this.price,
    required this.duration,
    required this.status,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.thumbnailUrl,
    this.previewUrl,
  });

  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String? previewUrl;
  final int price;
  final int duration;
  final String status;
  final bool isPublished;
  final int viewCount;
  final int likesCount;
  final int revenue;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isFailed => status.toLowerCase() == 'failed';

  bool get isProcessing {
    final normalized = status.toLowerCase();
    return normalized == 'processing' ||
        normalized == 'uploading' ||
        normalized == 'queued' ||
        normalized == 'uploaded';
  }

  bool get isReady => status.toLowerCase() == 'ready';

  bool get isDraft => !isPublished && !isProcessing && !isFailed;

  String get statusLabel {
    if (isFailed) {
      return 'Échec';
    }
    if (isProcessing) {
      return 'Traitement';
    }
    if (isPublished) {
      return 'Publiée';
    }
    return 'Brouillon';
  }

  factory VideoWithStats.fromJson(Map<String, dynamic> json) {
    final isPublished = jsonBool(json['is_published']);
    final now = DateTime.now();

    return VideoWithStats(
      id: jsonString(json['id'], fallback: ''),
      title: jsonString(json['title'], fallback: 'Vidéo sans titre'),
      description: jsonNullableString(json['description']),
      thumbnailUrl: jsonNullableString(json['thumbnail_url']),
      previewUrl: jsonNullableString(json['preview_url']),
      price: jsonInt(json['price']),
      duration: jsonInt(json['duration']),
      status: jsonString(
        json['status'],
        fallback: isPublished ? 'published' : 'draft',
      ),
      isPublished: isPublished,
      viewCount: jsonInt(json['view_count']),
      likesCount: jsonInt(json['likes_count']),
      revenue: jsonInt(json['revenue']),
      createdAt: jsonDate(json['created_at']) ?? now,
      updatedAt: jsonDate(json['updated_at']) ?? now,
    );
  }

  VideoWithStats copyWith({
    String? title,
    String? description,
    String? thumbnailUrl,
    String? previewUrl,
    int? price,
    int? duration,
    String? status,
    bool? isPublished,
    int? viewCount,
    int? likesCount,
    int? revenue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoWithStats(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      isPublished: isPublished ?? this.isPublished,
      viewCount: viewCount ?? this.viewCount,
      likesCount: likesCount ?? this.likesCount,
      revenue: revenue ?? this.revenue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
