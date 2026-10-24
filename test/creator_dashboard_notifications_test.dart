import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/features/profile/domain/app_notification.dart';

Map<String, Object?> _json(String type, {String? videoId, String? payoutId}) =>
    {
      'id': 'n1',
      'type': type,
      'title': 'Titre',
      'body': 'Texte',
      'video_id': videoId,
      'payout_id': payoutId,
      'read_at': null,
      'created_at': '2026-10-23T10:00:00Z',
    };

void main() {
  group('AppNotification.fromJson', () {
    test('vente : video_id renseigné, pas de payout_id', () {
      final n = AppNotification.fromJson(_json('new_sale', videoId: 'v1'));

      expect(n.kind, NotificationKind.newSale);
      expect(n.isSale, isTrue);
      expect(n.videoId, 'v1');
      expect(n.payoutId, isNull);
      expect(n.isPayout, isFalse);
      expect(n.isUnread, isTrue);
    });

    test('retrait terminé et retrait échoué : payout_id renseigné', () {
      final done = AppNotification.fromJson(
        _json('payout_completed', payoutId: 'p1'),
      );
      final failed = AppNotification.fromJson(
        _json('payout_failed', payoutId: 'p2'),
      );

      expect(done.isPayoutCompleted, isTrue);
      expect(done.payoutId, 'p1');
      expect(done.videoId, isNull);
      expect(done.isPayout, isTrue);
      expect(failed.isPayoutFailed, isTrue);
      expect(failed.payoutId, 'p2');
    });

    test('vidéo prête / en échec / nouvelle vidéo', () {
      expect(
        AppNotification.fromJson(_json('video_ready', videoId: 'v')).kind,
        NotificationKind.videoReady,
      );
      expect(
        AppNotification.fromJson(_json('video_failed', videoId: 'v')).kind,
        NotificationKind.videoFailed,
      );
      final newVideo = AppNotification.fromJson(
        _json('new_video', videoId: 'v'),
      );
      expect(newVideo.kind, NotificationKind.newVideo);
      expect(newVideo.isSale, isFalse);
      expect(newVideo.type, 'new_video');
    });

    test('type inconnu : notification conservée, kind unknown', () {
      final n = AppNotification.fromJson(_json('quelque_chose_de_neuf'));

      expect(n.kind, NotificationKind.unknown);
      expect(n.type, 'quelque_chose_de_neuf');
      expect(n.title, 'Titre');
    });

    test('lue : readAt renseigné ; copyWith conserve payout_id', () {
      final json = _json('payout_completed', payoutId: 'p1')
        ..['read_at'] = '2026-10-23T11:00:00Z';
      final read = AppNotification.fromJson(json);
      expect(read.isUnread, isFalse);

      final unread = AppNotification.fromJson(
        _json('payout_completed', payoutId: 'p1'),
      );
      final marked = unread.copyWith(readAt: DateTime.utc(2026, 10, 23));
      expect(marked.isUnread, isFalse);
      expect(marked.payoutId, 'p1');
    });

    test('champs vides traités comme absents', () {
      final n = AppNotification.fromJson(_json('new_sale', videoId: ' '));
      expect(n.videoId, isNull);
    });
  });
}
