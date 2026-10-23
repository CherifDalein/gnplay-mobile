import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/features/creator/domain/video_with_stats.dart';

VideoWithStats _video(String status, {bool published = false}) =>
    VideoWithStats.fromJson({
      'id': 'v1',
      'title': 'Clip',
      'status': status,
      'is_published': published,
      'created_at': '2026-06-12T09:41:00Z',
      'updated_at': '2026-06-12T09:41:00Z',
    });

void main() {
  test('statuts backend → étape et libellé', () {
    expect(_video('ready', published: true).lifecycle, VideoLifecycle.online);
    expect(_video('ready').lifecycle, VideoLifecycle.hidden);
    expect(_video('ready').statusLabel, 'Masquée');
    expect(_video('READY', published: true).statusLabel, 'En ligne');
    expect(_video('queued').lifecycle, VideoLifecycle.processing);
    expect(_video('processing').isProcessing, isTrue);
    expect(_video('draft').lifecycle, VideoLifecycle.uploading);
    expect(_video('uploading').isProcessing, isTrue);
    expect(_video('failed').isFailed, isTrue);
    expect(_video('blocked').isBlocked, isTrue);
    expect(_video('deleted', published: true).isDeleted, isTrue);
  });

  test('seule une vidéo prête peut être publiée ou masquée', () {
    expect(_video('ready').canTogglePublish, isTrue);
    expect(_video('ready', published: true).canTogglePublish, isTrue);
    for (final status in [
      'draft',
      'queued',
      'processing',
      'failed',
      'blocked',
      'deleted',
    ]) {
      expect(_video(status).canTogglePublish, isFalse, reason: status);
    }
  });
}
