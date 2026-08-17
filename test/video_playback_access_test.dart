import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/features/creator/domain/video_playback_access.dart';

void main() {
  test('video playback access parses secured stream URLs', () {
    final access = VideoPlaybackAccess.fromJson({
      'url': 'https://cdn.example.com/video/master.m3u8',
      'expires_in': 3600,
    });

    expect(access.url, 'https://cdn.example.com/video/master.m3u8');
    expect(access.expiresIn, 3600);
  });

  test('video playback access accepts alternate response keys', () {
    final access = VideoPlaybackAccess.fromJson({
      'playback_url': 'https://cdn.example.com/alternate.m3u8',
      'expires_in': '120',
    });

    expect(access.url, 'https://cdn.example.com/alternate.m3u8');
    expect(access.expiresIn, 120);
  });

  test('video playback access parses playback session metadata', () {
    final access = VideoPlaybackAccess.fromJson({
      'token': 'session-token',
      'watermark': 'Mariama Diallo',
      'expires_in': 3600,
    });

    expect(access.sessionToken, 'session-token');
    expect(access.watermark, 'Mariama Diallo');
    expect(access.expiresIn, 3600);
  });
}
