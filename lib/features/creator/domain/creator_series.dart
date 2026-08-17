class CreatorSeries {
  const CreatorSeries({
    required this.id,
    required this.name,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.items = const [],
  });

  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CreatorSeriesEpisode> items;

  int get episodeCount => items.length;

  int get totalDuration {
    return items.fold<int>(0, (total, episode) => total + episode.duration);
  }

  int get totalRevenue {
    return items.fold<int>(0, (total, episode) => total + episode.revenue);
  }

  int get totalViews {
    return items.fold<int>(0, (total, episode) => total + episode.viewCount);
  }

  factory CreatorSeries.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final items = json['items'];

    return CreatorSeries(
      id: _string(json['id'], fallback: ''),
      name: _string(json['name'], fallback: 'Série sans titre'),
      description: _nullableString(json['description']),
      isPublic: _bool(json['is_public']),
      createdAt: _date(json['created_at']) ?? now,
      updatedAt: _date(json['updated_at']) ?? now,
      items: items is List
          ? items
                .whereType<Map<String, dynamic>>()
                .map(CreatorSeriesEpisode.fromJson)
                .toList()
          : const [],
    );
  }

  factory CreatorSeries.sample({String id = 'series-1'}) {
    return samples().firstWhere(
      (series) => series.id == id,
      orElse: () => samples().first,
    );
  }

  static List<CreatorSeries> samples() {
    final now = DateTime(2026, 8, 14, 9, 41);

    return [
      CreatorSeries(
        id: 'series-1',
        name: 'Nuits de Conakry',
        description: 'Mini-série documentaire sur la ville après minuit.',
        isPublic: true,
        createdAt: now.subtract(const Duration(days: 84)),
        updatedAt: now.subtract(const Duration(days: 2)),
        items: [
          CreatorSeriesEpisode.sample(
            id: 'episode-1',
            title: 'Épisode 1 — Kaloum',
            position: 1,
            viewCount: 7800,
            revenue: 940000,
          ),
          CreatorSeriesEpisode.sample(
            id: 'episode-2',
            title: 'Épisode 2 — Matam',
            position: 2,
            viewCount: 10420,
            revenue: 1320000,
          ),
          CreatorSeriesEpisode.sample(
            id: 'episode-3',
            title: 'Épisode 3 — Les studios',
            position: 3,
            viewCount: 14208,
            revenue: 1842000,
          ),
        ],
      ),
      CreatorSeries(
        id: 'series-2',
        name: 'Portraits du marché',
        description: 'Histoires courtes tournées à Madina.',
        isPublic: false,
        createdAt: now.subtract(const Duration(days: 21)),
        updatedAt: now.subtract(const Duration(days: 1)),
        items: [
          CreatorSeriesEpisode.sample(
            id: 'episode-4',
            title: '5h du matin',
            position: 1,
            status: 'published',
            isPublished: true,
            viewCount: 9461,
            revenue: 946000,
          ),
          CreatorSeriesEpisode.sample(
            id: 'episode-5',
            title: 'Les préparatifs',
            position: 2,
            status: 'draft',
            isPublished: false,
            viewCount: 0,
            revenue: 0,
          ),
        ],
      ),
    ];
  }
}

class CreatorSeriesEpisode {
  const CreatorSeriesEpisode({
    required this.id,
    required this.title,
    required this.position,
    required this.duration,
    required this.status,
    required this.isPublished,
    required this.price,
    required this.viewCount,
    required this.revenue,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final int position;
  final int duration;
  final String status;
  final bool isPublished;
  final int price;
  final int viewCount;
  final int revenue;
  final String? thumbnailUrl;

  String get statusLabel {
    if (status.toLowerCase() == 'processing') {
      return 'Traitement';
    }
    if (isPublished) {
      return 'Publiée';
    }
    return 'Brouillon';
  }

  factory CreatorSeriesEpisode.fromJson(Map<String, dynamic> json) {
    final video = json['video'];
    final source = video is Map<String, dynamic> ? video : json;
    final isPublished = _bool(source['is_published']);

    return CreatorSeriesEpisode(
      id: _string(source['id'], fallback: _string(json['id'], fallback: '')),
      title: _string(source['title'], fallback: 'Épisode sans titre'),
      position: _int(json['position']),
      duration: _int(source['duration']),
      status: _string(
        source['status'],
        fallback: isPublished ? 'published' : 'draft',
      ),
      isPublished: isPublished,
      price: _int(source['price']),
      viewCount: _int(source['view_count']),
      revenue: _int(source['revenue']),
      thumbnailUrl: _nullableString(source['thumbnail_url']),
    );
  }

  factory CreatorSeriesEpisode.sample({
    required String id,
    required String title,
    required int position,
    String status = 'published',
    bool isPublished = true,
    int viewCount = 0,
    int revenue = 0,
  }) {
    return CreatorSeriesEpisode(
      id: id,
      title: title,
      position: position,
      duration: 920,
      status: status,
      isPublished: isPublished,
      price: 15000,
      viewCount: viewCount,
      revenue: revenue,
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
