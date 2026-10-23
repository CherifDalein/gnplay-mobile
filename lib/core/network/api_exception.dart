/// Nature d'une erreur d'API, pour adapter l'affichage (réessayer, se
/// reconnecter, corriger un champ…) sans analyser le texte du message.
enum ApiErrorKind {
  /// Pas de réseau, serveur injoignable, TLS…
  network,

  /// Délai dépassé côté client.
  timeout,

  /// 401 : session absente ou expirée.
  unauthorized,

  /// 403 : action non autorisée pour ce compte.
  forbidden,

  /// 404.
  notFound,

  /// 400 / 409 / 422 : données refusées par le serveur.
  invalid,

  /// 429 : trop de requêtes.
  rateLimited,

  /// 5xx.
  server,

  /// Réponse inattendue (JSON illisible, champ manquant…).
  unexpected,
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    ApiErrorKind? kind,
    this.serverDetail,
  }) : _kind = kind;

  /// Message prêt à afficher, en français.
  final String message;

  final int? statusCode;

  /// Texte brut renvoyé par le serveur (`detail`), utile pour reconnaître une
  /// erreur précise sans dépendre de sa traduction.
  final String? serverDetail;

  final ApiErrorKind? _kind;

  ApiErrorKind get kind => _kind ?? kindForStatus(statusCode);

  bool get isNetwork =>
      kind == ApiErrorKind.network || kind == ApiErrorKind.timeout;

  static ApiErrorKind kindForStatus(int? statusCode) {
    if (statusCode == null) return ApiErrorKind.unexpected;
    if (statusCode == 401) return ApiErrorKind.unauthorized;
    if (statusCode == 403) return ApiErrorKind.forbidden;
    if (statusCode == 404) return ApiErrorKind.notFound;
    if (statusCode == 429) return ApiErrorKind.rateLimited;
    if (statusCode >= 500) return ApiErrorKind.server;
    if (statusCode >= 400) return ApiErrorKind.invalid;
    return ApiErrorKind.unexpected;
  }

  /// Vrai si le texte brut du serveur contient [fragment] (insensible à la
  /// casse) — pour reconnaître une erreur métier précise.
  bool serverSays(String fragment) =>
      (serverDetail ?? '').toLowerCase().contains(fragment.toLowerCase());

  @override
  String toString() => message;
}
