import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../creator/domain/video_upload_init_response.dart';

/// Envoi multipart d'une vidéo vers R2 : init → PUT de chaque partie sur une
/// URL pré-signée → confirmation → complete (qui lance le transcodage).
class UploadRepository {
  UploadRepository(this._api);

  final ApiClient _api;

  Future<VideoUploadInitResponse> init({
    required String filename,
    required int fileSize,
    required String mimeType,
    String? title,
    String? description,
    int? price,
  }) async {
    final json = await _api.post(
      '/api/v1/videos/upload/init',
      json: {
        'filename': filename,
        'file_size': fileSize,
        'mime_type': mimeType,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (price != null) 'price': price,
      },
    );
    return VideoUploadInitResponse.fromJson(json.asObject);
  }

  /// Nouvelles URLs pré-signées (expiration, reprise d'un envoi interrompu).
  Future<List<UploadPartTarget>> presignParts(
    String videoId, {
    required String uploadId,
    required List<int> partNumbers,
  }) async {
    final json = await _api.post(
      '/api/v1/videos/upload/$videoId/parts/presign',
      json: {'upload_id': uploadId, 'parts': partNumbers},
    );
    return (json.asObject['parts'] as Object?).asObjectList
        .map(UploadPartTarget.fromJson)
        .toList();
  }

  /// PUT brut d'une partie vers son URL pré-signée. Renvoie l'ETag (sans
  /// guillemets), indispensable pour finaliser l'envoi.
  Future<String> uploadPart(String uploadUrl, List<int> bytes) async {
    final response = await _api.putExternal(uploadUrl, bytes);
    final etag = response.headers['etag'];
    if (etag == null || etag.isEmpty) {
      throw const ApiException(
        'Le stockage n’a pas confirmé la réception d’une partie du fichier.',
        kind: ApiErrorKind.unexpected,
      );
    }
    return etag.replaceAll('"', '');
  }

  Future<void> confirmPart(
    String videoId, {
    required int partNumber,
    required String etag,
    required int size,
  }) => _api.post(
    '/api/v1/videos/upload/$videoId/parts/confirm',
    json: {'part_number': partNumber, 'etag': etag, 'size': size},
  );

  /// Parties déjà confirmées (avec leur ETag), pour reprendre un envoi.
  Future<List<ConfirmedUploadPart>> listConfirmedParts(String videoId) async {
    final json = await _api.get('/api/v1/videos/upload/$videoId/parts');
    return (json.asObject['parts'] as Object?).asObjectList
        .map(ConfirmedUploadPart.fromJson)
        .toList();
  }

  Future<UploadStatusResponse> status(String videoId) async {
    final json = await _api.get('/api/v1/videos/upload/$videoId/status');
    return UploadStatusResponse.fromJson(json.asObject);
  }

  /// Finalise l'envoi. Le backend attend `PartNumber` / `ETag` (format S3).
  Future<void> complete(
    String videoId, {
    required String uploadId,
    required List<({int partNumber, String etag})> parts,
  }) => _api.post(
    '/api/v1/videos/upload/$videoId/complete',
    json: {
      'upload_id': uploadId,
      'parts': [
        for (final part in parts)
          {'PartNumber': part.partNumber, 'ETag': part.etag},
      ],
    },
  );

  /// Abandonne l'envoi : le backend SUPPRIME la vidéo. À n'appeler qu'avant
  /// `complete` (jamais pendant le traitement).
  Future<void> abort(String videoId) =>
      _api.post('/api/v1/videos/upload/$videoId/abort');
}
