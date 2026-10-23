import '../../../shared/utils/json_helpers.dart';

class UploadPartTarget {
  const UploadPartTarget({required this.partNumber, required this.uploadUrl});

  final int partNumber;
  final String uploadUrl;

  /// `upload/init` renvoie l'URL sous `url`, `parts/presign` sous
  /// `upload_url` : on accepte les deux.
  factory UploadPartTarget.fromJson(Map<String, dynamic> json) {
    return UploadPartTarget(
      partNumber: jsonInt(json['part_number']),
      uploadUrl: jsonString(json['upload_url'] ?? json['url'], fallback: ''),
    );
  }
}

class VideoUploadInitResponse {
  const VideoUploadInitResponse({
    required this.videoId,
    required this.uploadId,
    required this.objectKey,
    required this.chunkSize,
    required this.totalParts,
    required this.maxParallelUploads,
    required this.expiresIn,
    required this.parts,
  });

  final String videoId;
  final String uploadId;
  final String objectKey;
  final int chunkSize;
  final int totalParts;
  final int maxParallelUploads;
  final int expiresIn;
  final List<UploadPartTarget> parts;

  factory VideoUploadInitResponse.fromJson(Map<String, dynamic> json) {
    final rawParts = json['parts'];
    return VideoUploadInitResponse(
      videoId: jsonString(json['video_id'], fallback: ''),
      uploadId: jsonString(json['upload_id'], fallback: ''),
      objectKey: jsonString(json['object_key'], fallback: ''),
      chunkSize: jsonInt(json['chunk_size']),
      totalParts: jsonInt(json['total_parts']),
      maxParallelUploads: jsonInt(json['max_parallel_uploads']) == 0
          ? 3
          : jsonInt(json['max_parallel_uploads']),
      expiresIn: jsonInt(json['expires_in']),
      parts: rawParts is List
          ? rawParts
                .whereType<Map<String, dynamic>>()
                .map(UploadPartTarget.fromJson)
                .toList()
          : const [],
    );
  }
}

class UploadStatusResponse {
  const UploadStatusResponse({
    required this.videoId,
    required this.status,
    required this.uploadId,
    required this.chunkSize,
    required this.totalParts,
    required this.uploadedParts,
    required this.missingParts,
  });

  final String videoId;
  final String status;
  final String uploadId;
  final int chunkSize;
  final int totalParts;
  final List<int> uploadedParts;
  final List<int> missingParts;

  factory UploadStatusResponse.fromJson(Map<String, dynamic> json) {
    return UploadStatusResponse(
      videoId: jsonString(json['video_id'], fallback: ''),
      status: jsonString(json['status'], fallback: ''),
      uploadId: jsonString(json['upload_id'], fallback: ''),
      chunkSize: jsonInt(json['chunk_size']),
      totalParts: jsonInt(json['total_parts']),
      uploadedParts: _intList(json['uploaded_parts']),
      missingParts: _intList(json['missing_parts']),
    );
  }

  static List<int> _intList(Object? value) {
    if (value is List) {
      return value.map(jsonInt).toList();
    }
    return const [];
  }
}

class ProcessingStatusResponse {
  const ProcessingStatusResponse({
    required this.videoId,
    required this.status,
    required this.progress,
    required this.attempts,
    this.errorMessage,
  });

  final String videoId;
  final String status;
  final int progress;
  final int attempts;
  final String? errorMessage;

  bool get isDone => status == 'completed' || status == 'ready';
  bool get isFailed => status == 'failed';

  /// Aucun job de transcodage n'existe (encore) pour cette vidéo.
  bool get isNotStarted => status == 'not_started';

  factory ProcessingStatusResponse.fromJson(Map<String, dynamic> json) {
    return ProcessingStatusResponse(
      videoId: jsonString(json['video_id'], fallback: ''),
      status: jsonString(json['status'], fallback: ''),
      progress: jsonInt(json['progress']),
      attempts: jsonInt(json['attempts']),
      errorMessage: jsonNullableString(json['error_message']),
    );
  }
}

/// Partie déjà confirmée côté serveur (`GET /videos/upload/{id}/parts`).
class ConfirmedUploadPart {
  const ConfirmedUploadPart({required this.partNumber, required this.etag});

  final int partNumber;
  final String etag;

  factory ConfirmedUploadPart.fromJson(Map<String, dynamic> json) {
    return ConfirmedUploadPart(
      partNumber: jsonInt(json['part_number']),
      etag: jsonString(json['etag'], fallback: ''),
    );
  }
}
