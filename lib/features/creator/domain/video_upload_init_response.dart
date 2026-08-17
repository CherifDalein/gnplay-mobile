class VideoUploadInitResponse {
  const VideoUploadInitResponse(this.raw);

  final Map<String, dynamic> raw;

  String? get videoId => _string(raw['video_id']) ?? _string(raw['id']);

  String? get uploadId => _string(raw['upload_id']) ?? _string(raw['key']);

  String? get uploadUrl {
    return _string(raw['upload_url']) ??
        _string(raw['presigned_url']) ??
        _string(raw['url']);
  }

  bool get hasUploadTarget => uploadUrl != null;

  factory VideoUploadInitResponse.fromJson(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      return VideoUploadInitResponse(decoded);
    }
    return const VideoUploadInitResponse({});
  }
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}
