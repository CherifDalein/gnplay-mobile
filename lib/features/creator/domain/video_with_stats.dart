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

  /// Étape de la vie de la vidéo, déduite du statut backend (`VideoStatus`)
  /// et de `is_published`. Le backend n'écrit jamais `published`/`draft` au
  /// sens « en ligne / brouillon » : une vidéo en ligne est `ready` +
  /// `is_published`, et `draft` désigne un envoi pas encore finalisé.
  VideoLifecycle get lifecycle => VideoLifecycle.of(status, isPublished);

  bool get isFailed => lifecycle == VideoLifecycle.failed;

  /// Envoi ou traitement en cours (rien à faire, il faut attendre).
  bool get isProcessing =>
      lifecycle == VideoLifecycle.processing ||
      lifecycle == VideoLifecycle.uploading;

  bool get isReady =>
      lifecycle == VideoLifecycle.online || lifecycle == VideoLifecycle.hidden;

  /// Prête mais masquée du catalogue.
  bool get isDraft => lifecycle == VideoLifecycle.hidden;

  bool get isBlocked => lifecycle == VideoLifecycle.blocked;

  bool get isDeleted => lifecycle == VideoLifecycle.deleted;

  /// Seule une vidéo prête peut être publiée ou masquée.
  bool get canTogglePublish => isReady;

  String get statusLabel => lifecycle.label;

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
      status: jsonString(json['status'], fallback: 'ready').toLowerCase(),
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

enum VideoLifecycle {
  /// Envoi commencé mais pas finalisé (`draft`, `uploading`, `uploaded`).
  uploading('Envoi incomplet'),

  /// En file d'attente ou en cours de transcodage.
  processing('En traitement'),

  /// Prête et visible dans le catalogue.
  online('En ligne'),

  /// Prête mais masquée par le créateur.
  hidden('Masquée'),

  failed('Échec'),

  /// Bloquée par la modération.
  blocked('Bloquée'),

  /// Supprimée (conservée côté serveur pour les acheteurs).
  deleted('Supprimée');

  const VideoLifecycle(this.label);

  final String label;

  static VideoLifecycle of(String status, bool isPublished) {
    switch (status.toLowerCase()) {
      case 'draft':
      case 'uploading':
      case 'uploaded':
        return VideoLifecycle.uploading;
      case 'queued':
      case 'processing':
        return VideoLifecycle.processing;
      case 'failed':
        return VideoLifecycle.failed;
      case 'blocked':
        return VideoLifecycle.blocked;
      case 'deleted':
        return VideoLifecycle.deleted;
      case 'ready':
      case 'published':
      default:
        return isPublished ? VideoLifecycle.online : VideoLifecycle.hidden;
    }
  }
}
