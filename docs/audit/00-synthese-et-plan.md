# Audit de la partie créateur — synthèse et plan d'implémentation

Date : 23/10/2026. Sources détaillées (avec fichier:ligne) dans ce dossier :
`01-api.md` (84 routes backend), `02-app-mobile.md` (20 écrans), `03-maquette.md`
(écarts avec « GNPlay Créateur »), `04-frontend-web.md` (ce que fait le site web).
Les points marqués ✔ ont été revérifiés à la main dans le code.

## 1. État des lieux en une page

- **L'app fonctionne de bout en bout** : tous les chemins d'API appelés existent, `flutter analyze`
  est propre, 26 tests passent. Mais plusieurs flux sont fragiles ou trompeurs.
- **Envoi de vidéo cassé au premier essai** ✔ : `upload/init` renvoie `parts[].url`, l'app lit
  `upload_url` (clé de `parts/presign` uniquement). Chaque morceau échoue puis passe par la nouvelle
  tentative. Le test inventait le champ et masquait la panne.
- **« Annuler » pendant le traitement supprime la vidéo** côté serveur (`/abort`) sans confirmation.
- **Navigation instable** : le `GoRouter` est recréé à chaque changement d'auth (formulaire de
  connexion vidé après un échec, redirection post-inscription perdue) ; hors-ligne au démarrage =
  déconnexion.
- **Écrans qui cachent les erreurs** : Notifications, Appareils, opérateurs de retrait affichent un
  état vide au lieu d'une erreur ; le Profil dépend du dashboard (si celui-ci échoue, plus de
  déconnexion possible) ; spinner plein écran à chaque rafraîchissement (Vidéos, Détail, Stats).
- **Statuts vidéo mal interprétés** : le backend n'écrit jamais `published`/`draft` ; une vidéo en
  ligne est `ready` (+ `is_published`), `deleted`/`blocked` s'affichent « Brouillon » et sont
  republiables.
- **Manques fonctionnels** : historique des retraits (API prête, jamais affiché), reprise d'un envoi
  interrompu, progression en octets, compte à rebours OTP réel, pagination/tri du portefeuille.
- **Design** : les 15 écrans créateur existent mais aucun n'est conforme à la maquette (libellés,
  pavé numérique du retrait, toast, feuille de confirmation, onglets segmentés, icônes Material
  interdites). Police Sora non appliquée sur 6 textes ✔ (`fontFamily: 'Sora'` en dur).
- **Dette** : `CreatorRepository` fourre-tout (678 lignes), helpers HTTP dupliqués ×4, pas de timeout
  HTTP, messages d'erreur réseau bruts, ~12 symboles morts, Android encore en `com.example.gnplay`
  avec HTTP clair et signature debug.

## 2. Limites côté API (le mobile doit faire avec, ou il faut toucher au backend)

| # | Constat | Effet pour le créateur | Option |
|---|---|---|---|
| A1 | `POST /videos/{id}/watch-progress` n'est appelé par aucun client ✔ | vues, spectateurs uniques, complétion restent à 0 | à brancher côté **app spectateur / web**, pas créateur (sa propre lecture gonflerait les vues) |
| A2 | Aucune notification pour le créateur (seulement `new_video` aux abonnés) | écran Notifications toujours vide | backend : notifier vente, retrait payé/échoué, vidéo prête/échouée |
| A3 | Pas de route d'envoi de miniature, pas de `GET /videos/{id}` | champ miniature inutile, détail reconstruit depuis `/videos/mine` | retirer le champ ; ou ajouter la route |
| A4 | Recharge : redirection après paiement vers le site web, échecs jamais enregistrés (reste `pending`) | l'utilisateur atterrit sur le web ; statut « en attente » éternel en cas d'échec | backend : deep link / page neutre + webhook d'échec |
| A5 | Devise : recharge forcée en XOF, minimum de retrait en GNF pour la Guinée, le mobile affiche « GNF » en dur | montants potentiellement faux | **à trancher** (voir §5) |
| A6 | `PATCH /users/me` → 500 si `page_name` déjà pris ou `full_name` < 6 car. ; `upload/init` → 500 au-delà de 2 Go ; `retry-transcode` peut laisser `queued` | erreurs 500 opaques | le mobile valide en amont ; correctifs backend à prévoir |
| A7 | Statut de retrait mis à jour seulement via `GET /payouts/{id}` (pas de webhook) | un retrait reste « en cours » tant qu'on n'ouvre pas son détail | le mobile rafraîchit les retraits en cours ; webhook backend à terme |
| A8 | Limite d'appareils : le backend **désactive le plus ancien** au lieu de bloquer ✔ | textes « limite de 3 atteinte » obsolètes | corriger les textes |
| A9 | Erreurs 429 au format `{"error": …}` (pas `detail`), messages backend en anglais | message brut ou générique | le mobile traduit les erreurs connues |

## 3. Plan d'implémentation

Principe : un **socle commun** d'abord (sinon chaque écran réinvente la même chose), puis **écran par
écran**, chacun livré avec ses tests, vérifié dans l'app (Linux et émulateur) puis commité.

### Lot 0 — Socle (transverse)

1. **Contrat d'upload** : lire `url` *ou* `upload_url` ; test basé sur la vraie réponse du backend.
2. **Couche réseau** : `ApiClient` unique (base URL, en-têtes, timeouts, décodage UTF-8, extraction
   `detail`/`error`, traduction FR des erreurs connues et des erreurs réseau) ; découpage de
   `CreatorRepository` en `VideoRepository`, `UploadRepository`, `WalletRepository`,
   `PayoutRepository`, `AnalyticsRepository`, `UserRepository`.
3. **Auth et routeur** : `GoRouter` créé une seule fois (`refreshListenable`), `bootstrap()` ne
   déconnecte que si le refresh est refusé (pas hors-ligne), une seule source de jeton, rôle connu
   au démarrage (`/users/me` → `currentUserProvider`) pour router viewer/créateur.
4. **Modèle vidéo** : statuts réels (`queued/uploading/processing/ready/failed/deleted/blocked`),
   libellés de la maquette (« En ligne », « Masquée », « En traitement », « Échec »), vidéos
   supprimées/bloquées non republiables.
5. **Design system** : police Sora corrigée, jeu d'icônes `GnLineIcon` complet (fin des
   `Icons.*`), et composants manquants : en-tête d'écran avec retour, toast, feuille de confirmation,
   onglets segmentés, chips, barre de recherche, bandeaux info/alerte, pavé numérique, états
   chargement/erreur/vide uniformes (sans spinner plein écran au rafraîchissement).
6. **Android** : `applicationId` définitif, HTTP clair désactivé, libellés ; `flutter_localizations` FR.

Tests : unitaires `ApiClient` (timeouts, 401, 429, 422, erreurs réseau), contrats JSON de chaque
repository à partir de réponses copiées du backend, routeur (redirections viewer/créateur/hors-ligne),
widgets du design system.

### Lots écran par écran (ordre proposé)

| Lot | Écrans | Points principaux |
|---|---|---|
| 1 | Connexion, Inscription + OTP, Mot de passe oublié | OTP NG Messaging, vrai compte à rebours + renvoi, reprise si `register` échoue après l'OTP, erreurs en français |
| 2 | Devenir créateur | confirmation, retour, routage après activation |
| 3 | Tableau de bord | un seul chargement léger (pas toutes les vidéos), cloche + badge, libellés exacts |
| 4 | Mon contenu (liste) | onglets/chips de la maquette, recherche, rafraîchissement sans spinner plein écran, relance du traitement |
| 5 | Détail vidéo, aperçu, lecteur complet | édition validée (prix, titre), suppression avec feuille de confirmation, statuts réels, lecteur (contrôles, buffering, expiration) |
| 6 | Statistiques vidéo | sélecteur « Changer », libellés de la maquette |
| 7 | Publier (upload) | reprise d'envoi interrompu, progression en octets + vitesse, annulation sans suppression silencieuse, sondage borné, retour à l'état initial, suppression du champ miniature |
| 8 | Portefeuille | historique trié/paginé avec dates locales, historique des retraits, recharge |
| 9 | Demande et suivi de retrait | pavé numérique, opérateurs avec délais, récapitulatif avant débit, erreurs visibles, rafraîchissement du statut |
| 10 | Profil, édition, avatar | indépendant du dashboard, validation `page_name`/nom, avatar avec contrôle taille/format |
| 11 | Appareils, Notifications, Réglages | erreurs visibles, confirmation de révocation, textes d'éviction, tap notification → vidéo, réglages inertes retirés |

Chaque lot : widget tests de l'écran (chargement, erreur, vide, données, actions) avec dépôt simulé
sur des réponses réelles du backend, puis vérification manuelle dans l'app.

### Organisation

- Lot 0 fait par moi (il touche à tout, risque de conflits).
- Lots 1 à 11 : un sous-agent Sonnet par lot, **l'un après l'autre** (ils partagent le design system
  et le routeur), avec une consigne précise (fichiers, comportements, tests attendus) ; je relis
  chaque diff, lance analyse + tests, puis on vérifie l'écran ensemble avant le commit.

## 4. Hors périmètre

Les 13 écrans spectateur de la maquette, les fonctions favoris/playlists/abonnements/téléchargements
hors ligne, l'admin. La fonction Séries reste retirée.

## 5. Décisions (validées le 23/10/2026)

1. **Backend** : on corrige l'API quand c'est la bonne solution (A2, A3, A4, A6, A7), avec tests et
   migration, dans des commits séparés du mobile.
2. **Devise** : celle du pays de l'utilisateur (GNF en Guinée, XOF au Sénégal…), cohérente avec les
   minimums de retrait du backend.
3. **Maquette** : adaptée — on garde l'esprit, la hiérarchie et les composants clés, avec liberté sur
   les textes et composants quand c'est plus pratique ou que l'API diffère.
