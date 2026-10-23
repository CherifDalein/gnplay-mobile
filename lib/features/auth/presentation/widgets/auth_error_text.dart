import '../../../../core/network/api_exception.dart';

/// Message affichable pour une erreur d'authentification.
///
/// `ApiException.message` est déjà en français, mais le filtre générique du
/// socle remplace par un texte neutre certains messages courts du serveur
/// (« Utilisateur inexistant », « Trop de tentatives… »). Pour les routes
/// d'authentification, les 400 / 409 et les 429 « un code vient d'être
/// envoyé » sont écrits pour l'utilisateur (fournisseur d'envoi compris,
/// ex. « Code incorrect — 4 tentative(s) restante(s). ») : on les affiche tels
/// quels.
String authErrorMessage(Object error, {String? notFound}) {
  if (error is! ApiException) return 'Une erreur inattendue est survenue.';

  final detail = error.serverDetail?.trim() ?? '';
  final status = error.statusCode;

  if (status == 404 && notFound != null) return notFound;
  if (detail.isNotEmpty) {
    if (status == 400 || status == 409) return detail;
    // Le 429 de slowapi (« Rate limit exceeded… ») est en anglais.
    if (status == 429 && !error.serverSays('rate limit')) return detail;
  }
  return error.message;
}

/// Compte déjà existant (409 à l'inscription, 400 à la demande de code).
bool isAccountExistsError(Object? error) =>
    error is ApiException &&
    (error.statusCode == 409 ||
        error.serverSays('déjà un compte') ||
        error.serverSays('existe déjà'));

/// Code expiré : à inviter à renvoyer plutôt qu'à resaisir.
bool isExpiredCodeError(Object? error) =>
    error is ApiException &&
    error.statusCode == 400 &&
    error.serverSays('expir');

/// Refus d'un envoi dû au délai entre deux codes (et non à la limite par IP).
bool isCodeCooldownError(Object? error) =>
    error is ApiException &&
    error.kind == ApiErrorKind.rateLimited &&
    !error.serverSays('rate limit');
