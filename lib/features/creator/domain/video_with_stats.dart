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

  factory VideoWithStats.sample({String id = 'sample-1'}) {
    return samples().firstWhere(
      (video) => video.id == id,
      orElse: () => samples().first,
    );
  }

  static List<VideoWithStats> samples() {
    final now = DateTime(2026, 8, 14, 9, 41);

    return [
      VideoWithStats(
        id: 'sample-1',
        title: 'Nuits de Conakry — épisode 3',
        description:
            'Une traversée nocturne entre Kaloum, Matam et les studios de répétition.',
        price: 15000,
        duration: 1448,
        status: 'published',
        isPublished: true,
        viewCount: 14208,
        likesCount: 842,
        revenue: 1842000,
        createdAt: now.subtract(const Duration(days: 63)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      VideoWithStats(
        id: 'sample-2',
        title: 'Marché Madina, 5h du matin',
        description:
            'Portrait court des commerçantes qui ouvrent le marché avant le lever du soleil.',
        price: 10000,
        duration: 632,
        status: 'published',
        isPublished: true,
        viewCount: 9461,
        likesCount: 512,
        revenue: 946000,
        createdAt: now.subtract(const Duration(days: 48)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
      VideoWithStats(
        id: 'sample-3',
        title: 'Kaloum en coulisses',
        description: 'Making-of du prochain épisode.',
        price: 0,
        duration: 318,
        status: 'processing',
        isPublished: false,
        viewCount: 0,
        likesCount: 0,
        revenue: 0,
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(minutes: 24)),
      ),
      VideoWithStats(
        id: 'sample-4',
        title: 'Archive familiale — version longue',
        description: 'Import interrompu pendant le transfert.',
        price: 5000,
        duration: 905,
        status: 'failed',
        isPublished: false,
        viewCount: 0,
        likesCount: 0,
        revenue: 0,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
    ];
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
