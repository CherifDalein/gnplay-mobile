# Audit complet — app mobile Flutter « GNPlay Créateur »

Périmètre : `/home/saliou/Bureau/gnplay/gnplay-mobile` (lecture seule, état du disque, y compris les modifs locales non commitées de `main.dart`, `full_video_player_screen.dart`, `video_detail_screen.dart`, `pubspec.yaml`). Backend vérifié dans `/home/saliou/Bureau/gnplay/app`.
Méthode : lecture intégrale de `lib/` (≈ 14 200 lignes avec les tests), recoupement avec `app/api/v1/routes/*.py`, `app/schemas/*.py`, `app/models/*.py`, `app/services/*.py`. Rien n'a été exécuté hormis `flutter analyze`, `flutter test` et `flutter pub outdated`. Les points marqués « à confirmer à l'exécution » découlent d'une lecture de code (et, pour Riverpod, du code source du paquet) mais n'ont pas été observés sur appareil.

Chemins backend cités en abrégé : `videos.py` = `app/api/v1/routes/videos.py`, etc.

---

## 0. État des vérifications

| Commande | Résultat |
|---|---|
| `flutter analyze` | `No issues found!` (21 s). `analysis_options.yaml` exclut `android/ ios/ web/ windows/ macos/ linux/ build/`. |
| `flutter test` | `All tests passed!` — **26 tests** verts (9 fichiers, 1 020 lignes). |
| `flutter pub outdated` | go_router 8.2.0 (dernière 18.1.1), flutter_riverpod 2.6.1 (3.4.3), flutter_secure_storage 9.2.4 (11.2.0), file_picker 11.0.3 (13.1.0), google_fonts 6.3.3 (9.0.0), flutter_lints 5.0.0 (6.0.0). Aucun correctif de sécurité évalué. |

Constat global : base propre côté lint, mais les tests ne couvrent ni le routage/auth, ni les contrôleurs (upload, top-up, retrait), ni 3 des 4 repositories ; et **un test valide un contrat d'API faux** (§5, P0-1).

---

## 1. Carte des routes (`lib/core/router/app_router.dart`)

Garde unique : `redirect` (L29-59). `initialLocation: '/splash'` (L28).

| # | Chemin | Écran | Shell à onglets ? | Garde / comportement |
|---|---|---|---|---|
| 1 | `/splash` | `SplashScreen` (L62-64) | non | Toujours affiché tant que `authState.isLoading` (L38-40). Si authentifié → `/home` (ou `postAuthRedirect`) (L48-56). |
| 2 | `/login` | `LoginScreen` (L66) | non | Non connecté : autorisé. Connecté : → `/home` (L48-56). |
| 3 | `/register` | `RegisterScreen` (L67-70) | non | idem `/login` (« auth-only », L33). |
| 4 | `/forgot-password` | `ForgotPasswordScreen` (L71-73) | non | « Public » (L36) : accessible aussi connecté (depuis Réglages). |
| 5 | `/become-creator` | `BecomeCreatorScreen` (L75-77) | non | Connecté requis ; **aucune garde de rôle** (un créateur peut l'ouvrir). |
| 6 | `/devices` | `DevicesScreen` (L79-81) | non | connecté requis |
| 7 | `/notifications` | `NotificationsScreen` (L83-85) | non | connecté requis |
| 8 | `/settings` | `SettingsScreen` (L87-89) | non | connecté requis |
| 9 | `/payout` | `PayoutRequestScreen` (L91-93) | non | connecté requis (pas de garde rôle : un viewer reçoit 403 API) |
| 10 | `/payout/:payoutId` | `PayoutDetailScreen` (L95-98) | non | `pathParameters['payoutId']!` |
| 11 | `/videos/:videoId/stats` | `VideoStatsScreen` (L100-103) | non | déclarée **avant** `/videos/:videoId` (OK) |
| 12 | `/videos/:videoId` | `VideoDetailScreen` (L105-108) | non | |
| 13 | `/home` | `CreatorDashboardScreen` (L117-119) | **oui** (branche 0) | |
| 14 | `/videos` | `VideosScreen` (L125-127) | **oui** (branche 1) | |
| 15 | `/publish` | `PublishScreen` (L133-135) | **oui** (branche 2, FAB central) | |
| 16 | `/earnings` | `EarningsScreen` (L141-143) | **oui** (branche 3) | |
| 17 | `/profile` | `ProfileScreen` (L149-151) | **oui** (branche 4) | |

Non routés mais atteints par `Navigator.push` : `FullVideoPlayerScreen` (`video_detail_screen.dart:185-193`, `MaterialPageRoute(fullscreenDialog: true)`) ; feuilles modales `_EditVideoSheet` (`video_detail_screen.dart:994`), `_EditProfileSheet` (`profile_screen.dart:409`), `_TopupSheet` (`topup_sheet.dart:10-22`).

Shell : `StatefulShellRoute.indexedStack` (L109) → `ShellScaffold` (`shared/widgets/shell_scaffold.dart`), `GnBottomNav` 5 items ; `goBranch(index, initialLocation: index == currentIndex)` (L47-50).

Problèmes de routage (détails §2 et §7) :
- **R1 – Le `GoRouter` est reconstruit à chaque changement d'état d'auth** : `routerProvider` fait `ref.watch(authControllerProvider)` (L24) et `ref.watch(postAuthRedirectProvider)` (L25) puis crée un nouveau `GoRouter(initialLocation: '/splash')`. Chaque `state = AsyncLoading()` (login, logout) ou `AsyncError` détruit la pile de navigation, repasse par `/splash`, et **recrée l'écran courant (formulaires vidés)**. Le `GoRouter` précédent n'est jamais `dispose()`é (pas de `ref.onDispose`). Solution standard : `refreshListenable` + `ref.read`. (à confirmer à l'exécution ; mécanisme certain d'après le code.)
- **R2 – `postAuthRedirect` se consomme lui-même** : L50-52 remet le provider à `null` via `Future.microtask` ; comme le routeur *watch* ce provider, cela le reconstruit → nouvelle navigation `/splash` → `/home`. La redirection post-inscription vers `/become-creator` (`register_screen.dart:98`) est donc très probablement écrasée par `/home` (le tableau de bord affiche alors `_NotCreatorYet`, `creator_dashboard_screen.dart:67`). De plus l'écriture du provider en `register_screen.dart:98` reconstruit déjà le routeur *avant* la connexion → bascule temporaire sur `/login`.
- **R3 – `context.go` utilisé pour entrer dans des routes hors shell** (`videos_screen.dart:144`, `creator_dashboard_screen.dart:464`, `video_detail_screen.dart:97`, `video_stats_screen.dart:76`) : la pile devient `[/videos/:id]` seule, le shell (et l'état des onglets) est détruit ; au retour `_goBack` fait `context.go('/videos')` (jamais `/home` même si l'on vient du tableau de bord). Les écrans retraits/appareils/notifications/réglages utilisent `context.push` (cohérence à unifier).
- **R4** – Aucune garde de rôle : `/payout`, `/videos/*`, `/publish`, `/earnings` sont ouverts à un compte viewer (échec API 403 → écran d'erreur).
- **R5** – Pas de route 404 (`errorBuilder`) ni de deep link ; `pathParameters['…']!` sans validation.

---

## 2. Fiches par écran

Convention : `Fichier:ligne`. « OK » = vérifié fonctionnel par lecture.

### 2.1 SplashScreen — `auth/presentation/screens/splash_screen.dart` (25 l.)
- But : attente du `bootstrap()` (refresh du jeton). Atteint au démarrage et à chaque `AsyncLoading` d'auth (R1). Mène à `/login` ou `/home` par redirection.
- API : aucune directement ; `AuthController.bootstrap()` → `POST /api/v1/auth/refresh-token` (`auth_controller.dart:41`).
- États : spinner seul. Aucun timeout : si l'API ne répond pas, splash infini (pas de timeout HTTP, §3).
- Boutons : aucun. A11y : logo sans `semanticLabel` (`gnplay_logo.dart:11`).
- Bug : `bootstrap` efface la session sur **toute** exception (`auth_controller.dart:47-49`) — y compris absence de réseau ou 5xx — alors que `AuthenticatedClient` évite explicitement de déconnecter sur erreur réseau (`authenticated_client.dart:90-92`). Démarrer l'app hors-ligne = déconnexion.

### 2.2 LoginScreen — `login_screen.dart` (261 l.)
- Arrivée : redirection non-connecté, ou `context.go('/login')` depuis forgot/register. Mène à `/home` (redirection), `/forgot-password` (L162), `/register` (L184).
- API : `POST /api/v1/auth/login` (form-urlencoded `username`=téléphone, `password`) via `AuthController.login` (`auth_controller.dart:59`) puis `POST /api/v1/devices/register` en arrière-plan (L96-107). Champs lus : `access_token`, `refresh_token`, `token_type` (existent : `app/schemas/auth.py` `TokenResponse`).
- États : chargement (`isLoading` → bouton), erreur (`ApiException.message` sinon « Une erreur inattendue est survenue. » L56-58), pas de vide/pull-to-refresh (n/a).
- **Bug majeur (R1)** : `login()` met `state = AsyncLoading()` (`auth_controller.dart:57`) → routeur reconstruit → l'écran de connexion est remplacé par le splash puis, en cas d'échec, par une **nouvelle** `LoginScreen` : les contrôleurs téléphone/mot de passe sont perdus, l'utilisateur doit tout retaper après chaque échec ; l'indicateur de chargement du bouton (L155) n'est jamais visible ; `if (!mounted …) return` (L44) court-circuite `context.go('/home')` (L48), la navigation passe par la redirection.
- Autres : `onPressed: _login` non désactivé pendant le chargement (L156) ; validation téléphone = longueur ≥ 9 (L107) sans normalisation du format alors que le backend compare le numéro exact (`auth_service.py:33,189`) — le placeholder « +224 621 45 88 07 » (L102) contient des espaces qui ne matcheront pas ; pas d'erreur réseau dédiée.
- Fallback d'erreur mal libellé : `AuthRepository._extractErrorMessage` renvoie « La creation du compte a echoue. » (`auth_repository.dart:329`) pour toute erreur sans `detail`, y compris à la connexion.
- UX/a11y : bascule « Voir / Masquer » = `TextButton` minuscule (L127-139) ; pas d'`autofillHints`, pas de `AutofillGroup` ; message d'erreur non annoncé (pas de `Semantics(liveRegion)`).

### 2.3 RegisterScreen (2 étapes) — `register_screen.dart` (688 l.)
- Arrivée : `/register` depuis login. Mène à `/login` (retour) ou `/become-creator` / `/home` (L116, mais voir R2).
- API : `POST /auth/request-otp` (`otp_type: register`, 201 attendu — `auth.py:27`), `POST /auth/verify-otp` (204), `POST /auth/register` (201), puis `POST /auth/login` + `POST /devices/register`. Champs lus de la réponse register : `UserRead` (`id, full_name, phone_number, role, is_active, is_superuser, is_verified, created_at, updated_at, bio, avatar, page_name` — tous présents dans `app/schemas/auth.py`).
- États : `registerState.isLoading || authState.isLoading` (L123) ; erreurs via `registerController` (non `autoDispose`, `register_controller.dart:8` → l'erreur persiste d'une visite à l'autre).
- **Boutons/données en dur** :
  - « Renvoyer le code dans **00:45** » (L384-386) : compte à rebours **factice** (texte statique) ; le bouton renvoie immédiatement l'OTP (`_resendOtp` L65-70) et le backend refuse < 1 min (429 « Trop de tentatives, ressayez dans 1min », `auth_service.py:68`).
  - Champ « Pays » : `_CountryField` (L557-593) avec chevron « ⌄ » → **non interactif**, pays figé `GN`/« Guinée (GNF) » (L34-35).
- **Flux fragile** : `_createAccount` enchaîne `verifyOtp` (marque l'OTP `is_used`, `auth_service.py:134-136`) puis `register` (L79-93). Si `register` échoue (409, 422, réseau), un second clic refait `verify-otp` → « OTP Invalide ou Déjà expiré » : l'utilisateur est bloqué et doit redemander un code (aucun chemin « réessayer seulement register »).
- Redirection post-inscription : voir R2 (L98 écrit le provider *avant* la connexion → routeur reconstruit → bascule sur `/login`, puis `/home` probable au lieu de `/become-creator`). `if (!mounted) return` (L106) est toujours vrai dans ce scénario.
- Validation : nom ≥ 6 (conforme `UserBase.full_name min_length=6`), mot de passe ≥ 4 (conforme `UserCreate`), téléphone ≥ 9. Pas de confirmation du mot de passe. Longueur OTP en dur à 6 (L452, 533, 362) alors que le backend la lit de `settings.OTP_CODE_LENGTH`.
- Champ OTP : `TextFormField` à `Opacity(0.01)` posé sur les cases (L518-541) → invisible aux lecteurs d'écran, pas d'`AutofillHints.oneTimeCode`, `_setError` passe par `addPostFrameCallback` (L459-470).
- Libellé « Étape 1 sur 2 · vos informations » (L249) OK ; message « Votre compte est créé en tant que spectateur. Vous pourrez passer créateur juste après. » (L407-412).

### 2.4 ForgotPasswordScreen — `forgot_password_screen.dart` (186 l.)
- Arrivée : login (L162) ou Réglages « Changer le mot de passe » (`settings_screen.dart:45`). Mène à `/login` (L54, L183).
- API : `POST /auth/request-password-reset` (202 attendu, `auth.py:67`), `POST /auth/reset-password` (204). Contrôleur `autoDispose` (OK).
- États : chargement/erreur OK ; **aucun retour si téléphone invalide** (`_requestCode` L150-153 retourne silencieusement), idem code/mot de passe vides (`_confirm` L163-167).
- Manques : pas de renvoi de code, pas de compte à rebours, pas de validation de longueur de code (placeholder « Code à 6 chiffres »), pas de bascule d'affichage du nouveau mot de passe, pas de confirmation, pas de validation min 4 caractères. Le message d'erreur de l'étape 1 persiste à l'étape 2.
- Navigation : la flèche retour fait toujours `context.go('/login')` (L54) même si l'on vient des Réglages (utilisateur connecté → rebond `/home`) ; `ConstrainedBox(maxWidth: 430)` non centré (L49) → colonne collée à gauche sur grand écran.
- Après succès l'utilisateur déjà connecté n'est pas déconnecté : la session précédente reste valide.

### 2.5 BecomeCreatorScreen — `creator/presentation/screens/become_creator_screen.dart` (253 l.)
- Arrivée : `context.go('/become-creator')` depuis `_NotCreatorYet` (dashboard L398) ou post-inscription. Mène à `/publish` (L68).
- API : `POST /api/v1/users/me/become-creator` → `UserRead` (users.py:34). OK. Invalide `creatorDashboardProvider` (`become_creator_controller.dart:28`).
- États : chargement (bouton), erreur (`ApiException.message` sinon « Une erreur inattendue… » L461-465). Contrôleur non `autoDispose` : erreur et `AsyncData(user)` persistants.
- UX : **aucun bouton retour / aucune sortie** (pas d'AppBar, pas d'« Annuler »), alors que l'écran dit « Cette action est définitive. » (L74) sans demander de confirmation. Un compte `admin` voit « Devenir créateur » mais le backend refuse (`user_service.py:53+`).
- Bug dashboard associé : un admin reçoit 403 sur `/payouts/balance` (`payouts.py:22` n'autorise que `CREATOR`) → le dashboard affiche `_NotCreatorYet` alors que `isCreator` vaut vrai pour admin (`user_read.dart:30`).

### 2.6 CreatorDashboardScreen (onglet Accueil) — `creator_dashboard_screen.dart` (607 l.)
- Arrivée : `/home`. Mène à `/notifications` (L146, `push`), `/earnings` (L290, `go`), `/videos` (L47, `go`), `/videos/:id` (L464, `go`), `/become-creator` (L398).
- Providers : `creatorDashboardProvider` (autoDispose) → `CreatorRepository.loadDashboard()` = **séquentiel** `GET /users/me`, `GET /creators/me/analytics`, `GET /payouts/balance`, puis `GET /videos/mine?limit=100&offset=…` en boucle jusqu'à épuisement (creator_repository.dart:30-46, 82-96) ; `unreadNotificationCountProvider` → `GET /notifications/unread-count`.
- Champs lus ↔ backend : `analytics.total_videos,total_views,total_followers,revenue_total,revenue_this_month,top_videos[]` ✔ (`analytics.py:64-110`) ; `payouts/balance.wallet_balance, withdrawable_balance` ✔ (`payout_service.py:82-88`) ; `UserRead` ✔ ; `unread_count` ✔.
- États : chargement ✔ (`GnLoadingState`), erreur ✔ (`GnAsyncError` + Réessayer), 403 → `_NotCreatorYet`, vide (`_NoVideosYet`), pull-to-refresh ✔ (L32, `.when` avec `skipLoadingOnRefresh` par défaut → pas de clignotement). Après mutation : invalidé par vidéo/retrait/topup/profil ✔. **Le compteur de notifications n'est pas invalidé par le pull-to-refresh** (L32) ni jamais re-sondé.
- Boutons : tous câblés. « Vidéos publiées » (L342) affiche `analytics.totalVideos` = **toutes** les vidéos du créateur, tous statuts (`analytics.py:68-70`) → libellé trompeur. Cloche : `GestureDetector` 40×40 (L145-195), sous les 48 dp, mais `Semantics` présent ✔.
- Perf : charge toutes les vidéos (jusqu'à 5 000, `_maxVideoPages = 50`) pour fusionner miniature+revenu de 5 top vidéos (L589-622). Appels en série (4 allers-retours) au lieu de `Future.wait`.
- Devise « GNF » en dur (L256 + `formatMoney`), alors que le backend raisonne en devise du pays (`payout_service.py:106-108`).
- `Image.network(video.thumbnailUrl!)` sans `errorBuilder`/`loadingBuilder` (L478) — contrairement à `GnVideoThumbnail`. `_StripePainter` dupliqué (L588 et `creator_content_widgets.dart:390`).
- L'avatar n'est pas affiché (initiales uniquement, L110-117) même si `user.avatar` existe.

### 2.7 VideosScreen (onglet Vidéos) — `videos/presentation/screens/videos_screen.dart` (706 l.)
- Arrivée : onglet ; « Tout voir » du dashboard. Mène à `/publish` (L77), `/videos/:id` (L144, `go`).
- Providers/API : `creatorVideosProvider` → `GET /videos/mine?limit=100&offset=N` (toutes les pages) ; mutations `videoMutationControllerProvider` : `PATCH /videos/{id}` (`is_published`), `POST /internal/videos/{id}/retry-transcode` (existe : `videos.py:1158`, autorisé propriétaire/admin ✔).
- Champs lus ↔ backend `VideoWithStatsResponse` : `id,title,description,thumbnail_url,preview_url,price,duration,status,is_published,view_count,likes_count,revenue,created_at,updated_at` ✔.
- États : chargement/erreur/vide/« Aucun résultat » ✔ ; pull-to-refresh ✔ (L175-182).
- **Bug (à confirmer à l'exécution, mécanisme vérifié dans `riverpod-2.6.1/common.dart:597`)** : le `switch (videosState)` (L94-101) teste `AsyncData(:final value)` ; pendant un rechargement (`ref.invalidate`/`refresh`) l'état est un `AsyncLoading` *avec* valeur précédente, qui ne correspond pas à `AsyncData` → branche `_ => GnLoadingState()`. Conséquence : la liste est remplacée par un spinner (scroll perdu) à **chaque** pull-to-refresh, après chaque bascule de publication, et toutes les 6 s tant qu'une vidéo est en traitement (poller L37-42). Même défaut dans `video_detail_screen.dart:87-117` et `video_stats_screen.dart:42-63`.
- Poller `Timer.periodic(6 s)` (L37) actif tant que l'onglet existe (IndexedStack) même quand un autre onglet est affiché ; relance tout le téléchargement de toutes les pages. `Timer` annulé en `dispose` ✔.
- Statuts : `isDraft` = `!isPublished && !isProcessing && !isFailed` (`video_with_stats.dart:48`) → les vidéos `blocked` et `deleted` apparaissent comme « Brouillon ». Or `/videos/mine` renvoie **tous** statuts (`videos.py:553-575`, aucun filtre) et `DELETE /videos/{id}` d'une vidéo déjà achetée ne fait qu'un soft-delete `status=DELETED` (`videos.py:511-523`) : la vidéo « supprimée » **réapparaît** dans « Mon contenu » en « Brouillon », avec un interrupteur qui peut la republier (`update_video` n'interdit pas `is_published=True` sur `deleted`, `videos.py:446-455`).
- Boutons : « Réessayer » (L582) 30 px de haut ; interrupteur désactivé si traitement/échec ✔ ; dépublier sans confirmation (L148).
- Divers : `durationLabel: formatDurationShort(video.duration)` affiche « 0 min » pour une vidéo en cours de traitement (durée 0 → `gn_formatters.dart:32-34`) (L492) ; `ListView(children: …map)` non paresseux (L138-151) ; recherche sans debounce (local, OK) ; erreurs en snackbar `'$error'` brut (L199).

### 2.8 VideoDetailScreen — `video_detail_screen.dart` (1 129 l.) + `_PreviewHero` + `_EditVideoSheet`
- Arrivée : liste/dashboard (`go`). Mène à `FullVideoPlayerScreen` (`Navigator.push`), `/videos/:id/stats` (L97, `go`), `/videos` (suppression L181, retour L199).
- Providers/API : `videoByIdProvider` (dérivé de la **liste complète** `creatorVideosProvider` → pas d'appel `GET /videos/{id}` ; ouvrir une vidéo recharge toutes les pages), `videoAnalyticsProvider` → `GET /videos/{id}/analytics` ✔ (`analytics.py:18-61` : `views, unique_viewers, completed_views, average_completion_rate, likes_count, purchases_count, revenue`), mutations `PATCH`, `DELETE /videos/{id}`, `POST /internal/videos/{id}/retry-transcode`.
- États : chargement/erreur/« Cette vidéo n'existe plus » ✔ ; pull-to-refresh ✔ ; analytics a sa propre erreur/retry (L383-405) ✔ ; après mutation : invalide liste + analytics + dashboard ✔.
- **Bug** : `switch` sur `AsyncData` (L87-117) → spinner plein écran à chaque rechargement (voir §2.7) ; pendant le traitement le poller (L39-49, `Timer` 5 s) recharge toute la liste → l'écran et son lecteur d'aperçu sont démontés/remontés toutes les 5 s. `_scheduleProcessingPoll` est appelé **dans `build`** via `whenData` (L72) (effet de bord en build).
- Aperçu 15 s (`_PreviewHeroState`) : `VideoPlayerController.networkUrl(previewUrl)`, lecture auto muette en boucle. Pas de `mounted` avant `setState` après `await controller.setVolume` dans `_toggleMute` (L525-533). Erreur brute `'$_error'` affichée (L621). Libellés d'état OK (« aperçu en cours de génération… »).
- Boutons : « Modifier » ✔, « Voir la vidéo complète » (désactivé si traitement/échec ✔), « Voir les statistiques détaillées » ✔, interrupteur publication ✔ (sans confirmation), « Supprimer la vidéo » ✔ avec `AlertDialog` (L138-169) mais le message n'indique que le titre : pas d'avertissement irréversible/« conservée si déjà achetée ».
- Feuille d'édition (L994-1106) : champs titre/description/prix/miniature. Problèmes : titre vide → `return` **silencieux** (L1088-1090) ; prix vide ou invalide → `?? 0` (L1098) = la vidéo devient **gratuite** sans avertissement ; envoie toujours tous les champs (y compris `thumbnail_url: ''`, L1099) ; pas de `SingleChildScrollView` → débordement probable clavier ouvert sur petits écrans (Column `mainAxisSize.min` L1044-1081) ; erreurs affichées en snackbar de l'écran parent (L59-67), probablement masquée par la feuille modale.
- Textes : « publiée le {date} » même pour un brouillon (L812) ; `_formatDate` sans année (L1112-1129) ; libellé « Revenu GNF » (L865).
- Mixité : interrupteur `GnContentSwitch` sans `Semantics`.

### 2.9 FullVideoPlayerScreen — `full_video_player_screen.dart` (381 l., modifié localement)
- Arrivée : bouton « Voir la vidéo complète » (push plein écran). Mène : fermeture (`Navigator.pop`), `/devices` (L62).
- Providers/API : `videoPlaybackAccessProvider(videoId)` → `POST /videos/{id}/playback-session?device_id=…` (✔ `streaming.py:64` ; réponse `token, expires_at, watermark` ✔) puis lecture HLS `GET /stream/{id}/master.m3u8?token=…`. Sur 403 « device » : `POST /devices/register` puis nouvel essai (`creator_content_provider.dart:55-88`).
- États : chargement, erreur (+ Réessayer), lecture ✔. Filigrane animé (timer 5 s annulé en `dispose` ✔).
- Problèmes : (a) `_isDeviceLimitError` (L377-381) teste `400` + « maximum of 3 » — **branche morte** : le backend évince désormais l'appareil le plus ancien au lieu de refuser (`devices.py:35-47`) ; le texte « limite de 3 appareils… Révoquez-en un » (L52) est obsolète. (b) `ref.watch(...)` utilisé après un `await` dans le provider (`creator_content_provider.dart:73-82`) → `ref.read` attendu. (c) `access.expiresAt` jamais exploité (session 2 h, `streaming.py` `timedelta(hours=2)`) : aucune reprise à l'expiration. (d) pas de contrôles (pas de barre « tap pour afficher », pas de plein écran/rotation, pas d'indicateur de buffering, pas de maintien d'écran allumé) ; bouton lecture central tapable même invisible (opacité 0). (e) bouton fermer 40×40 (L363-372). (f) erreurs brutes `'$error'` (L53, L259). (g) `VideoPlayerMediaKit.ensureInitialized(linux: true)` (`main.dart:12`) OK pour Linux.
- Le titre est tronqué sur 1 ligne (OK).

### 2.10 VideoStatsScreen — `video_stats_screen.dart` (263 l.)
- Arrivée : détail vidéo. Mène : retour (`pop` ou `go('/videos/:id')`).
- API : `videoByIdProvider` (liste complète) + `GET /videos/{id}/analytics` ✔.
- États : chargement/erreur/« n'existe plus » ✔ ; pull-to-refresh : invalide liste + analytics mais n'attend que la liste (L30-35).
- `_VideoPickerTile` (L155-179) : nom suggère un sélecteur de vidéo, c'est une simple carte statique (pas de chevron, pas d'action) ; bouton retour 32×32 `shrinkWrap` (L133-141) ; `switch` `AsyncData` → spinner au rechargement (voir §2.7). Revenu formaté « GNF » ; note « net de commission » ✔ (conforme `analytics.py` « part créateur déjà nette »).
- `GnCompletionRing` : `completionPercent` gère 0-1 et 0-100 (`video_analytics.dart:24-29`) — le backend renvoie 0-1 ✔.

### 2.11 PublishScreen (onglet Publier) — `publish/presentation/screens/publish_screen.dart` (626 l.) + `VideoUploadController`
- Arrivée : onglet FAB ; `BecomeCreator` ; « Publier » de la liste. Mène : `/videos` (L111, L183).
- API (via `VideoUploadController`, `creator_content_provider.dart:166-385`) : `POST /videos/upload/init` → `PUT <url présignée R2>` ×N (3 workers) → `POST /videos/upload/{id}/parts/confirm` par part → `POST /videos/upload/{id}/complete` (202) → boucle `GET /videos/{id}/processing-status` toutes les 2 s ; reprise `POST /videos/upload/{id}/parts/presign` ; annulation `POST /videos/upload/{id}/abort`. Tous existent côté backend (`videos.py:174, 308, 864, 906, 981, 1016`).
- **P0 – contrat de l'`init` incompatible** : `UploadPartTarget.fromJson` lit `json['upload_url']` (`video_upload_init_response.dart:12`) mais `POST /videos/upload/init` renvoie `parts: [{"part_number", "url"}]` (`videos.py:252-258, 289` via `r2_service.generate_batch_part_urls`, `r2_service.py:218-228`) ; seul `/parts/presign` renvoie `upload_url` (`videos.py:894-899`). Résultat : `uploadUrl == ''` → première tentative de **chaque** part échoue (`creator_content_provider.dart:292-296`), puis 2 s d'attente (L302), re-présignature (L304-311) et seulement la 2ᵉ tentative réussit. L'envoi ne fonctionne que grâce au chemin d'erreur ; si `/parts/presign` échoue (silencieux, L312-314) les 3 essais partent sur une URL vide et l'envoi échoue. Le test `video_upload_flow_test.dart:45,49` invente un champ `upload_url` dans une réponse d'`init` « réelle » → masque le défaut.
- **P0 – annulation destructive** : « Annuler » (L213-223) → `_handleCancel` (L178-185) → `cancel()` (`creator_content_provider.dart:361-372`) appelle `POST …/abort` dès que `isBusy`, **y compris en phase `processing`** ; le backend supprime alors le `Video`, l'upload et les parts (`videos.py:1000-1010`) alors que l'écran dit « vous pouvez fermer l'app » (L601). Aucune confirmation. De plus la boucle `_pollProcessing` (`while (true)`, L344-357) n'est ni interrompue par `cancel()` ni bornée : après abort, le prochain poll reçoit 404 et bascule l'état en `failed` avec un snackbar d'erreur après que l'utilisateur ait annulé.
- États : chaque étape ✔ ; échec → snackbar (L46-55) et retour à l'étape 2 avec formulaire conservé ; **pas de bouton « Réessayer » dédié**, et l'upload échoué laisse une vidéo orpheline `uploading` côté serveur (pas d'`abort` automatique).
- **Bug – état jamais réinitialisé** : `VideoUploadController.reset()` n'est appelé nulle part (grep) ; après `UploadPhase.ready`, l'onglet Publier reste figé sur l'étape 4 « Vidéo prête » (IndexedStack conserve l'écran) ; impossible de publier une seconde vidéo sans tuer l'app. « Voir mon contenu » (L609-612) ne remet pas à zéro non plus.
- **Champ inerte** : « Miniature — URL de l'image » (L453-457) alimente `_thumbnailController` (L24) qui n'est **jamais lu** dans `_startUpload` (L151-176) ni passé à `uploadFile` → la saisie est ignorée. Le bandeau (L478) dit « pas encore disponible côté API — collez une URL en attendant » : trompeur, l'URL n'est pas envoyée.
- **Promesses non tenues** : « l'envoi reprend automatiquement s'il est interrompu » (L324) et « En cas de coupure, l'envoi reprendra où il s'est arrêté » (L534) : seul un retry intra-session par part existe ; rien ne persiste `video_id/upload_id` pour reprendre après fermeture ; `getUploadStatus` (`creator_repository.dart:324`) n'est jamais appelé (le doc `docs/creator-app-design.md` écran 8 prévoit la reprise).
- Validation : titre requis (snackbar L156-165) ; prix `int.tryParse(text) ?? 0` (L174) → champ vide = gratuit, pas de plafond, pas de devise affichée (« Prix », L423) ; `FileType.video` accepte mkv/avi mais `_mimeTypeFor` retombe sur `video/mp4` (`creator_content_provider.dart:374-384`) ; texte « MP4 ou MOV » (L324) alors que `webm` est accepté ; le backend n'autorise que mp4/webm/quicktime (`videos.py:~190`).
- Mémoire : `file.bytes` jamais chargé (pas de `withData`) → lecture par chunks via `RandomAccessFile` ✔ ; 3 chunks de 10 Mo en parallèle OK.
- Autres : icône de l'état « prête » = `chevronRight` (L570) ; `_Header` « Annuler » `TextButton` `padding: zero` (< 48 dp) ; `uploadedParts` mis à jour par plusieurs workers (OK, mono-thread Dart) ; après `cancel()` les workers déjà lancés continuent d'envoyer des parts (aucune vérification d'annulation dans `worker()`, L242-263) et `state = …` peut s'exécuter après `dispose` (assert en debug).
- Dépendance : `uploadFile` appelle `_ref.invalidate(creatorVideosProvider)` ✔ à la fin.

### 2.12 EarningsScreen (onglet Gains) — `earnings/presentation/screens/earnings_screen.dart` (403 l.) + `TopupSheet` (`widgets/topup_sheet.dart`, 256 l.)
- Arrivée : onglet ; « Retirer mes gains » du dashboard. Mène à `/payout` (L105, push), `/payout/:id` (L146, push, via `reference_type == 'payout'`), feuille de recharge.
- API : `creatorDashboardProvider` (4+ appels, juste pour 2 soldes) et `creatorWalletLedgerProvider` → `GET /wallets/transactions` ✔ (`wallets.py:22` renvoie `wallet.ledger_entries` ORM : `amount, direction, transaction_type, reference_id, reference_type, description, created_at` ✔).
- États : chargement/erreur indépendants ✔, vide « Aucune transaction » ✔, pull-to-refresh ✔ (L38-51), après mutation (retrait/recharge) invalidés ✔.
- Problèmes : **l'historique n'est ni trié, ni paginé** (le backend renvoie la relation SQLAlchemy sans `order_by`, `models/wallets.py:17`; le mobile n'ordonne pas, `wallet_ledger_entry.dart`/`creator_wallet_provider.dart`) → ordre arbitraire, liste complète d'un coup dans un `ListView` non paresseux (L141-149) ; la date est un `String` figé au parsing (`dateLabel`, `wallet_ledger_entry.dart:47-55`), en UTC (pas de `toLocal()`), sans heure, avec repli trompeur « Aujourd'hui » si absente ; pas de lien entre un retrait et son historique de retraits (`listPayouts`/`payoutsProvider` jamais affichés → **aucun écran « historique des retraits »**, pourtant prévu par `docs/creator-app-design.md` écrans 9-11) ; `commission` et autres types → `neutral`.
- Info-bulle : `InkWell` 13 px + padding 2 (L207-217) → cible ≈ 17 px, sans `Semantics`/tooltip.
- Recharge : voir §2.13. Libellés « GNF · tout confondu » OK.

### 2.13 TopupSheet + `TopupController` — `topup_sheet.dart`, `creator/presentation/providers/topup_controller.dart`
- API : `POST /payments/topup/initiate` (`payment_url`, `reference` ✔ `payments.py:19-62`) → `launchUrl(externalApplication)` → poll `GET /payments/topup/status/{reference}` toutes les 3 s, 100 fois max (≈ 5 min) ; `didChangeAppLifecycleState(resumed)` force un check ✔ (`topup_sheet.dart:51-55`).
- États : formulaire, attente, succès, échec ✔ ; invalide dashboard + ledger au succès ✔.
- Problèmes : `start()` écrit `state` après deux `await` sans `mounted` (`topup_controller.dart:56-62`) → exception en debug si la feuille est fermée pendant l'appel ; pendant « En attente du paiement » la feuille n'a ni bouton annuler ni « J'ai payé » (fermeture par glissement uniquement, sondage arrêté ; le crédit arrivera quand même) ; les URLs `success/failure` du backend redirigent vers le **site web** (`payments.py:65-75`, `FRONTEND_URL/wallet/callback`), jamais vers l'app (pas de deep link) ; aucun montant minimum/maximum ni devise cohérente (« GNF » en dur, `topup_sheet.dart:168`) ; `Timer.periodic` + `_poll` async peuvent se chevaucher (requêtes simultanées) ; la feuille n'est pas défilable (OK ici car courte).
- Textes : « Payer avec mobile money » / « page de paiement sécurisée DexPay » ✔.

### 2.14 PayoutRequestScreen — `payout_request_screen.dart` (392 l.)
- Arrivée : `/payout` (push). Mène : `pushReplacement('/payout/{id}')` (L307) ; retour `pop`/`go('/earnings')`.
- API : `GET /payouts/balance` (via dashboard), `GET /payouts/providers` ✔ (champs DexPay `provider_short_name, provider_name, provider_country, provider_currency, min_amount, max_amount` — conformes à `skills/dexpay/references/api-reference.md:277-301`), `POST /payouts/request` (`amount, operator, destination_phone` ✔ `PayoutRequestCreate`).
- États : chargement dashboard, erreur ✔ ; opérateurs : spinner puis liste — **en cas d'erreur de `/payouts/providers` (502) l'écran affiche « Aucun opérateur disponible pour votre pays. » (L63-64, L230-234) sans retry** ; 429 géré (L95-97) ✔ ; double-soumission bloquée (`canSubmit … !isLoading`) ✔.
- Validation : minimum de l'opérateur ✔ (L84), solde insuffisant ✔ (L85) ; **`max_amount` ignoré** ; devise de l'opérateur (`provider_currency`) ignorée alors que le libellé est « GNF » en dur (L127, 173, 188) ; « Minimum : 0 GNF » avant chargement des opérateurs (L188) ; téléphone destinataire non validé (L303) ; pas de récapitulatif/confirmation avant un débit irréversible (« Confirmer le retrait » est le seul clic) ; frais jamais affichés (`fees` parsé mais inutilisé).
- Bugs : `payoutControllerProvider` non `autoDispose` (`payout_controller.dart:9`) → l'erreur d'une tentative précédente réapparaît à la réouverture de l'écran ; `_phoneController.text = …` et `_selectedProviderShortName = …` modifiés dans `build` (L68-80) ; extension locale `firstOrNull` (L390-392) redondante avec le SDK (Dart ≥ 3) ; bouton retour 32×32 ; `Tout retirer` sans zone tactile suffisante (L196-209) ; clavier : `ListView` ✔.
- Backend : `GET /payouts/balance`, `/providers`, `/request` exigent le rôle `CREATOR` (admin exclu).

### 2.15 PayoutDetailScreen — `payout_detail_screen.dart` (295 l.)
- Arrivée : `pushReplacement` après demande ; ligne d'historique (retrait/remboursement). Mène : retour.
- API : `GET /payouts/{id}` ✔ (le backend rafraîchit le statut chez DexPay) ; champs lus : `id, amount, fees, status, reference, destination_phone, operator, failure_reason, created_at, processed_at` ✔ (`models/payouts.py`).
- États : chargement ✔ ; **erreur = texte brut `'$error'` sans bouton Réessayer** (L69-80) ; pas de pull-to-refresh ; auto-actualisation 6 s tant que `pending/processing` (L31-41, timer dans `build` via `whenData` L47 ; annulé en `dispose` ✔).
- Affichage : `operator` montré en code brut (`wave_sn_payout`) (L188) ; dates en heure UTC sans `toLocal()` (L215-221) ; référence non copiable ; `fees` non affiché ; statut `failed` → « Montant recrédité à votre portefeuille » ✔ (conforme `payouts.py`/ `_refund_failed_payout`) ; `cancelled` traité comme échec visuel.

### 2.16 ProfileScreen (onglet Profil) — `profile_screen.dart` (506 l.) + `_EditProfileSheet`
- Arrivée : onglet. Mène à `/devices`, `/notifications`, `/settings` (push), `/home` (« Statistiques de la chaîne », L216-219 → simple raccourci vers le dashboard), `/login` (déconnexion).
- API : **tout le profil dépend de `creatorDashboardProvider`** (L47-63) ; `PATCH /users/me` (`full_name, page_name, bio` ✔), `POST /users/me/profile-picture` multipart (`file` ✔, réponse `profile_picture_url` ✔), `POST /auth/logout`.
- **Défaut structurel** : si le dashboard échoue (hors-ligne, 5xx, 403 viewer/admin) l'écran n'affiche que l'erreur : **ni édition de profil, ni appareils, ni réglages, ni bouton « Se déconnecter »** (L49-63). Un compte viewer ne peut pas non plus se déconnecter depuis cet onglet.
- États : pas de pull-to-refresh ; avatar : `NetworkImage` sans `onError` (L296-301) ; upload avatar indicateur ✔ (L313-331) ; aucune validation (taille/format) avant envoi (backend limite `MAX_IMAGE_SIZE`).
- Déconnexion : pas de confirmation (L224-229) ; `AuthController.logout` laisse remonter une exception réseau (`auth_controller.dart:131`, `finally` sans `catch`) → erreur non gérée dans `_logout` (L259-264) alors que la session locale est bien vidée ; routeur reconstruit pendant l'`AsyncLoading` (R1) → splash fugace.
- `_EditProfileSheet` : titre `Nom` vide → retour silencieux (L490-492) ; libellé technique « Identifiant public (page_name) » (L467) ; envoie `page_name: ''`/`bio: ''` quand vidés ; erreurs d'API visibles uniquement par snackbar de l'écran parent (probablement masquée) ; pas de `SingleChildScrollView`.
- Extension `firstOrNull` dupliquée (L267-269).

### 2.17 SettingsScreen — `settings_screen.dart` (264 l.)
- Arrivée : Profil. Mène à `/forgot-password` (L45, `go` → perd la pile), `/login`.
- Éléments **inertes / factices** :
  - Interrupteur « Mode sombre » (L89-105) : `final bool _dark = true` (L18), `onChanged` ne fait que `setState(() {})` + snackbar « Le mode clair arrive dans une prochaine version. » → texte « bientôt », aucun effet.
  - « Conditions générales · Mentions légales » (L114) : texte simple, **pas de lien** ; « version 1.0.0 » en dur.
- API : `POST /auth/logout` (avec `refresh_token`) pour « cet appareil » ; sans `refresh_token` pour « tous les appareils » (`logout_user` révoque tout, `auth_service.py:313-335`) ✔.
- Confirmation : « tous les appareils » ✔ (dialogue L135-165) ; « cet appareil » sans confirmation ; exception réseau non gérée (voir §2.16).
- `padding bottom: 116` inutile (hors shell).

### 2.18 NotificationsScreen — `notifications_screen.dart` (276 l.)
- Arrivée : cloche du dashboard (push) ou Profil. Mène : retour.
- API : `GET /notifications?limit=100&offset=0` ✔ (`id, type, title, body, video_id, read_at, created_at` ✔), `PATCH /notifications/{id}/read` ✔, `PATCH /notifications/read-all` ✔ ; invalide liste + compteur ✔.
- **Pas d'état d'erreur** : `valueOrNull ?? []` (L33-35) → une erreur API s'affiche comme « Aucune notification pour le moment » (L88-89), sans retry ; pull-to-refresh ✔ (L47-50).
- Le tap ne fait que marquer lu (L94-102) : `video_id` ignoré (aucune navigation vers la vidéo) ; limite 100 sans pagination ; libellé relatif simpliste (« il y a 30 j », L184-195 du fichier) ; `ListView(children: map)` non paresseux ; bouton retour 32×32 ; pas de `Semantics` (état lu/non lu = simple point 7 px).
- Doc backend : seul le type `new_video` existe (destiné aux spectateurs) → l'écran sera quasi toujours vide pour un créateur.

### 2.19 DevicesScreen — `devices_screen.dart` (332 l.)
- Arrivée : Profil, ou erreur d'appareil du lecteur. Mène : retour.
- API : `GET /devices` ✔ (`id, device_id, platform, device_name, is_active, last_seen_at` ✔), `DELETE /devices/{id}` ✔ (accepte l'id de ligne ou `device_id`, `devices.py:91+`), pull-to-refresh ✔ (L47-50).
- **Pas d'état d'erreur** (L33-34) : erreur ⇒ « Aucun appareil enregistré / Reconnectez-vous… » (L116-139).
- **Révocation sans confirmation** (L148-150, bouton L277) — action destructive (suppression de la ligne, pas désactivation).
- Texte obsolète : « Limite atteinte. Révoquez un appareil avant d'en connecter un nouveau. » (L98) — faux depuis que `register_device` désactive automatiquement le plus ancien (`devices.py:35-47`). Les appareils `is_active == false` sont listés comme les autres, sans badge « inactif » ; « CET APPAREIL » s'affiche même si l'appareil courant a été évincé ; le bouton « Révoquer » est visible pour l'appareil courant tant que `currentDeviceIdProvider` charge (L35, L276).
- Icône toujours `phone_iphone` (L230) ; `device_name` = `Platform.operatingSystemVersion` (`device_repository.dart:84-89`) → chaîne de version noyau longue affichée comme nom d'appareil.

### 2.20 ShellScaffold / GnBottomNav — `shared/widgets/shell_scaffold.dart`, `gn_bottom_nav.dart`
- Navigation fonctionnelle (5 branches). Barre de 86 px ; zone tactile = colonne entière ✔ ; **aucun `Semantics` (`selected`, label)** ni tooltip ; libellés en `fontSize: 9.5` (illisible avec grande police ; pas de gestion du `textScaler`).
- `MaterialApp.router` (`main.dart:22-28`) : pas de `locale`/`localizationsDelegates` (`flutter_localizations` absent du pubspec) → menus système (copier/coller), info-bulles « Back » et libellés d'accessibilité Material restent en anglais selon la langue du téléphone ; `title: 'Gnplay'`.

### 2.21 Éléments transverses (tous écrans)
- **Erreurs réseau non traduites** : aucun `try/catch` ne convertit `SocketException`/`ClientException`/`TimeoutException` ; `friendlyErrorMessage` (`creator_content_widgets.dart:351-357`) renvoie `error.toString()` → l'utilisateur voit « ClientException with SocketException: Failed host lookup… » dans `GnAsyncError` et les snackbars.
- **Messages backend en anglais** affichés tels quels : « Video not found », « Unsupported video format », « Invalid file size », « Playback is restricted to registered active devices », « Device not found », « Notification not found », « Failed to confirm part… » (`videos.py`, `streaming.py`, `devices.py`, `notifications.py`).
- **Aucun timeout HTTP** (`grep timeout lib` = 0 hors timers) : un serveur qui ne répond pas fige splash / spinners indéfiniment.
- **Accessibilité** : 2 occurrences de `Semantics` dans tout `lib/` (`creator_dashboard_screen.dart:140`, `register_screen.dart:636`), 0 `tooltip` ; boutons retour `IconButton` 32×32 `shrinkWrap` (payout_request:332-336, payout_detail:110-114, video_stats:136-140, settings:198-202, notifications:134-138, devices:183-187) ; `GnContentSwitch` 46×26 (`creator_content_widgets.dart:97-125`) sans sémantique ni zone ≥ 48 ; cloche 40×40 ; textes de 9–11 px nombreux ; couleur `text3 (#6E6E78)` sur fond `#0B0B0D` ≈ contraste 3,9:1 (< 4,5:1 pour du petit texte) — mesure indicative non calculée à l'outil.
- **Confirmations avant action destructive/irréversible** : présentes seulement pour supprimer une vidéo et « déconnecter tous les appareils » ; absentes pour : annuler un upload (publish_screen.dart:70), révoquer un appareil, déconnexion simple, dépublier, confirmer un retrait, devenir créateur.
- **Formats** : montants `formatMoney` → « 1 234 567 GNF » avec espace normale (peut se couper en fin de ligne) (`gn_formatters.dart:14-17`) ; `formatCompact` renvoie « 1,50 M » ; durée `formatDurationShort(0)` = « 0 min » vs « m:ss » ailleurs ; dates construites à la main (pas d'`intl`), pas de `toLocal()`, fuseau UTC.
- **Polices** : `google_fonts` en téléchargement à l'exécution (aucune police embarquée) ; plusieurs `TextStyle` forcent `fontFamily: AppFonts.display` = `'Sora'` (`gn_button.dart:67`, `earnings_screen.dart:358`, `become_creator_screen.dart:137,204`) — ce nom n'est pas celui sous lequel `google_fonts` enregistre la police → repli probable sur la police par défaut (à confirmer visuellement). Hors-ligne au premier lancement : polices de repli.
- **Sources de vérité du jeton** : `AuthController.state` (jeton mémoire, jamais mis à jour après un refresh) vs `TokenStorage` (à jour). Les providers profile/notifications/devices lisent `ref.read(authControllerProvider).valueOrNull` (`device_provider.dart:40-46`, `notification_provider.dart:66-72`, `profile_controller.dart:56-62`), `CreatorRepository` lit `TokenStorage` ; seule la surcharge de `AuthenticatedClient` (remplace par le jeton frais) évite des 401 — redondance fragile.

---

## 3. Couche data

### 3.1 Inventaire des méthodes et endpoints

**`AuthRepository`** (`auth/data/auth_repository.dart`, 331 l.)
| Méthode (ligne) | Appel | Utilisée ? |
|---|---|---|
| `login` (17) | `POST /api/v1/auth/login` (form) | oui (AuthController) |
| `refreshToken` (43) | `POST /auth/refresh-token` | oui (bootstrap) |
| `logout` (63) | `POST /auth/logout` | oui |
| `myInfo` (87) | `GET /users/me` | **jamais utilisée** (doublon de `CreatorRepository._getUser`, L528) |
| `updateProfile` (107) | `PATCH /users/me` | oui |
| `uploadProfilePicture` (137) | `POST /users/me/profile-picture` (multipart) | oui |
| `becomeCreator` (166) | `POST /users/me/become-creator` | oui |
| `requestRegisterOtp` (188) | `POST /auth/request-otp` | oui |
| `verifyRegisterOtp` (206) | `POST /auth/verify-otp` | oui |
| `requestPasswordReset` (231) | `POST /auth/request-password-reset` | oui |
| `resetPassword` (254) | `POST /auth/reset-password` | oui |
| `register` (281) | `POST /auth/register` | oui |

**`DeviceRepository`** (`auth/data/device_repository.dart`, 135 l.) : `registerDevice` (19) `POST /devices/register` ; `listDevices` (40) `GET /devices` ; `revokeDevice` (60) `DELETE /devices/{id}` — tous utilisés.

**`NotificationRepository`** (`profile/data/notification_repository.dart`, 112 l.) : `list` (15) `GET /notifications?limit&offset` ; `unreadCount` (39) `GET /notifications/unread-count` ; `markRead` (56) `PATCH /notifications/{id}/read` ; `markAllRead` (69) `PATCH /notifications/read-all` — tous utilisés.

**`CreatorRepository`** (`creator/data/creator_repository.dart`, 678 l., **23 méthodes publiques**)
| Méthode (ligne) | Appel | Utilisée ? | Testée ? |
|---|---|---|---|
| `loadDashboard` (30) | `GET /users/me` + `GET /creators/me/analytics` + `GET /payouts/balance` + `GET /videos/mine` (pages) | oui | via widget |
| `loadPayoutBalances` (50) | `GET /payouts/balance` | **jamais** | non |
| `listMyVideos` (74) | `GET /videos/mine?limit=100&offset=` | oui | oui |
| `loadVideoAnalytics` (98) | `GET /videos/{id}/analytics` | oui | via widget |
| `loadVideoPlaybackAccess` (125) | `POST /videos/{id}/playback-session?device_id=` | oui | oui |
| `updateVideo` (159) | `PATCH /videos/{id}` | oui | non |
| `deleteVideo` (187) | `DELETE /videos/{id}` | oui | non |
| `initVideoUpload` (201) | `POST /videos/upload/init` | oui | oui (fixture fausse) |
| `presignUploadParts` (232) | `POST /videos/upload/{id}/parts/presign` | oui (repli) | non |
| `uploadChunk` (263) | `PUT <URL R2>` | oui | oui |
| `confirmUploadPart` (282) | `POST /videos/upload/{id}/parts/confirm` | oui | oui |
| `completeUpload` (302) | `POST /videos/upload/{id}/complete` | oui | oui |
| `getUploadStatus` (324) | `GET /videos/upload/{id}/status` | **jamais** | non |
| `abortUpload` (338) | `POST /videos/upload/{id}/abort` | oui | non |
| `retryTranscode` (352) | `POST /internal/videos/{id}/retry-transcode` | oui | oui |
| `getProcessingStatus` (366) | `GET /videos/{id}/processing-status` | oui | oui |
| `loadWalletLedger` (382) | `GET /wallets/transactions` | oui | via widget |
| `requestPayout` (401) | `POST /payouts/request` | oui | non |
| `initiateTopup` (428) | `POST /payments/topup/initiate` | oui | oui |
| `getTopupStatus` (449) | `GET /payments/topup/status/{ref}` | oui | oui |
| `listPayoutProviders` (464) | `GET /payouts/providers` | oui | non |
| `listPayouts` (485) | `GET /payouts` | via `payoutsProvider` **jamais observé** (seulement invalidé, `payout_controller.dart:37`) | non |
| `getPayout` (506) | `GET /payouts/{id}` | oui | non |

Tous les chemins appelés existent côté backend. Aucun appel mobile vers une route inexistante n'a été trouvé. Non utilisés côté mobile mais disponibles : `GET /wallets/balance`, `GET /videos/{id}/access`, `POST /videos/{id}/purchase`, `GET /feed`, etc. (hors périmètre créateur).

### 3.2 Doublons de logique
Quatre repositories réimplémentent chacun les mêmes helpers :
- `_authHeaders` : `device_repository.dart:92`, `notification_repository.dart:80`, `creator_repository.dart:624` (+ headers inline dans `auth_repository.dart:70,91,117,143,172`).
- `_isSuccess` : `device_repository.dart:99`, `notification_repository.dart:87`, `creator_repository.dart:635` (inline `>= 200 && < 300` ×12 dans `auth_repository.dart` et `authenticated_client.dart:94`).
- `_decodeObject` : `auth_repository.dart:299`, `device_repository.dart:103`, `creator_repository.dart:639` (messages différents « Reponse API invalide. » / « Réponse API invalide. »).
- `_extractErrorMessage` : `auth_repository.dart:307` (gère `detail` liste), `creator_repository.dart:654` (idem), `device_repository.dart:121` et `notification_repository.dart:98` (ne gèrent **pas** `detail: [ {msg} ]` des 422) ; **chaînes sans accents/divergentes** : « Reponse API invalide. » (`auth_repository.dart:304`, `creator_repository.dart:644`), « Impossible de lire la reponse du serveur. » (`auth_repository.dart:326`, `creator_repository.dart:673`), « La requete a echoue. » (`creator_repository.dart:676`), « La creation du compte a echoue. » (`auth_repository.dart:329`, utilisé aussi pour login/OTP/reset), versus version accentuée dans device/notification repos.
- Incohérence d'API interne : `Auth/Device/Notification` prennent `accessToken` en paramètre ; `CreatorRepository` le lit dans `TokenStorage` ; tous reposent pourtant sur `AuthenticatedClient` qui réécrit l'en-tête.
- Pas de timeout, pas de journalisation, pas de traduction des exceptions réseau (voir §2.21).
- `jsonDecode(response.body)` direct sans protection `FormatException` sur les chemins succès (`creator_repository.dart:393, 475, 496, 565`, `device_repository.dart:50`).
- Constantes d'URL : `'${ApiConfig.baseUrl}/api/v1/…'` répété ≈ 40 fois ; un seul usage de `_apiUri` (resolve) dans `creator_repository.dart:131,148`.
- `AuthenticatedClient` : requêtes multipart non rejouables (`authenticated_client.dart:46-48`) → l'envoi de photo de profil avec un jeton expiré échoue en 401 sans tentative de refresh ; le corps de `logout` embarque l'ancien refresh token capturé avant rotation (rejeu après refresh → l'ancien jeton est déjà révoqué ; sans conséquence grave car `logout_user` ignore une session introuvable, mais la session courante n'est pas révoquée dans ce cas).

### 3.3 « God class » `CreatorRepository` et proposition de découpage
678 lignes, 23 méthodes publiques, 5 domaines mélangés (dashboard/analytics, vidéos, upload multipart, portefeuille/top-up, retraits) + utilitaires HTTP privés. Proposition (un fichier par domaine, injection d'un `ApiClient` partagé) :

| Nouveau module | Méthodes déplacées |
|---|---|
| `core/network/api_client.dart` (nouveau) | headers, `get/post/patch/delete` JSON, décodage, `_extractErrorMessage` unique, timeout, traduction `SocketException/TimeoutException → ApiException('Connexion impossible…')` |
| `videos/data/video_repository.dart` | `listMyVideos`, `updateVideo`, `deleteVideo`, `retryTranscode`, `loadVideoAnalytics`, `loadVideoPlaybackAccess` |
| `publish/data/upload_repository.dart` | `initVideoUpload`, `presignUploadParts`, `uploadChunk`, `confirmUploadPart`, `completeUpload`, `getUploadStatus`, `abortUpload`, `getProcessingStatus` |
| `earnings/data/wallet_repository.dart` | `loadWalletLedger`, `loadPayoutBalances`, `initiateTopup`, `getTopupStatus` |
| `earnings/data/payout_repository.dart` | `listPayoutProviders`, `requestPayout`, `listPayouts`, `getPayout` |
| `creator/data/creator_stats_repository.dart` | `loadDashboard` (via `Future.wait`), `_getAnalytics`, `_mergeTopVideos` ; déplacer `_getUser` vers `AuthRepository.myInfo` (déjà existant) |

Les providers (`creator_content_provider.dart`, 385 l. — mélange lecture, mutations, upload, lecteur) devraient suivre le même découpage ; `VideoUploadController` mérite son propre fichier.

---

## 4. Modèles domain : champs parsés vs disponibles, parseurs fragiles

| Modèle (fichier) | Champs lus | Champs API non lus | Fragilité |
|---|---|---|---|
| `UserRead` (`auth/domain/user_read.dart:42-57`) | tous (`id, full_name, phone_number, role, is_active, is_superuser, is_verified, created_at, updated_at, bio, avatar, page_name`) | — | **`as String` / `as bool` / `DateTime.parse(… as String)` sans garde** : `TypeError` si champ absent/null ; un seul champ manquant fait échouer tout `loadDashboard` donc dashboard + profil + retraits |
| `TokenResponse` (`token_response.dart:13-17`) | `access_token, refresh_token, token_type` | — | `as String` (acceptable : champs obligatoires) |
| `TopVideo` (`creator/domain/top_video.dart:19-26`) | `video_id, title, view_count, likes_count` + **`revenue`, `thumbnail_url` (n'existent pas dans `TopVideoResponse`, `schemas/analytics.py`)** | — | `as String` sur `video_id`/`title`, `as int?` (plante si `num` non entier) ; champs fantômes toujours défaut, comblés par `_mergeTopVideos` |
| `CreatorAnalytics` (`creator_analytics.dart:24-28`) | tous | — | `as int?` au lieu de `jsonInt` (incohérent avec le reste) |
| `VideoWithStats` (`video_with_stats.dart:63-86`) | tous sauf `user_id` | `user_id` | **fabrique des valeurs** : `createdAt/updatedAt ?? DateTime.now()` (L65, 83-84), `title` « Vidéo sans titre », `status` déduit ; ne connaît pas les statuts `draft`, `blocked`, `deleted` (backend `enums/videos.py`) |
| `VideoAnalytics` | tous | — | robuste (`jsonInt/jsonDouble`) |
| `VideoPlaybackAccess` | `token → url`, `watermark`, `expires_at` | — | `expiresAt` jamais utilisé |
| `VideoUploadInitResponse`/`UploadPartTarget` (`video_upload_init_response.dart`) | `video_id, upload_id, object_key, chunk_size, total_parts, max_parallel_uploads, expires_in, parts[].part_number, parts[].upload_url` | **`parts[].url` (réel), `file_key`, `part_size`** | **clé `upload_url` fausse pour l'init** (P0-1) ; `max_parallel_uploads` lu mais ignoré (constante `_maxParallelUploads = 3`, `creator_content_provider.dart:164`) |
| `UploadStatusResponse` | `video_id, status, upload_id, chunk_size, total_parts, uploaded_parts, missing_parts` | `expires_at` | classe entière **inutilisée** (méthode jamais appelée) |
| `ProcessingStatusResponse` (L99-126) | `video_id, status, progress, attempts, error_message` | — | `isDone` teste `'completed' \|\| 'ready'` : le job ne produit que `queued/processing/ready/failed/not_started` (`workers/video_processing.py:70,311,371`, `videos.py:40,1033`) → `not_started` (aucun job) boucle indéfiniment dans `_pollProcessing` (pas de plafond) |
| `WalletLedgerEntry` (`wallet_ledger_entry.dart:25-45`) | `description, created_at, amount, direction, transaction_type, reference_type, reference_id` | `id`, `wallet_id`, `user_id`, heure de `created_at` | `dateLabel` = `String` calculée au parsing (UTC, `'Aujourd’hui'` si date absente, L47-54) → tri/affichage localisé impossibles ; `commission` → `neutral` |
| `PayoutRequestRecord` (`payout_request.dart:70-83`) | `id, amount, fees, status, reference, destination_phone, operator, failure_reason, created_at, processed_at` | `wallet_id, gateway_payout_id, country_iso, updated_at` | `createdAt ?? DateTime.now()` (L80) ; `fees` parsé mais non affiché ; statut inconnu → `pending` |
| `PayoutProviderOption` | `provider_short_name, provider_name, provider_country, provider_currency, min_amount, max_amount` | — | `currency` et `maxAmount` non exploités par l'UI |
| `PayoutBalances`/`CreatorDashboard` | `wallet_balance, withdrawable_balance` | `total_earnings, total_withdrawn, total_refunded` (renvoyés par `payout_service.py:82-88`) | non utilisés |
| `AppNotification` | tous | — | `createdAt ?? DateTime.now()` (L144) ; `video_id` lu mais jamais utilisé pour naviguer |
| `Device` (`auth/domain/device.dart`) | `id, device_id, platform, device_name, is_active, last_seen_at` | `user_id`, `created_at` | robuste ; `id` peut valoir `''` si absent |
| `TopupStatus` | `status` | `amount` | OK |

---

## 5. Tests

### 5.1 Fichiers et couverture (26 tests, tous verts)
| Fichier | Tests | Couverture réelle |
|---|---|---|
| `test/authenticated_client_test.dart` (218 l.) | 6 | Refresh sur 401 + rejeu, refresh concurrents sérialisés, jeton frais prioritaire, refresh refusé ⇒ session vidée + callback, panne réseau pendant refresh ⇒ pas de déconnexion, requêtes sans bearer inchangées. **Le meilleur fichier de la suite.** |
| `test/creator_repository_api_test.dart` (115 l.) | 4 | `listMyVideos` (pagination 100), `retryTranscode`, `initiateTopup` + `getTopupStatus`, erreur `initiateTopup`. |
| `test/creator_repository_playback_test.dart` (127 l.) | 4 | Session de lecture → URL `/stream/{id}/master.m3u8?token=`, device id persisté, erreur 403, token manquant. |
| `test/video_upload_flow_test.dart` (171 l.) | 5 | `initVideoUpload` (**fixture fausse : `upload_url`**, L45/49), `uploadChunk` (ETag), `confirmUploadPart`, `completeUpload`, `getProcessingStatus`. |
| `test/creator_shell_test.dart` (142 l.) | 3 | Dashboard (soldes, top vidéo, badge notif), historique Gains, dashboard en erreur. |
| `test/creator_content_test.dart` (122 l.) | 1 | Montage de Videos/Publish/VideoDetail/VideoStats avec faux client (textes statiques seulement). |
| `test/auth_onboarding_test.dart` (38 l.) | 1 | Montage de Login/Register/BecomeCreator (un texte chacun, sans routeur ni interaction). |
| `test/design_system_test.dart` (67 l.) | 1 | Montage des primitives. |
| `test/widget_test.dart` (20 l.) | 1 | Montage de l'app (sans assertion de comportement). |

### 5.2 Ce qui n'est pas couvert
Par écran :
- Splash, Login (soumission, erreur, champs conservés), Register (OTP, échec register après verify, redirection), ForgotPassword, BecomeCreator (soumission), Settings, Notifications, Devices, Profile, PayoutRequest, PayoutDetail, FullVideoPlayer : **0 test** d'interaction. Videos/Detail/Stats/Publish/Dashboard/Earnings : montage + textes uniquement (aucun tap, aucune mutation, aucun état erreur sauf dashboard).
- **Routeur/redirections** (`app_router.dart`) : aucun test (c'est là que se trouvent R1/R2).
- `AuthController` (bootstrap hors-ligne, login/logout, `handleSessionExpired`) : aucun test.
- `VideoUploadController` (retry, annulation, poll infini), `VideoMutationController`, `TopupController` (poll, timeout 100 tentatives), `PayoutController`, `ProfileController`, `NotificationMutationController`, `DeviceRevokeController` : aucun test.

Par repository :
- `AuthRepository` (12 méthodes), `DeviceRepository` (3), `NotificationRepository` (4) : **aucun test**.
- `CreatorRepository` : non testées directement `updateVideo`, `deleteVideo`, `presignUploadParts`, `getUploadStatus`, `abortUpload`, `requestPayout`, `listPayoutProviders`, `listPayouts`, `getPayout`, `loadPayoutBalances` (10/23).
- Modèles/parseurs : aucun test unitaire (pas de cas `null`/champ absent/type inattendu) ; `gn_formatters.dart`, `json_helpers.dart` sans test.
- **Les fixtures ne sont pas validées contre le backend** : celle de l'init d'upload est fausse (§2.11) ; aucun contrat partagé.

---

## 6. Fichiers morts / inutiles / dépendances

### 6.1 Code jamais utilisé
- `AuthRepository.myInfo` (`auth_repository.dart:87-105`).
- `CreatorRepository.loadPayoutBalances` (`creator_repository.dart:50-70`) et `getUploadStatus` (324-336) + classe `UploadStatusResponse` (`video_upload_init_response.dart:60-97`).
- `CreatorRepository.listPayouts` (485-504), `payoutsProvider` (`payout_providers.dart:12-16`, seulement invalidé), `PayoutRequestRecord.fees` (jamais affiché).
- `VideoWithStats.isReady` (`video_with_stats.dart:46`), `VideoPlaybackAccess.expiresAt`, `ProcessingStatusResponse.attempts`, `VideoUploadInitResponse.maxParallelUploads/expiresIn/objectKey`.
- `VideoUploadController.reset()` (`creator_content_provider.dart:359`) — jamais appelé (et nécessaire, cf. bug).
- Tokens de design inutilisés : `AppFonts.body`, `AppRadii.phone`, `AppRadii.xl`, `AppSpacing.x3…x8`, `AppColors.accent600` (`app_theme.dart`).
- Duplications : `_StripePainter` (dashboard L588 / widgets L390), `_Header` (retour) copiée 6 fois (payout_request, payout_detail, stats, settings, notifications, devices), extension `firstOrNull` copiée 2 fois (`payout_request_screen.dart:390`, `profile_screen.dart:267`) alors que Dart 3 la fournit.

### 6.2 Assets / dossiers
- `assets/images/` contient 3 fichiers (`gnplay_logo.png`, `gnplay_logo_transparent.png`, `LOGO_TRANSPARENT.png`) : **seul `LOGO_TRANSPARENT.png` est référencé** (`gnplay_logo.dart:11`) ; les 2 autres sont inutilisés mais embarqués (`pubspec.yaml` déclare `assets/images/`).
- Dossier `GNPlay Design System/` (≈ 45 fichiers .jsx/.html/.css/.js/.d.ts) **versionné dans le dépôt de l'app mobile** mais non référencé par Flutter ; `creator_video_management_api.md` à la racine décrit l'ancien endpoint `/videos/{id}/access` (obsolète, le code utilise `playback-session`) ; `README.md` correct mais « lancer » vise la **prod** par défaut (`api_config.dart:3-4`).
- Boilerplate non personnalisé : `pubspec.yaml` `description: "A new Flutter project."` ; `web/manifest.json` (« gnplay », « A new Flutter project. », couleurs `#0175C2`) ; `web/index.html` titre « gnplay » ; fenêtre Linux « gnplay » (`linux/runner/my_application.cc:49,53`) ; iOS `CFBundleDisplayName` « Gnplay » ; icônes de lanceur : non vérifié (peuvent être celles de Flutter) ; `web` ne peut pas compiler (`dart:io`, `File`, `Platform` dans `auth_repository.dart`, `device_repository.dart`, `creator_content_provider.dart`).
- Android/release (**bloquants publication**) : `android/app/src/main/AndroidManifest.xml:6` `android:usesCleartextTraffic="true"` dans le manifeste principal (HTTP clair autorisé en production) ; `android/app/build.gradle.kts:27` `applicationId = "com.example.gnplay"` (TODO du modèle) et `:40` build `release` signé avec la clé **debug**.
- macOS : `macos/Runner/DebugProfile.entitlements` n'a que `network.server`, pas `network.client` (non vérifié pour Release) — hors cible mobile.

### 6.3 Dépendances `pubspec.yaml`
| Paquet | Usage |
|---|---|
| `flutter_riverpod`, `go_router`, `http`, `flutter_secure_storage`, `video_player`, `file_picker`, `url_launcher`, `google_fonts` | utilisés |
| `video_player_media_kit` | utilisé (`main.dart:3,12`, modif locale) |
| `media_kit_libs_linux` | non importé dans `lib/` mais requis par `video_player_media_kit` sur Linux (légitime) |
| `cupertino_icons` | **inutilisé** (`grep CupertinoIcons` = 0) |
| `flutter_localizations` | **absent** alors que l'app est 100 % française (menus système en anglais) |
| `intl` | absent (dates/devises formatées à la main) |
| `flutter_lints` ^5.0.0 | OK (6.0.0 disponible) |
Versions majeures en retard : go_router 8 → 17/18 (breaking), riverpod 2 → 3, flutter_secure_storage 9 → 10/11, file_picker 11 → 13.

---

## 7. Liste priorisée des problèmes (P0 bloquant / P1 important / P2 confort)

### P0 — bloquant
| ID | Problème | Fichier:ligne |
|---|---|---|
| P0-1 | Contrat d'`upload/init` faux : l'app lit `parts[].upload_url`, le backend renvoie `parts[].url` ⇒ URL vide, chaque part échoue au 1ᵉʳ essai et ne passe que via le repli `presign` (+2 s/part) ; l'envoi échoue si `presign` échoue. Test masquant la panne. | `video_upload_init_response.dart:12` ; `creator_content_provider.dart:285-316` ; backend `videos.py:252-258,289`, `r2_service.py:218-228` ; `test/video_upload_flow_test.dart:45,49` |
| P0-2 | « Annuler » pendant le traitement **supprime la vidéo côté serveur** sans confirmation (et le texte promet « vous pouvez fermer l'app »). | `publish_screen.dart:178-185,601` ; `creator_content_provider.dart:361-372` ; backend `videos.py:981-1010` |
| P0-3 | Publication Android impossible/dangereuse : HTTP clair autorisé en prod, signature `debug`, `applicationId com.example.*`. | `AndroidManifest.xml:6` ; `build.gradle.kts:27,40` |

### P1 — important
| ID | Problème | Fichier:ligne |
|---|---|---|
| P1-1 | Routeur reconstruit à chaque changement d'auth : formulaire de connexion vidé après chaque échec, flash splash, `GoRouter` jamais disposé. | `app_router.dart:24-28` ; `auth_controller.dart:57,121-134` ; `login_screen.dart:44-48` |
| P1-2 | `postAuthRedirect` se réinitialise via le provider surveillé ⇒ redirection `/become-creator` post-inscription probablement perdue ; écriture avant connexion renvoie sur `/login`. | `app_router.dart:49-56` ; `register_screen.dart:98-116` |
| P1-3 | `bootstrap()` efface la session sur n'importe quelle erreur (hors-ligne = déconnexion), contrairement à `AuthenticatedClient`. | `auth_controller.dart:47-49` |
| P1-4 | Profil entièrement conditionné au dashboard : en erreur/403 plus d'édition, d'appareils ni de déconnexion. | `profile_screen.dart:47-63` |
| P1-5 | `switch` sur `AsyncData` ⇒ spinner plein écran à chaque rechargement (pull-to-refresh, mutation, poller 5-6 s) ; lecteur d'aperçu remonté. | `videos_screen.dart:94-101,37-42` ; `video_detail_screen.dart:87-117,39-49,72` ; `video_stats_screen.dart:42-63` |
| P1-6 | Vidéos `deleted`/`blocked` affichées « Brouillon » et republiables ; une vidéo achetée « supprimée » réapparaît. | `video_with_stats.dart:36-61` ; backend `videos.py:511-523,553-575,446-455` |
| P1-7 | `UploadPhase.ready` jamais réinitialisé : impossible de publier une 2ᵉ vidéo ; `reset()` jamais appelé. | `publish_screen.dart:109-112,609-612` ; `creator_content_provider.dart:359` |
| P1-8 | Champ « Miniature — URL » collecté mais jamais envoyé à l'API. | `publish_screen.dart:24,453-457,151-176` |
| P1-9 | Promesses de reprise d'upload non implémentées (rien n'est persisté, `getUploadStatus` jamais appelé). | `publish_screen.dart:324,534` ; `creator_repository.dart:324` |
| P1-10 | Sondage de traitement sans borne ni annulation : boucle infinie sur `not_started`, bascule en `failed` après annulation (404), workers d'upload non interrompus. | `creator_content_provider.dart:242-263,344-357` ; `video_upload_init_response.dart:114` |
| P1-11 | Inscription : compte à rebours « 00:45 » factice ; après `verify-otp` réussi puis échec de `register`, plus de reprise possible (OTP consommé). | `register_screen.dart:384-386,79-93` ; backend `auth_service.py:134-136,68` |
| P1-12 | Notifications et Appareils : une erreur API est présentée comme un état vide, sans retry. | `notifications_screen.dart:33-35,88-89` ; `devices_screen.dart:33-34,116-139` |
| P1-13 | Retraits : erreur de `/payouts/providers` présentée comme « aucun opérateur » ; `max_amount`/devise ignorés ; pas de récapitulatif avant débit ; erreur du retrait précédent persiste (contrôleur non autoDispose). | `payout_request_screen.dart:62-64,230-234,84-91,303` ; `payout_controller.dart:9` |
| P1-14 | Aucun historique des retraits (`listPayouts`/`payoutsProvider` non branchés) alors que l'API et la conception l'exigent. | `creator_repository.dart:485` ; `payout_providers.dart:12` ; `earnings_screen.dart` |
| P1-15 | Aucun timeout HTTP ; exceptions réseau brutes affichées (« ClientException with SocketException… »). | `creator_content_widgets.dart:351-357` ; tous les repositories |
| P1-16 | Fallback d'erreur auth mal libellé et sans accents (« La creation du compte a echoue. » même à la connexion). | `auth_repository.dart:329,304,326` ; `creator_repository.dart:644,673,676` |
| P1-17 | Déconnexion : exception réseau non gérée (`finally` sans `catch`) ; pas de confirmation ; révocation d'appareil sans confirmation. | `auth_controller.dart:120-149` ; `profile_screen.dart:259-264` ; `settings_screen.dart:128-133` ; `devices_screen.dart:148-150` |
| P1-18 | Édition vidéo : prix vide ⇒ gratuit silencieux, titre vide ⇒ aucun message, erreurs masquées par la feuille, risque de débordement clavier. | `video_detail_screen.dart:1086-1105,1098,1044-1081` |
| P1-19 | Historique du portefeuille non trié (backend sans `order_by`), non paginé, date UTC sans heure avec repli « Aujourd'hui ». | `models/wallets.py:17` ; `wallet_ledger_entry.dart:47-55` ; `earnings_screen.dart:141-149` |
| P1-20 | Dashboard : 4+ appels séquentiels et téléchargement de toutes les vidéos (≤ 5 000) pour 5 miniatures ; réutilisé pour Profil et Retraits. | `creator_repository.dart:30-46,82-96,589-622` |
| P1-21 | `friendly` : messages backend en anglais affichés bruts (« Video not found », « Unsupported video format »…). | `videos.py`, `streaming.py`, `devices.py`, `notifications.py` ; affichage `'$error'` dans les snackbars |
| P1-22 | Test de contrat trompeur et absence totale de tests routeur/auth/contrôleurs/repositories auth-device-notif. | §5 |

### P2 — confort / dette
| ID | Problème | Fichier:ligne |
|---|---|---|
| P2-1 | Réglages : interrupteur « Mode sombre » inerte + snackbar « arrive dans une prochaine version » ; « Conditions générales · Mentions légales » non cliquable ; version en dur. | `settings_screen.dart:18,89-105,114` |
| P2-2 | Champ « Pays » factice (chevron « ⌄ » sans action), pays en dur `GN`. | `register_screen.dart:34-35,557-593` |
| P2-3 | Libellé « Vidéos publiées » = total de toutes les vidéos. | `creator_dashboard_screen.dart:342` ; `analytics.py:68-70` |
| P2-4 | Textes obsolètes : limite de 3 appareils (le backend évince automatiquement). | `devices_screen.dart:98` ; `full_video_player_screen.dart:52,377-381` |
| P2-5 | `context.go` vers routes hors shell ⇒ perte de l'état des onglets et retour toujours sur `/videos`. | `videos_screen.dart:144` ; `creator_dashboard_screen.dart:464` ; `video_detail_screen.dart:97,199` |
| P2-6 | Poller de la liste actif depuis n'importe quel onglet ; `Timer` posé dans `build` (détail, retrait). | `videos_screen.dart:37` ; `video_detail_screen.dart:72` ; `payout_detail_screen.dart:47` |
| P2-7 | `setState`/`state =` après `await` sans `mounted` : `_toggleMute`, `TopupController.start`, `VideoUploadController` après annulation/dispose. | `video_detail_screen.dart:532` ; `topup_controller.dart:56-62` ; `creator_content_provider.dart:262` |
| P2-8 | `ref.watch` utilisé après un `await` dans un provider. | `creator_content_provider.dart:73-82` |
| P2-9 | Deux sources de jeton (état `AuthController` périmé vs `TokenStorage`). | `device_provider.dart:40-46` ; `notification_provider.dart:66-72` ; `profile_controller.dart:56-62` |
| P2-10 | Multipart (photo de profil) non rejouable après 401 ; pas de validation taille/format avant envoi. | `authenticated_client.dart:46-48` ; `profile_screen.dart:237-248` |
| P2-11 | Cibles tactiles < 48 dp et absence de `Semantics`/tooltips (retours 32×32, interrupteur 46×26, cloche 40×40, « Annuler », « Tout retirer », info-bulle 17 px). | cf. §2.21 |
| P2-12 | Pas de `flutter_localizations` / locale ⇒ menus système et info-bulles en anglais ; `MaterialApp.title` « Gnplay ». | `main.dart:22-28` ; `pubspec.yaml` |
| P2-13 | Polices : `fontFamily: 'Sora'` forcé alors que `google_fonts` n'enregistre pas ce nom ; polices téléchargées à l'exécution. | `gn_button.dart:67` ; `earnings_screen.dart:358` ; `app_theme.dart:112-120` |
| P2-14 | Devise « GNF » codée en dur partout (le backend dépend du pays/provider). | `gn_formatters.dart:14-17` ; `payout_request_screen.dart:127,173,188` ; `topup_sheet.dart:168` |
| P2-15 | Dates : pas de `toLocal()`, pas d'année, `DateTime.now()` fabriqué si champ absent. | `video_detail_screen.dart:1112-1129` ; `payout_detail_screen.dart:215-221` ; `video_with_stats.dart:65,83` ; `payout_request.dart:80` ; `app_notification.dart:32` |
| P2-16 | Parseurs fragiles : `UserRead`, `TopVideo` (`as String`, `as int?`) ; champs fantômes `TopVideo.revenue/thumbnail_url`. | `user_read.dart:42-57` ; `top_video.dart:19-26` |
| P2-17 | `Image.network`/`NetworkImage` sans gestion d'erreur (dashboard, avatar). | `creator_dashboard_screen.dart:478` ; `profile_screen.dart:296-301` |
| P2-18 | `durationLabel` « 0 min » pour vidéo non traitée ; `formatMoney` avec espace sécable. | `videos_screen.dart:492` ; `gn_formatters.dart:31-45,5-12` |
| P2-19 | Notification : tap n'ouvre pas la vidéo (`video_id` ignoré) ; limite 100 ; pas de re-sondage du compteur (ni invalidation au pull-to-refresh du dashboard). | `notifications_screen.dart:94-102` ; `creator_dashboard_screen.dart:32,94` |
| P2-20 | Appareils : icône unique, nom = chaîne noyau, inactifs non distingués, « CET APPAREIL » pour un appareil évincé. | `devices_screen.dart:230,245-247,276` ; `device_repository.dart:84-89` |
| P2-21 | `BecomeCreatorScreen` sans retour, sans confirmation ; admin affiché comme non-créateur (403 `payouts` réservé à `CREATOR`). | `become_creator_screen.dart:59-74` ; `payouts.py:22` ; `creator_dashboard_screen.dart:67` |
| P2-22 | Top-up : URLs de retour renvoient au site web (pas de deep link), pas de min/max, pas d'action pendant l'attente. | `payments.py:65-75` ; `topup_sheet.dart:79-84` |
| P2-23 | Lecteur plein écran minimal (pas de rotation, contrôles auto-masqués, buffering, expiration de session 2 h). | `full_video_player_screen.dart:123-354` |
| P2-24 | `ListView(children: …map)` non paresseux (vidéos, notifications, appareils, historique). | `videos_screen.dart:138`, `notifications_screen.dart:94`, `devices_screen.dart:141`, `earnings_screen.dart:141` |
| P2-25 | Dette : doublons (`_Header` ×6, `_StripePainter` ×2, `firstOrNull` ×2, helpers HTTP ×4), `CreatorRepository` god class (678 l.), `creator_content_provider.dart` 385 l. mélange 6 responsabilités. | §3 |
| P2-26 | Code mort : `myInfo`, `loadPayoutBalances`, `getUploadStatus`/`UploadStatusResponse`, `listPayouts`, `isReady`, `expiresAt`, tokens de design, 2 logos, `cupertino_icons`, dossier `GNPlay Design System/`, `creator_video_management_api.md` obsolète. | §6 |
| P2-27 | Boilerplate : description pubspec, manifest web, titres fenêtres, `CFBundleDisplayName`, build web impossible (`dart:io`). | §6.2 |
| P2-28 | README : `flutter run` vise la production par défaut (`api_config.dart:3-4`). | `api_config.dart:3-4` |
| P2-29 | Dépendances en retard (go_router 8 → 18, riverpod 2 → 3, secure_storage 9 → 11, file_picker 11 → 13). | `pubspec.yaml` |
| P2-30 | Extension `firstOrNull` locale, `AppTextStyles` statiques `GoogleFonts.*` évalués paresseusement (chargement réseau au premier usage). | `payout_request_screen.dart:390` ; `app_theme.dart:112+` |
