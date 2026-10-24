import '../../../shared/utils/json_helpers.dart';

/// Nature d'une notification, déduite du champ `type` du backend.
///
/// Un type inconnu (ajouté côté serveur après la sortie de l'app) donne
/// [unknown] : la notification reste affichable avec son titre et son texte.
enum NotificationKind {
  /// Abonné : un créateur suivi a publié une vidéo.
  newVideo('new_video'),

  /// Créateur : une de ses vidéos vient d'être achetée.
  newSale('new_sale'),

  /// Créateur : le traitement est terminé, la vidéo est en ligne.
  videoReady('video_ready'),

  /// Créateur : le traitement de la vidéo a échoué.
  videoFailed('video_failed'),

  /// Créateur : un retrait a abouti.
  payoutCompleted('payout_completed'),

  /// Créateur : un retrait a échoué ou été annulé (montant recrédité).
  payoutFailed('payout_failed'),

  unknown('');

  const NotificationKind(this.apiValue);

  /// Valeur exacte du champ `type` côté API.
  final String apiValue;

  static NotificationKind fromApi(String? type) {
    for (final kind in values) {
      if (kind != unknown && kind.apiValue == type) return kind;
    }
    return unknown;
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body,
    this.videoId,
    this.payoutId,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String? body;

  /// Vidéo concernée (`new_video`, `new_sale`, `video_ready`, `video_failed`),
  /// sinon null : le backend renseigne `video_id` OU `payout_id`, jamais les
  /// deux.
  final String? videoId;

  /// Retrait concerné (`payout_completed`, `payout_failed`), sinon null.
  final String? payoutId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  NotificationKind get kind => NotificationKind.fromApi(type);

  bool get isSale => kind == NotificationKind.newSale;
  bool get isVideoReady => kind == NotificationKind.videoReady;
  bool get isVideoFailed => kind == NotificationKind.videoFailed;
  bool get isPayoutCompleted => kind == NotificationKind.payoutCompleted;
  bool get isPayoutFailed => kind == NotificationKind.payoutFailed;

  /// Notification qui concerne un retrait (et non une vidéo).
  bool get isPayout => isPayoutCompleted || isPayoutFailed;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: jsonString(json['id'], fallback: ''),
      type: jsonString(json['type'], fallback: ''),
      title: jsonString(json['title'], fallback: ''),
      body: jsonNullableString(json['body']),
      videoId: jsonNullableString(json['video_id']),
      payoutId: jsonNullableString(json['payout_id']),
      readAt: jsonDate(json['read_at']),
      createdAt: jsonDate(json['created_at']) ?? DateTime.now(),
    );
  }

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      createdAt: createdAt,
      body: body,
      videoId: videoId,
      payoutId: payoutId,
      readAt: readAt ?? this.readAt,
    );
  }
}
