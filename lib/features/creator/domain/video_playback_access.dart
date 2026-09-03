import '../../../shared/utils/json_helpers.dart';

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
          jsonNullableString(json['url']) ??
          jsonNullableString(json['playback_url']) ??
          jsonNullableString(json['stream_url']) ??
          '',
      expiresIn: jsonInt(json['expires_in']),
      sessionToken:
          jsonNullableString(json['token']) ??
          jsonNullableString(json['session_token']) ??
          jsonNullableString(json['playback_token']),
      watermark: jsonNullableString(json['watermark']),
    );
  }
}
