import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/domain/user_read.dart';
import '../domain/creator_analytics.dart';
import '../domain/creator_dashboard.dart';
import '../../../shared/utils/json_helpers.dart';
import '../domain/payout_balances.dart';
import '../domain/payout_provider.dart';
import '../domain/payout_request.dart';
import '../domain/top_video.dart';
import '../domain/topup.dart';
import '../domain/video_analytics.dart';
import '../domain/video_playback_access.dart';
import '../domain/video_upload_init_response.dart';
import '../domain/video_with_stats.dart';
import '../domain/wallet_ledger_entry.dart';

class CreatorRepository {
  CreatorRepository(this._tokenStorage, {http.Client? client})
    : _client = client ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _client;

  Future<CreatorDashboard> loadDashboard() async {
    final accessToken = await _requireAccessToken();

    final user = await _getUser(accessToken);
    final analytics = await _getAnalytics(accessToken);
    final balances = await _getPayoutBalances(accessToken);
    final videos = await _listAllMyVideos(accessToken);
    final topVideos = _mergeTopVideos(analytics.topVideos, videos);

    return CreatorDashboard(
      user: user,
      withdrawableBalance: balances.withdrawableBalance,
      walletBalance: balances.walletBalance,
      analytics: analytics,
      topVideos: topVideos,
    );
  }

  /// Solde du portefeuille et solde retirable, tous deux renvoyés par
  /// `GET /payouts/balance` (le second est un sous-ensemble net du premier).
  Future<PayoutBalances> loadPayoutBalances() async {
    final accessToken = await _requireAccessToken();
    return _getPayoutBalances(accessToken);
  }

  Future<PayoutBalances> _getPayoutBalances(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/payouts/balance'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = _decodeObject(response.body);
    return PayoutBalances(
      walletBalance: jsonInt(decoded['wallet_balance']),
      withdrawableBalance: jsonInt(decoded['withdrawable_balance']),
    );
  }

  /// Toutes les vidéos du créateur : `/videos/mine` plafonne à 100 par page,
  /// on enchaîne donc les pages jusqu'à épuisement.
  Future<List<VideoWithStats>> listMyVideos() async {
    final accessToken = await _requireAccessToken();
    return _listAllMyVideos(accessToken);
  }

  static const _videosPageSize = 100;
  static const _maxVideoPages = 50;

  Future<List<VideoWithStats>> _listAllMyVideos(String accessToken) async {
    final all = <VideoWithStats>[];
    for (var page = 0; page < _maxVideoPages; page++) {
      final batch = await _listMyVideos(
        accessToken,
        limit: _videosPageSize,
        offset: page * _videosPageSize,
      );
      all.addAll(batch);
      if (batch.length < _videosPageSize) {
        break;
      }
    }
    return all;
  }

  Future<VideoAnalytics> loadVideoAnalytics(String videoId) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/videos/$videoId/analytics'),
      headers: _authHeaders(accessToken),
    );

    if (_isSuccess(response)) {
      return VideoAnalytics.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  /// Session de lecture (`POST /videos/{id}/playback-session`) puis flux
  /// HLS proxié et déchiffré via `/stream/{id}/master.m3u8?token=...`.
  ///
  /// C'est le seul chemin qui fonctionne réellement : le manifeste HLS
  /// généré par le worker référence ses sous-playlists de qualité, ses
  /// segments .ts et sa clé de déchiffrement AES-128 par chemins RELATIFS
  /// sans signature propre (`app/workers/video_processing.py`). Une URL
  /// pré-signée S3/R2 brute (l'ancien endpoint `/videos/{id}/access`) ne
  /// signe que le fichier demandé : le lecteur charge le master.m3u8 avec
  /// succès puis échoue silencieusement sur chaque sous-ressource, faute
  /// de token. Seul `/stream/...` réécrit chaque URI référencée pour y
  /// propager le token de session (`streaming.py::rewrite_master_manifest`
  /// / `rewrite_index_manifest`).
  Future<VideoPlaybackAccess> loadVideoPlaybackAccess(String videoId) async {
    final accessToken = await _requireAccessToken();
    final deviceId = await _tokenStorage.readOrCreateDeviceId();

    final response = await _client.post(
      _apiUri(
        '/api/v1/videos/$videoId/playback-session',
      ).replace(queryParameters: {'device_id': deviceId}),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    // Réponse réelle de POST /videos/{id}/playback-session :
    // { "token": str, "expires_at": ISO datetime, "watermark": str }
    final decoded = _decodeObject(response.body);
    final sessionToken = jsonNullableString(decoded['token']);
    if (sessionToken == null || sessionToken.isEmpty) {
      throw const ApiException('Session de lecture invalide.');
    }

    final streamUrl = _apiUri(
      '/api/v1/stream/$videoId/master.m3u8',
    ).replace(queryParameters: {'token': sessionToken}).toString();

    return VideoPlaybackAccess(
      url: streamUrl,
      expiresAt: jsonDate(decoded['expires_at']),
      watermark: jsonNullableString(decoded['watermark']),
    );
  }

  Future<VideoWithStats> updateVideo(
    String videoId, {
    String? title,
    String? description,
    int? price,
    String? thumbnailUrl,
    bool? isPublished,
  }) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/videos/$videoId'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (price != null) 'price': price,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        if (isPublished != null) 'is_published': isPublished,
      }),
    );

    if (_isSuccess(response)) {
      return VideoWithStats.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  Future<void> deleteVideo(String videoId) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/videos/$videoId'),
      headers: _authHeaders(accessToken),
    );

    if (_isSuccess(response)) {
      return;
    }

    throw _apiException(response);
  }

  Future<VideoUploadInitResponse> initVideoUpload({
    required String filename,
    required int fileSize,
    required String mimeType,
    String? title,
    String? description,
    int? price,
  }) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/videos/upload/init'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({
        'filename': filename,
        'file_size': fileSize,
        'mime_type': mimeType,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (price != null) 'price': price,
      }),
    );

    if (_isSuccess(response)) {
      return VideoUploadInitResponse.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  /// Renvoie de nouvelles URLs pré-signées pour reprendre un envoi interrompu.
  Future<List<UploadPartTarget>> presignUploadParts(
    String videoId, {
    required String uploadId,
    required List<int> partNumbers,
  }) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/videos/upload/$videoId/parts/presign',
      ),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'upload_id': uploadId, 'parts': partNumbers}),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = _decodeObject(response.body);
    final parts = decoded['parts'];
    if (parts is List) {
      return parts
          .whereType<Map<String, dynamic>>()
          .map(UploadPartTarget.fromJson)
          .toList();
    }
    return const [];
  }

  /// PUT brut d'un morceau de fichier vers une URL R2 pré-signée (pas
  /// d'en-tête d'auth : le lien est déjà auto-authentifié). Renvoie l'ETag.
  Future<String> uploadChunk(String uploadUrl, List<int> bytes) async {
    final response = await _client.put(Uri.parse(uploadUrl), body: bytes);

    if (!_isSuccess(response)) {
      throw ApiException(
        'Échec de l’envoi d’un morceau du fichier.',
        statusCode: response.statusCode,
      );
    }

    final etag = response.headers['etag'] ?? response.headers['ETag'];
    if (etag == null || etag.isEmpty) {
      throw const ApiException(
        'Le serveur de stockage n’a pas renvoyé d’ETag.',
      );
    }
    return etag.replaceAll('"', '');
  }

  Future<void> confirmUploadPart(
    String videoId, {
    required int partNumber,
    required String etag,
    required int size,
  }) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/videos/upload/$videoId/parts/confirm',
      ),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'part_number': partNumber, 'etag': etag, 'size': size}),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }
  }

  Future<void> completeUpload(
    String videoId, {
    required String uploadId,
    required List<({int partNumber, String etag})> parts,
  }) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/videos/upload/$videoId/complete'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({
        'upload_id': uploadId,
        'parts': parts
            .map((p) => {'PartNumber': p.partNumber, 'ETag': p.etag})
            .toList(),
      }),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }
  }

  Future<UploadStatusResponse> getUploadStatus(String videoId) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/videos/upload/$videoId/status'),
      headers: _authHeaders(accessToken),
    );

    if (_isSuccess(response)) {
      return UploadStatusResponse.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  Future<void> abortUpload(String videoId) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/videos/upload/$videoId/abort'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }
  }

  /// Relance le transcodage d'une vidéo en échec (le fichier source est
  /// conservé côté serveur) — réservé au propriétaire ou à un admin.
  Future<void> retryTranscode(String videoId) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/internal/videos/$videoId/retry-transcode',
      ),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }
  }

  Future<ProcessingStatusResponse> getProcessingStatus(String videoId) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/videos/$videoId/processing-status',
      ),
      headers: _authHeaders(accessToken),
    );

    if (_isSuccess(response)) {
      return ProcessingStatusResponse.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  Future<List<WalletLedgerEntry>> loadWalletLedger() async {
    final accessToken = await _requireAccessToken();
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/wallets/transactions'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = jsonDecode(response.body);
    final items = _extractList(decoded);
    return items
        .whereType<Map<String, dynamic>>()
        .map(WalletLedgerEntry.fromJson)
        .toList();
  }

  Future<PayoutRequestRecord> requestPayout({
    required int amount,
    required String operator,
    String? destinationPhone,
  }) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/payouts/request'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({
        'amount': amount,
        'operator': operator,
        if (destinationPhone != null && destinationPhone.trim().isNotEmpty)
          'destination_phone': destinationPhone.trim(),
      }),
    );

    if (_isSuccess(response)) {
      return PayoutRequestRecord.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  /// Recharge du portefeuille : `POST /payments/topup/initiate` renvoie l'URL
  /// de paiement DexPay à ouvrir dans le navigateur ainsi que la référence
  /// à suivre via [getTopupStatus] (le crédit arrive par webhook).
  Future<TopupCheckout> initiateTopup(int amount) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/payments/topup/initiate'),
      headers: _authHeaders(accessToken),
      body: jsonEncode({'amount': amount}),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = _decodeObject(response.body);
    final url = jsonNullableString(decoded['payment_url']);
    final reference = jsonNullableString(decoded['reference']);
    if (url == null || reference == null) {
      throw const ApiException('Lien de paiement indisponible.');
    }
    return TopupCheckout(paymentUrl: url, reference: reference);
  }

  Future<TopupStatus> getTopupStatus(String reference) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/payments/topup/status/$reference'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = _decodeObject(response.body);
    return TopupStatus.parse(jsonNullableString(decoded['status']));
  }

  Future<List<PayoutProviderOption>> listPayoutProviders() async {
    final accessToken = await _requireAccessToken();
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/payouts/providers'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PayoutProviderOption.fromJson)
          .toList();
    }
    return const [];
  }

  Future<List<PayoutRequestRecord>> listPayouts() async {
    final accessToken = await _requireAccessToken();
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/payouts'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PayoutRequestRecord.fromJson)
          .toList();
    }
    return const [];
  }

  Future<PayoutRequestRecord> getPayout(String payoutId) async {
    final accessToken = await _requireAccessToken();
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/payouts/$payoutId'),
      headers: _authHeaders(accessToken),
    );

    if (_isSuccess(response)) {
      return PayoutRequestRecord.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  Future<String> _requireAccessToken() async {
    final token = await _tokenStorage.read();
    if (token == null) {
      throw const ApiException('Vous devez vous connecter.');
    }
    return token.accessToken;
  }

  Future<UserRead> _getUser(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me'),
      headers: _authHeaders(accessToken),
    );

    if (_isSuccess(response)) {
      return UserRead.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  Future<CreatorAnalytics> _getAnalytics(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/creators/me/analytics'),
      headers: _authHeaders(accessToken),
    );

    if (_isSuccess(response)) {
      return CreatorAnalytics.fromJson(_decodeObject(response.body));
    }

    throw _apiException(response);
  }

  Future<List<VideoWithStats>> _listMyVideos(
    String accessToken, {
    required int limit,
    required int offset,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/videos/mine',
    ).replace(queryParameters: {'limit': '$limit', 'offset': '$offset'});
    final response = await _client.get(uri, headers: _authHeaders(accessToken));

    if (_isSuccess(response)) {
      final decoded = jsonDecode(response.body);
      return _extractList(
        decoded,
      ).whereType<Map<String, dynamic>>().map(VideoWithStats.fromJson).toList();
    }

    throw _apiException(response);
  }

  List<dynamic> _extractList(Object? decoded) {
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map<String, dynamic>) {
      for (final key in const ['items', 'transactions', 'results', 'data']) {
        final value = decoded[key];
        if (value is List) {
          return value;
        }
      }
    }
    return const [];
  }

  List<TopVideo> _mergeTopVideos(
    List<TopVideo> analyticsTopVideos,
    List<VideoWithStats> videos,
  ) {
    final videosById = {for (final video in videos) video.id: video};

    final merged = analyticsTopVideos.map((topVideo) {
      final video = videosById[topVideo.videoId];
      return topVideo.copyWith(
        revenue: video?.revenue,
        thumbnailUrl: video?.thumbnailUrl,
      );
    }).toList();

    if (merged.isNotEmpty) {
      return merged;
    }

    final sortedVideos = [...videos]
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    return sortedVideos
        .take(5)
        .map(
          (video) => TopVideo(
            videoId: video.id,
            title: video.title,
            viewCount: video.viewCount,
            likesCount: video.likesCount,
            revenue: video.revenue,
            thumbnailUrl: video.thumbnailUrl,
          ),
        )
        .toList();
  }

  Map<String, String> _authHeaders(String accessToken) {
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  Uri _apiUri(String path) {
    return Uri.parse(ApiConfig.baseUrl).resolve(path);
  }

  bool _isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Reponse API invalide.');
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
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map<String, dynamic>) {
            final message = first['msg'];
            if (message is String && message.isNotEmpty) {
              return message;
            }
          }
        }
      }
    } on FormatException {
      return 'Impossible de lire la reponse du serveur.';
    }

    return 'La requete a echoue.';
  }
}
