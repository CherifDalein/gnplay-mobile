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
    this.videoUrl,
  });

  final String id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String? previewUrl;
  final String? videoUrl;
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
        normalized == 'transcoding';
  }

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
    final isPublished = _bool(json['is_published']);
    final now = DateTime.now();

    return VideoWithStats(
      id: _string(json['id'], fallback: ''),
      title: _string(json['title'], fallback: 'Vidéo sans titre'),
      description: _nullableString(json['description']),
      thumbnailUrl: _nullableString(json['thumbnail_url']),
      previewUrl: _nullableString(json['preview_url']),
      videoUrl:
          _nullableString(json['video_url']) ??
          _nullableString(json['playback_url']) ??
          _nullableString(json['stream_url']) ??
          _nullableString(json['hls_url']) ??
          _nullableString(json['master_url']),
      price: _int(json['price']),
      duration: _int(json['duration']),
      status: _string(
        json['status'],
        fallback: isPublished ? 'published' : 'draft',
      ),
      isPublished: isPublished,
      viewCount: _int(json['view_count']),
      likesCount: _int(json['likes_count']),
      revenue: _int(json['revenue']),
      createdAt: _date(json['created_at']) ?? now,
      updatedAt: _date(json['updated_at']) ?? now,
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
    String? videoUrl,
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
      videoUrl: videoUrl ?? this.videoUrl,
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

String _string(Object? value, {required String fallback}) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return fallback;
}

String? _nullableString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return false;
}

DateTime? _date(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
