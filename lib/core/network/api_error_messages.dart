import 'api_exception.dart';

/// Traduit les erreurs du backend en messages lisibles en français.
///
/// Le backend mélange des messages français (à afficher tels quels) et des
/// messages techniques en anglais, parfois avec l'exception Python collée
/// (`"Upload init failed: …"`). Ces derniers ne doivent jamais atteindre
/// l'utilisateur : on les traduit quand on les connaît, sinon on se rabat sur
/// un message générique selon le code HTTP.
abstract final class ApiErrorMessages {
  static const _known = <String, String>{
    'video not found': 'Cette vidéo est introuvable.',
    'video not found or access denied': 'Cette vidéo est introuvable.',
    'access denied': 'Vous n’avez pas accès à cette ressource.',
    'you do not have access to this video':
        'Vous n’avez pas accès à cette vidéo.',
    'video is not ready': 'La vidéo n’est pas encore prête.',
    'video is not ready for streaming':
        'La vidéo est encore en cours de traitement.',
    'video is not published': 'Cette vidéo n’est pas publiée.',
    'unsupported video format':
        'Format vidéo non pris en charge (MP4, MOV ou WebM).',
    'invalid file size': 'Taille de fichier invalide.',
    'upload not found': 'Envoi introuvable : recommencez la publication.',
    'upload session not found':
        'Session d’envoi expirée : recommencez la publication.',
    'video upload session not found':
        'Session d’envoi expirée : recommencez la publication.',
    'cannot retry: source upload record not found.':
        'Le fichier d’origine est introuvable : renvoyez la vidéo.',
    'video processing queue is not available':
        'Le traitement des vidéos est momentanément indisponible.',
    'price must be greater than or equal to 0':
        'Le prix ne peut pas être négatif.',
    'playback is restricted to registered active devices':
        'Cet appareil n’est pas autorisé à lire des vidéos.',
    'invalid or expired playback token':
        'La session de lecture a expiré. Relancez la vidéo.',
    'master hls manifest not found for this video':
        'La vidéo n’est pas disponible à la lecture.',
    'master manifest not found': 'La vidéo n’est pas disponible à la lecture.',
    'stream file not found': 'La vidéo n’est pas disponible à la lecture.',
    'device not found': 'Appareil introuvable.',
    'notification not found': 'Notification introuvable.',
    'user not found': 'Compte introuvable.',
    'creator not found': 'Créateur introuvable.',
    'insufficient balance': 'Solde insuffisant.',
    'you cannot purchase your own video':
        'Vous ne pouvez pas acheter votre propre vidéo.',
    'not authenticated': 'Votre session a expiré. Reconnectez-vous.',
    'could not validate credentials':
        'Votre session a expiré. Reconnectez-vous.',
  };

  /// Message pour un `detail` serveur et un code HTTP.
  static String forServer(String? detail, int statusCode) {
    final text = detail?.trim() ?? '';
    if (text.isNotEmpty) {
      final known = _known[text.toLowerCase()];
      if (known != null) return known;
      if (!_looksEnglish(text) && !_looksTechnical(text)) return text;
    }
    return forKind(ApiException.kindForStatus(statusCode));
  }

  static String forKind(ApiErrorKind kind) {
    return switch (kind) {
      ApiErrorKind.network =>
        'Connexion impossible. Vérifiez votre accès à Internet.',
      ApiErrorKind.timeout =>
        'Le serveur met trop de temps à répondre. Réessayez.',
      ApiErrorKind.unauthorized => 'Votre session a expiré. Reconnectez-vous.',
      ApiErrorKind.forbidden => 'Cette action n’est pas autorisée.',
      ApiErrorKind.notFound => 'Élément introuvable.',
      ApiErrorKind.invalid => 'Certaines informations sont invalides.',
      ApiErrorKind.rateLimited =>
        'Trop de tentatives. Patientez un instant avant de réessayer.',
      ApiErrorKind.server =>
        'Le serveur a rencontré un problème. Réessayez dans un instant.',
      ApiErrorKind.unexpected => 'Réponse inattendue du serveur.',
    };
  }

  // Les messages du backend destinés à l'utilisateur sont en français ; les
  // messages techniques sont en anglais. On affiche donc tout ce qui ne
  // ressemble pas à de l'anglais (« Utilisateur inexistant », « Trop de
  // tentatives, ressayez dans 1min »…).
  static final _englishMarkers = RegExp(
    r"\b(the|not|is|are|was|be|must|cannot|can't|you|your|failed|invalid|denied|found|only|already|exceeded|required|missing|unsupported|error|this|for|of|to)\b",
    caseSensitive: false,
  );

  static bool _looksEnglish(String text) =>
      !RegExp(r'[éèêàâçùûôîï]').hasMatch(text) &&
      _englishMarkers.hasMatch(text);

  /// Messages qui embarquent une exception technique (`…: {str(e)}`).
  static bool _looksTechnical(String text) =>
      text.contains('Traceback') ||
      text.contains('Exception') ||
      text.contains('Error(') ||
      RegExp(r'failed: ', caseSensitive: false).hasMatch(text);
}
