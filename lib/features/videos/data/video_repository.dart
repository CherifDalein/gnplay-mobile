import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/utils/json_helpers.dart';
import '../../auth/data/token_storage.dart';
import '../../creator/domain/video_analytics.dart';
import '../../creator/domain/video_playback_access.dart';
import '../../creator/domain/video_preview_generation.dart';
import '../../creator/domain/video_upload_init_response.dart';
import '../../creator/domain/video_with_stats.dart';

/// Vidéos du créateur : liste, édition, suppression, statistiques, lecture et
/// suivi du traitement.
class VideoRepository {
  VideoRepository(this._api, this._tokenStorage);

  final ApiClient _api;
  final TokenStorage _tokenStorage;

  static const _pageSize = 100; // maximum accepté par /videos/mine
  static const _maxPages = 50;

  /// Toutes les vidéos du créateur, tous statuts confondus (pages de 100).
  Future<List<VideoWithStats>> listMyVideos() async {
    final all = <VideoWithStats>[];
    for (var page = 0; page < _maxPages; page++) {
      final batch = (await _api.get(
        '/api/v1/videos/mine',
        query: {'limit': _pageSize, 'offset': page * _pageSize},
      )).asObjectList.map(VideoWithStats.fromJson).toList();
      all.addAll(batch);
      if (batch.length < _pageSize) break;
    }
    return all;
  }

  /// Modifie titre, description, prix et/ou publication (seuls les champs
  /// fournis sont envoyés). Le serveur n'a pas de route d'envoi de miniature.
  Future<VideoWithStats> updateVideo(
    String videoId, {
    String? title,
    String? description,
    int? price,
    bool? isPublished,
  }) async {
    final json = await _api.patch(
      '/api/v1/videos/$videoId',
      json: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (price != null) 'price': price,
        if (isPublished != null) 'is_published': isPublished,
      },
    );
    return VideoWithStats.fromJson(json.asObject);
  }

  Future<void> deleteVideo(String videoId) =>
      _api.delete('/api/v1/videos/$videoId');

  Future<VideoAnalytics> loadVideoAnalytics(String videoId) async {
    final json = await _api.get('/api/v1/videos/$videoId/analytics');
    return VideoAnalytics.fromJson(json.asObject);
  }

  /// Session de lecture (`POST /videos/{id}/playback-session`) puis flux
  /// HLS proxié et déchiffré via `/stream/{id}/master.m3u8?token=...`.
  ///
  /// C'est le seul chemin de lecture qui fonctionne : le manifeste HLS
  /// référence ses sous-playlists, segments et clé AES par chemins relatifs ;
  /// seul `/stream/...` réécrit ces URI pour y propager le token de session.
  Future<VideoPlaybackAccess> createPlaybackSession(String videoId) async {
    final deviceId = await _tokenStorage.readOrCreateDeviceId();
    final json = (await _api.post(
      '/api/v1/videos/$videoId/playback-session',
      query: {'device_id': deviceId},
    )).asObject;

    final token = jsonNullableString(json['token']);
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Session de lecture invalide.',
        kind: ApiErrorKind.unexpected,
      );
    }
    return VideoPlaybackAccess(
      url: _api.uri('/api/v1/stream/$videoId/master.m3u8', {
        'token': token,
      }).toString(),
      expiresAt: jsonDate(json['expires_at']),
      watermark: jsonNullableString(json['watermark']),
    );
  }

  /// Relance le transcodage d'une vidéo en échec (le fichier source est
  /// conservé côté serveur). Route « internal » mais authentifiée par
  /// l'utilisateur : réservée au propriétaire ou à un admin.
  Future<void> retryTranscode(String videoId) =>
      _api.post('/api/v1/internal/videos/$videoId/retry-transcode');

  Future<ProcessingStatusResponse> getProcessingStatus(String videoId) async {
    final json = await _api.get('/api/v1/videos/$videoId/processing-status');
    return ProcessingStatusResponse.fromJson(json.asObject);
  }

  /// Demande la création de l'aperçu de 15 s (`POST /videos/{id}/preview`).
  /// 200 : l'aperçu existe déjà ; 202 : génération lancée, à suivre en relisant
  /// la vidéo ; 409 : la vidéo n'est pas encore prête.
  Future<PreviewGeneration> generatePreview(String videoId) async {
    final json = await _api.post('/api/v1/videos/$videoId/preview');
    return PreviewGeneration.fromJson(json.asObject);
  }
}
