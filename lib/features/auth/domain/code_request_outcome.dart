/// Résultat d'une demande de code (inscription ou mot de passe oublié).
enum CodeRequestOutcome {
  /// Code envoyé : le compte à rebours de renvoi démarre.
  sent,

  /// Refus 429 : le compte à rebours repart pour ne pas bloquer l'utilisateur.
  rateLimited,

  /// Autre échec (message dans l'état du contrôleur).
  failed,
}
