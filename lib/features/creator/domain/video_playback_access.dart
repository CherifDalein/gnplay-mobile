class VideoPlaybackAccess {
  const VideoPlaybackAccess({
    required this.url,
    required this.expiresIn,
    this.sessionToken,
    this.watermark,
    this.httpHeaders = const {},
  });

  final String url;
  final int expiresIn;
  final String? sessionToken;
  final String? watermark;
  final Map<String, String> httpHeaders;

  factory VideoPlaybackAccess.fromJson(Map<String, dynamic> json) {
    return VideoPlaybackAccess(
      url:
          _string(json['url']) ??
          _string(json['playback_url']) ??
          _string(json['stream_url']) ??
          '',
      expiresIn: _int(json['expires_in']),
      sessionToken:
          _string(json['token']) ??
          _string(json['session_token']) ??
          _string(json['playback_token']),
      watermark: _string(json['watermark']),
    );
  }
}

String? _string(Object? value) {
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
