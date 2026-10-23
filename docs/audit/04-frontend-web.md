# Audit du frontend web Next.js (createur / compte / argent) vs app mobile Flutter

Perimetre lu (lecture seule) :
- Web : `/home/saliou/Bureau/gnplay/frontend/src` (api.ts, store/useAuthStore.ts, components/AppInitializer.tsx, pages upload, wallet, wallet/callback, profile, library, watch/[id], login, register, page.tsx).
- Mobile : `/home/saliou/Bureau/gnplay/gnplay-mobile/lib`.
- Backend : `/home/saliou/Bureau/gnplay/app` (tout sous `/api/v1`).

Notation : les numeros de ligne web sont ceux des fichiers pris individuellement. `API = <NEXT_PUBLIC_API_URL>/api/v1` (api.ts:3-10). Le mobile utilise `ApiConfig.baseUrl` (core/network/api_config.dart:1-15, defaut `https://gnplay-api.nextgenz.tech`).

IMPORTANT, constat de depart : le web N'A PAS de page pour : mot de passe oublie, notifications, statistiques/analytics, liste "mes videos" / edition / suppression / (de)publication, retry transcodage, liste des appareils hors ecran de blocage. Seuls upload, wallet (+callback), profil/avatar/devenir createur, login/register(OTP), lecture et catalogue/achat/like existent. Le mobile est une app "createur" (docs/creator-app-design.md) : il n'a ni catalogue, ni achat, ni bibliotheque, ni like.

---------------------------------------------------------------------------------------------------

## 1. Fonctionnalites web : appels API exacts, logique cliente, details

### 1.1 Client HTTP et session (services/api.ts)
- axios `baseURL = API`, header par defaut `Content-Type: application/json` (api.ts:5-10).
- Intercepteur requete : `Authorization: Bearer <localStorage.access_token>` (api.ts:13-24).
- Intercepteur reponse 401 (api.ts:41-110) : ignore `/auth/refresh-token` et `/auth/login` ; file d'attente `failedQueue` + drapeau `isRefreshing` pour serialiser le refresh (refresh token rotatif cote backend, auth_service.py:269-291) ; `POST /auth/refresh-token {refresh_token}` via un `axios` nu ; stocke les 2 nouveaux tokens ; rejoue la requete une fois (`_retry`). Echec -> vide les 2 cles et `window.location.href='/login'`.
- AUCUN header `X-DEVICE-NAME` n'est envoye (grep `x-device` dans frontend/src : 0 resultat). Cote backend, `X-DEVICE-NAME` n'est lu qu'au login pour nommer la session (`app/services/auth_service.py:230-231`, defaut `"api request"`). Le mobile ne l'envoie pas non plus (grep dans gnplay-mobile/lib : 0). Les sessions ne sont d'ailleurs listees par aucune route, donc impact faible.
- Tokens en `localStorage` (api.ts:16, store:76-77) ; mobile : `flutter_secure_storage` (auth/data/token_storage.dart:142-182).

### 1.2 Connexion / deconnexion (store/useAuthStore.ts + app/login/page.tsx)
- `POST /auth/login` en `application/x-www-form-urlencoded` : `username=<phone>&password=<pwd>` (store:69-95). Backend : `OAuth2PasswordRequestForm` (routes/auth.py:45).
- Apres succes : stocke tokens, `GET /users/me` + `GET /wallets/balance` en parallele (store:110-134), puis `registerCurrentDevice()` (store:182).
- Validation client : seulement "champs vides" (login/page.tsx:19). Message d'erreur : `err.response?.data?.detail || "Identifiants incorrects."` (login/page.tsx:22). Backend renvoie 401 "Numero de telephone ou Mot de passe incorrect" (auth_service.py:197,201).
- Deconnexion : `POST /auth/logout {refresh_token}` (store:97-108) ; echec ignore (console.warn) ; vide le storage dans `finally`. Le backend sait aussi deconnecter tous les appareils si `refresh_token` est null (auth_service.py:317+).
- Limite de sessions : le backend revoque les sessions les plus anciennes au login (`MAX_SESSIONS_PER_USER=2`, core/config.py:30 ; auth_service.py:209-218). L'appareil evince recevra 401 au prochain refresh -> redirection login.

### 1.3 Inscription + OTP (app/register/page.tsx, 3 etapes)
1. Pays (`SN`/`GN`/`FR`, ligne 80) + telephone. `POST /auth/request-otp {phone_number, otp_type:'register'}` (l.27). Succes -> "Code OTP envoye !". Si la reponse contient `debug_code` (mode DEBUG backend uniquement, schemas/otp_codes.py:12-17), le code est pre-rempli et affiche (l.30-33, 98-100).
2. `POST /auth/verify-otp {phone_number, code}` (l.44) - ATTENTION : pas de `otp_type` envoye (le defaut backend est `register`, schemas/otp_codes.py:9). Input `maxLength=6`. Succes -> "Numero verifie !".
3. `POST /auth/register {phone_number, full_name, password, country_iso2}` (l.53) puis `alert('Inscription reussie !')` et `router.push('/login')`. Pas de login automatique.
- Validation client : uniquement non-vide (l.24, 42, 51). Le backend impose `full_name >= 6`, `phone_number >= 9`, `password >= 4` (schemas/auth.py:12-19). Les violations renvoient un 422 dont `detail` est une LISTE d'objets -> voir defauts (3.2).
- Backend : un OTP "register" actif ne peut etre redemande qu'apres 1 minute (429 "Trop de tentatives, ressayez dans 1min", auth_service.py:68-70) ; `request_otp` limite a 5/minute (routes/auth.py:28). L'OTP peut venir du fournisseur NG Messaging (ng_messaging_service, non commite) : dans ce cas `debug_code` est toujours null.
- Pas d'ecran "mot de passe oublie" sur le web, alors que le backend a `POST /auth/request-password-reset {phone_number}` (202) et `POST /auth/reset-password {phone_number, code, new_password}` (204).

### 1.4 Appareils et limite de 3 appareils (store + components/AppInitializer.tsx)
- device_id : `localStorage.gnplay_device_id`, genere `'gnplay_web_' + Math.random().toString(36).substring(2,15)` (store:184-189).
- `POST /devices/register {device_id, platform:'web', device_name:'Navigateur Web'}` appele apres login et a chaque chargement (AppInitializer:25-33 ; store:192-206).
- Gestion de la limite : si reponse 400 dont `detail` contient "Maximum" -> `deviceLimitExceeded=true`, `GET /devices`, et AppInitializer affiche un ecran bloquant "Limite d'appareils atteinte" avec la liste et un bouton Revoquer par appareil (AppInitializer:48-118, texte "3 appareils" l.74) ; revocation = `confirm()` puis `DELETE /devices/{device_id}` (store:217-227, l'ID envoye est le `device_id` logique) puis re-register.
- CE CODE EST MORT : le backend ne renvoie plus jamais ce 400. `register_device` evince automatiquement les appareils actifs les plus anciens (`MAX_ACTIVE_DEVICES=3`, `app/api/v1/routes/devices.py:14,36-49`). Consequence reelle : l'appareil evince recoit 403 "Playback is restricted to registered active devices" (routes/streaming.py:~111-118) au playback ; le web traduit TOUT 403/400 en "Contenu Premium / Acheter" (watch/[id]/page.tsx:56-58,132-149) - message faux.
- Le backend accepte `DELETE /devices/{x}` avec `x` = id de ligne OU device_id (devices.py:97-101) : le web envoie le device_id, le mobile l'id de ligne.
- Le mobile a une vraie liste d'appareils (voir tableau).

### 1.5 Profil, avatar, devenir createur (app/profile/page.tsx + store)
- Chargement : `fetchUserAndWallet()` = `GET /users/me` + `GET /wallets/balance` (store:110-134). Champs UserRead : id, full_name, phone_number, page_name, bio, avatar, role, is_active, is_superuser, is_verified, created_at, updated_at (schemas/auth.py:23-34).
- Edition : `PATCH /users/me {full_name, page_name: pageName || undefined, bio}` (profile:40 ; store:229-232). Succes -> "Profil mis a jour." ; erreur -> `detail` ou "Erreur lors de la mise a jour du profil." Le `|| undefined` evite d'envoyer `page_name:""` (important : `page_name` est UNIQUE en base, models/user.py:15, et `UserService.update_user` ne gere ni doublon ni chaine vide -> 500/IntegrityError possible, services/user_service.py:22-37).
- Avatar : `<input type=file accept="image/*">` -> `POST /users/me/profile-picture` multipart (champ `file`) (profile:49-60 ; store:234-241). Reponse `{profile_picture_url}`. Backend : max 2 Mo (`MAX_IMAGE_SIZE`, config.py:47), extensions jpeg/jpg/png seulement (config.py:48) ; 400 sinon. Le web ignore le `detail` serveur et affiche toujours "Erreur lors de l'envoi de la photo de profil." (profile:56) ; aucune verification de taille/format cote client.
- Devenir createur : `POST /users/me/become-creator` (sans corps) -> renvoie UserRead, remplace `user` du store (store:243-246). Bouton affiche uniquement si `role==='viewer'` (profile:106). Backend : viewer -> creator uniquement ; admin refuse 400 (user_service.py:39-63).
- Le lien "Publier" du Navbar est masque pour les viewers (Navbar.tsx:37 `user?.role !== viewer`) - mais le backend NE verifie PAS le role sur `POST /videos/upload/init` (routes/videos.py:174-180, seulement `UserDependency`) : un viewer peut uploader via l'API.

### 1.6 Upload video et suivi du traitement (app/upload/page.tsx, 557 lignes)
Formulaire (etape 1) : titre (obligatoire), description, prix XOF (`type=number min=0`, defaut "0"), fichier `accept="video/mp4"` uniquement (l.464). Validation : fichier requis (l.331-334) ; titre via `required` HTML ; pas de limite de taille.

Sequence "nouvel envoi" (`startFreshUpload`, l.106-212) :
1. `POST /videos/upload/init {filename, file_size, mime_type: file.type||'video/mp4'}` -> `{video_id, upload_id, chunk_size, total_parts, parts:[{part_number, url}], max_parallel_uploads:3, expires_in:3600, object_key}` (routes/videos.py:174-300). Backend : types autorises `video/mp4|webm|quicktime`, `file_size>0` ; taille de part fixe 10 Mo (`part_size=10*1024*1024`, l.~237) ; URLs presignees R2 valables 3600 s.
2. `PATCH /videos/{video_id} {title, description, price:Number(price)}` (l.130-134). Redondant : `init` accepte deja `title`, `description`, `price` (schemas/videos.py:7-13 ; routes/videos.py:214-219). Defaut possible : `Number("10.5")` -> 422 car `price` est int.
3. Sauvegarde de reprise : `localStorage.gnplay_pending_upload = {videoId, uploadId, fileName, fileSize, title, description, price}` (l.137-146).
4. Pour chaque part (concurrence 3 via `runWithConcurrencyLimit`, l.85-96, 193) : `file.slice(index*chunkSize, +chunkSize)` ; `PUT part.url` avec `Content-Type: file.type`, corps = Blob, sans Authorization (axios nu, l.165-168) ; ETag lu dans `response.headers.etag` (guillemets retires, l.169) - exige `ExposeHeaders: ETag` dans le CORS du bucket R2 ; erreur "Aucun ETag renvoye par le stockage." sinon ; 5 tentatives, attente `2000*attempt` ms (l.162-178), la part est remise a 0 dans la progression a chaque echec ; ensuite `POST /videos/upload/{video_id}/parts/confirm {part_number, etag, size}` (l.182-186). NB : apres retry l'URL presignee n'est PAS regeneree (contrairement au mobile).
5. `POST /videos/upload/{video_id}/complete {upload_id, parts:[{PartNumber, ETag}]}` (l.197-200), liste triee par index de part. Reponse 202 `{message, video_id, status}` ; `status` vaut `queued` (stockage local) ou `uploaded_waiting_r2_notification` (R2) (routes/videos.py:403-406). Le transcodage est declenche par ARQ, webhook ou notification R2.
6. Efface `gnplay_pending_upload`, passe a l'etape 3 et lance `pollStatus`.

Progression (etape 2) : octets par part dans un `useRef` (`reportPartProgress`, l.50-63) -> % global, octets envoyes / total, vitesse (echantillon toutes les 0,5 s) et "reste ~Ns" (l.506-527). Libelle courant "Envoi du fragment i/N...".

Reprise apres interruption (`resumeInterruptedUpload`, l.215-327) : declenchee seulement si l'utilisateur re-selectionne un fichier de MEME nom ET taille que la session sauvegardee (l.66-82) :
1. `GET /videos/upload/{video_id}/status` -> `{uploaded_parts, missing_parts, chunk_size, total_parts, status, expires_at}` (routes/videos.py:945-978).
2. Les parts deja confirmees comptent pour leur taille complete dans la progression (l.240-245).
3. `POST /videos/upload/{video_id}/parts/presign {upload_id, parts:[manquantes]}` -> `{parts:[{part_number, upload_url, expires_in}]}` (max 100 parts, l.864-903). Attention : cle `upload_url` ici vs `url` dans la reponse de `init`.
4. Upload des parts manquantes (meme boucle retry/confirm).
5. `GET /videos/upload/{video_id}/parts` -> `{parts:[{part_number, etag}]}` pour reconstruire la liste complete, puis `POST .../complete`.
- Bouton "Recommencer de zero" : supprime seulement la cle localStorage (l.344-349) ; N'APPELLE PAS `POST /videos/upload/{id}/abort` -> la ligne `videos` (statut UPLOADING) et le multipart R2 restent orphelins. Meme chose apres un echec d'upload (l.207-211).

Suivi du traitement (`pollStatus`, l.351-374) : `setInterval` 3 s sur `GET /videos/{video_id}/processing-status` -> `{video_id, status, progress, attempts, error_message}` (routes/videos.py:1016-1037). `status==='ready'` -> etape 4 "Video publiee !" ; `failed` -> `error_message || "Le transcodage HLS a echoue. Veuillez reessayer."` et retour a l'etape 1 ; autres (`queued|processing|not_started`) -> "Traitement de la video : <status> (<progress>%)...". Toute erreur reseau/HTTP est avalee (l.370-372). Valeurs reelles du job : `queued|processing|ready|failed` + `not_started` si pas de job (workers/video_processing.py:73,311,371 ; videos.py:1030). Le worker passe `is_published=True` automatiquement a la fin (video_processing.py:319) : le web n'a donc jamais besoin de publier manuellement.

### 1.7 Portefeuille, recharge, callback, retraits (app/wallet/page.tsx, wallet/callback/page.tsx)
Chargement : `fetchUserAndWallet()` (`GET /users/me`, `GET /wallets/balance` -> `{balance}`), `GET /wallets/transactions` (ledger : `id, amount, direction credit|debit, transaction_type, description, reference_id, reference_type, created_at`) (wallet:34-37). Pour un createur : `GET /payouts/balance` (-> `withdrawable_balance`, `wallet_balance`, `total_earnings`, `total_withdrawn`, `total_refunded` ; payouts.py:22-26 + payout_service.py:get_withdrawable_balance), `GET /payouts` (historique), `GET /payouts/providers` (store:146-164, wallet:39-48). Le solde "retirable" ne compte que les gains de ventes, pas les recharges (payout_service.py:63-92).

Recharge : champ montant (`min=1`) ; garde `if (!topupAmount || Number<=0) alert("Montant invalide.")` (wallet:52) ; `POST /payments/topup/initiate {amount}` -> `{payment_url, reference}` (store:136-144) ; `window.location.href = payment_url` (navigation complete vers DexPay, wallet:56-58). Erreurs : `alert("Impossible d'obtenir l'URL de paiement.")` / `alert("Erreur lors de l'initiation du paiement.")`. Le backend cree un `TopupTransaction(pending)`, appelle DexPay (devise codee en dur `XOF`, services/dexpay_service.py:27) avec `success_url=<BACKEND_URL>/api/v1/payments/topup/success?reference=...` et `failure_url=.../failure?reference=...` ; ces deux routes font un `RedirectResponse` vers `<FRONTEND_URL>/wallet/callback?reference=...[&failed=true]` (routes/payments.py:46-75). Le credit du portefeuille n'est applique QUE par le webhook signe `POST /payments/topup/webhook` (en-tete `x-webhook-signature`, evenement `checkout.completed`, payments.py:77-137), jamais par la redirection.

Page callback (wallet/callback/page.tsx) : lit `reference` et `failed` dans l'URL ; pas de reference ou `failed=true` -> echec direct (l.25-33) ; sinon `GET /payments/topup/status/{reference}` -> `{status: pending|completed|failed|cancelled, amount}` ; `completed` -> succes + `fetchUserAndWallet()` ; `failed|cancelled` -> echec ; `pending` -> re-essai toutes les 2 s, maximum 6 fois (12 s) puis etat "timeout" ("La validation se poursuivra en arriere-plan", l.130-147) ; erreur HTTP -> echec (l.56-59). Textes : "Traitement en cours", "Recharge Reussie !", "Echec de la transaction ... Aucune somme n'a ete debitee", "Validation en cours...". ATTENTION : cette page appelle une route authentifiee avec les tokens du navigateur ; si l'utilisateur n'est pas connecte dans CE navigateur, l'intercepteur redirige vers `/login` (api.ts:68-74).

Retrait (createur) : champs montant, operateur (`<select>` rempli par `/payouts/providers`, valeur = `provider_short_name`, libelle = `provider_name`), telephone (prerempli avec le numero du compte). Validations client : montant>0 ; `amount > withdrawableBalance` -> "Montant superieur a votre solde retirable." ; operateur requis (wallet:65-82). PAS de verification du minimum/maximum du fournisseur (`min_amount`/`max_amount` sont pourtant renvoyes). `POST /payouts/request {amount, operator, destination_phone}` (store:166-180) ; rate limit backend 5/heure (routes/payouts.py:41-43) ; erreurs backend : 400 montant < minimum pays (`GNF` 10 000 ; `XOF`/`XAF` 100, payout_service.py:16-20,106-117), 400 solde retirable insuffisant, 502 "Le retrait a echoue et a ete rembourse: <motif>". Le web affiche `detail` ou "Erreur lors de la demande de retrait." ; ensuite recharge soldes + historique.
Historique des retraits : liste `GET /payouts` avec etiquettes FR (`pending` En attente, `processing` En cours, `completed` Termine, `failed` Echoue, `cancelled` Annule, wallet:9-15), montant, telephone, date. Pas de page detail ; `GET /payouts/{id}` (qui rafraichit le statut aupres de DexPay, payouts.py:87-116) n'est pas utilise par le web. Pas de polling du statut.
Devise affichee : "XOF" en dur partout (wallet:96,115,154,179).

### 1.8 Lecture video (app/watch/[id]/page.tsx, components/VideoPlayer.tsx)
- `GET /videos?limit=100` (catalogue public = videos `ready|published` ET `is_published=true`, routes/videos.py:535-550) puis recherche de la video dans cette liste cote client (watch:32-35). DEFAUT : video hors des 100 premieres, ou non publiee (le createur qui veut previsualiser sa propre video !) -> "Video introuvable".
- device_id lu/genere comme au 1.4, puis `POST /videos/{id}/playback-session?device_id=<id>` (device_id en QUERY, pas en body) -> `{token, expires_at (2 h), watermark}` ; URL du flux = `${API}/stream/{id}/master.m3u8?token=<token>` (watch:47-52). Cote backend : exige `status in (ready,published)` (400 sinon), acces (prix 0 | proprietaire | achat dans le ledger, sinon 403), et appareil actif enregistre (403) (streaming.py:64-118).
- Mapping d'erreur : 403 ou 400 -> `hasAccess=false` -> ecran "Contenu Premium" + bouton Acheter (watch:56-58, 132-149) ; autre -> console. Pas de message distinct "appareil non autorise" (l'ecran dedie ne s'active que via `deviceLimitExceeded`, code mort, l.115-130).
- Filigrane : texte `watermark` ("Nom • •••1234") deplace toutes les 15 s sur 5 positions aleatoires, opacite 0,15 (watch:70-85,160-179). Mobile : rotation toutes les 5 s (full_video_player_screen.dart:199-208).
- Lecteur : `hls.js` (`enableWorker`, `lowLatencyMode`), recuperation automatique sur erreur fatale reseau (`startLoad`) ou media (`recoverMediaError`) ; repli natif Safari ; `controlsList="nodownload"` + menu contextuel bloque (VideoPlayer.tsx:20-46). Le backend reecrit le manifeste pour propager `?token=` aux sous-ressources (streaming.py:~30-60).
- Achat (hors perimetre mobile) : `POST /videos/{id}/purchase` apres `confirm()` ; garde locale `walletBalance < price` -> `alert("Solde insuffisant !")` ; MAJ optimiste du solde (watch:87-101). Like : `POST|DELETE /videos/{id}/like` (VideoCard.tsx). Bibliotheque : `GET /library?limit=100` (library/page.tsx:70). Le web n'envoie JAMAIS `POST /videos/{id}/watch-progress` (voir section 4).

---------------------------------------------------------------------------------------------------

## 2. Tableau Fonctionnalite | Web | Mobile | Ecart

| Fonctionnalite | Web | Mobile (fichier Dart) | Ecart |
|---|---|---|---|
| Login | `POST /auth/login` form-urlencoded (store:69-95) | Idem + `grant_type=password`, `scope=''` (auth/data/auth_repository.dart:17-41). Controleur : auth_controller.dart:274-292 | Equivalent. Aucun des deux n'envoie `X-DEVICE-NAME`. Mobile : message d'erreur = `detail` backend. |
| Refresh de token | Intercepteur axios + file d'attente (api.ts:41-110) | `AuthenticatedClient` : serialise un seul refresh en vol, relit le jeton du stockage, ne deconnecte pas sur erreur reseau, deconnecte sur 4xx (core/network/authenticated_client.dart:52-125) | Mobile plus robuste. Limite : requetes multipart non rejouables apres 401 (authenticated_client.dart:65). |
| Bootstrap session | `GET /users/me` + `/wallets/balance` au chargement (AppInitializer:25-33) | Au demarrage : `POST /auth/refresh-token` systematique, puis register device en arriere-plan (auth_controller.dart:254-272) | Mobile : un echec reseau au demarrage vide la session (catch -> clear, l.268-271) -> deconnexion sur simple perte de reseau. A corriger. |
| Deconnexion | `POST /auth/logout {refresh_token}` (store:97-108) | Cet appareil ET tous les appareils (`refresh_token` null) (auth_controller.dart:341-370 ; settings_screen.dart:48-55) | Mobile plus complet. |
| Inscription + OTP | 3 etapes, SN/GN/FR, `debug_code` prerempli, validation = non vide (register/page.tsx:22-60) | 2 etapes (compte -> OTP), Guinee `GN` seule (register_screen.dart:34-35), validateurs `full_name>=6`, `phone>=9`, `password>=4`, OTP 6 chiffres (l.261-304, 532) ; verify envoie `otp_type:'register'` (auth_repository.dart:206-229) ; auto-login apres inscription puis `/become-creator` (register_screen.dart:94-120) | Mobile : validations alignees sur le backend (meilleur). MAIS "Renvoyer le code dans 00:45" est un texte code en dur, sans compte a rebours, bouton toujours actif (register_screen.dart:374-390) ; le backend impose 1 min + 5/min (429 affiche tel quel). Pas de support `debug_code` (inutile en prod). |
| Mot de passe oublie | ABSENT | `POST /auth/request-password-reset` (202) puis `POST /auth/reset-password` (204) (auth_repository.dart:231-279 ; forgot_password_screen.dart:148-185) ; aussi accessible via Reglages > "Changer le mot de passe" (settings_screen.dart:42-47) | Mobile en avance. Validation faible : telephone `>=9`, code/mot de passe non vides seulement (forgot_password_screen.dart:152,166) ; pas de min 4 ni de comptage de 6 chiffres. Pas de vrai "changement avec ancien mot de passe" (inexistant cote backend). |
| Profil (nom, page_name, bio) | `PATCH /users/me` ; `page_name || undefined` (profile:40) | `PATCH /users/me` via bottom sheet ; envoie `page_name: ''` si vide (profile_screen.dart:494-500 ; auth_repository.dart:107-135) | Mobile : risque de violation d'unicite (`page_name` UNIQUE) pour tout 2e utilisateur avec `""` -> 500 backend. Reprendre le `|| undefined` du web. Aucun des deux ne gere "nom de page deja pris" de facon explicite. |
| Avatar | `POST /users/me/profile-picture` multipart, `accept=image/*` (profile:49-60) | Meme route, `FilePicker` image, `MultipartFile.fromPath('file')` (profile_screen.dart:237-248 ; auth_repository.dart:137-164) | Equivalent. Aucun controle client de la limite 2 Mo / jpeg-png (config.py:47-48) : le web masque le detail, le mobile affiche l'erreur du provider seulement si elle est capturee ailleurs. Ajouter verif taille/format + compression cote mobile. |
| Devenir createur | Bouton si `role==='viewer'` (profile:106-115) | Ecran dedie `/become-creator` + redirection post-inscription ; ecran "pas encore createur" sur 403 du dashboard (become_creator_screen.dart ; creator_dashboard_screen.dart:64-72, 380-400 ; auth_repository.dart:166-186) | Mobile OK. Detail : un `admin` est traite comme createur (`UserRead.isCreator` inclut admin, user_read.dart) mais `/payouts/*` exige `CREATOR` strict (payouts.py:19) -> 403 pour un admin. |
| Appareils : enregistrement | `device_id` `gnplay_web_<Math.random>` (store:186) ; `device_name='Navigateur Web'` | `gnplay_flutter_<Random.secure>` (token_storage.dart:184-198) ; `platform` (Android/iOS...) et `device_name = Platform.operatingSystemVersion` (device_repository.dart:19-38,71-90) | Mobile meilleur (alea cryptographique). `device_name` mobile = chaine de version OS, peu parlante ("Linux 6.x...") : preferer modele de l'appareil (device_info_plus). |
| Appareils : liste / revocation / limite | Ecran de blocage sur 400 "Maximum" (CODE MORT, devices.py evince automatiquement) ; revoque par `device_id` (AppInitializer:48-118) | Ecran `/devices` : liste, compteur `x/3`, badge "CET APPAREIL", revocation par id de ligne (devices_screen.dart:36-150 ; device_repository.dart:40-69) ; re-register + retry si playback 403 "device" (creator_content_provider.dart:55-88) | Mobile fonctionnel. Textes obsoletes : "Limite atteinte. Revoquez un appareil avant d'en connecter un nouveau" (devices_screen.dart:87-98) et commentaire sur "Maximum of 3 active devices" (creator_content_provider.dart:76-78) : le backend desactive silencieusement le plus ancien. Distinguer aussi la limite de SESSIONS (2) de celle d'APPAREILS (3). Le backend renvoie aussi les appareils `is_active=false` ; verifier que l'UI ne les compte pas. |
| Upload video : init + metadonnees | `init` (3 champs) puis `PATCH` titre/description/prix (upload:121-134) | `init` avec titre/description/prix directement (creator_repository.dart:201-229) | Mobile meilleur (1 appel de moins, pas d'etat intermediaire incoherent). |
| Upload : formats | `accept="video/mp4"` seulement | `FileType.video`, mime selon extension mp4/mov/webm (creator_content_provider.dart:374-384 ; publish_screen.dart:133, texte "MP4 ou MOV" l.324) | Mobile plus large (aligne sur le backend). |
| Upload : multipart / retry | 10 Mo/part (fixe par backend), concurrence 3, 5 essais, backoff 2s*n, URL non regeneree (upload:152-193) | Concurrence 3, 3 essais, backoff 2s*n, regenere l'URL presignee des la 2e tentative, lit le chunk par `RandomAccessFile` (creator_content_provider.dart:231-338) | Mobile meilleur sur l'expiration d'URL ; web a plus d'essais (5). Mobile : un seul `worker` echoue -> `Future.wait` echoue mais les autres workers continuent en arriere-plan (pas d'annulation cooperative). |
| Upload : progression | Octets reels, vitesse, ETA (upload:50-63, 506-527) | Par parts (`uploadedParts/totalParts`) (video_upload_progress.dart:33) | Mobile : granularite 10 Mo, pas de vitesse/ETA. A reprendre du web. |
| Upload : reprise apres coupure | Oui, si meme fichier re-selectionne (localStorage + `/status` + `/parts/presign` + `/parts`) (upload:66-82, 215-327) | NON. `getUploadStatus` existe (creator_repository.dart:324-336) mais n'est appele nulle part ; aucune persistance de session ; `GET /videos/upload/{id}/parts` jamais appele | Ecart majeur sur reseau mobile instable : app tuee = video orpheline en `UPLOADING`. A implementer (sauver `video_id/upload_id/path/size` en secure storage ; au demarrage proposer reprise). |
| Upload : annulation | Aucun appel `abort` (upload:344-349) | Bouton Annuler -> `POST /videos/upload/{id}/abort` best-effort (creator_content_provider.dart:361-372 ; creator_repository.dart:338-348) | Mobile meilleur. |
| Upload : miniature | Aucune (le worker en genere une, video_processing.py:111-135) | Champ "Miniature - URL de l'image" affiche (publish_screen.dart:454) mais JAMAIS envoye : `_startUpload` ne le transmet pas (publish_screen.dart:151-176) ; present dans l'edition (video_detail_screen.dart:1071) | Champ trompeur a l'etape publication : le retirer ou le brancher. Aucune route d'upload d'image de miniature n'existe (seulement `thumbnail_url` en PATCH). |
| Suivi du traitement | Polling 3 s, swallow des erreurs, jamais arrete, pas de timeout ni de nettoyage a la sortie de page (upload:351-374) | Polling 2 s, boucle `while(true)` sans timeout ; une erreur reseau fait echouer tout le flux (creator_content_provider.dart:340-357) | Les deux : bloques indefiniment sur `not_started` (mode R2 sans notification). Mobile : tolerer les erreurs transitoires (comme le web) mais ajouter un delai max. |
| Echec de transcodage | Retour a l'etape 1 + `error_message`, AUCUN retry | Ecran detail : "Relancer le traitement" -> `POST /internal/videos/{id}/retry-transcode` (video_detail_screen.dart:253-265 ; creator_repository.dart:350-364) | Mobile en avance. Note : route sous prefixe `internal` mais protegee par proprietaire/admin (videos.py:1158-1185). |
| Gestion des videos (liste, edition, suppression, publier/depublier) | ABSENTE (aucune page) | `GET /videos/mine` pagine par 100 (x50 pages) ; `PATCH /videos/{id}` (title, description, price, thumbnail_url, is_published) ; `DELETE /videos/{id}` avec confirmation (creator_repository.dart:72-96,159-199 ; videos_screen.dart ; video_detail_screen.dart:343-352, 1049-1078) | Mobile en avance (le web ne permet pas de depublier/supprimer/changer le prix). |
| Statistiques | ABSENTES | `GET /creators/me/analytics`, `GET /videos/{id}/analytics` (creator_repository.dart:98-110,541-552 ; video_stats_screen.dart) | Mobile en avance, MAIS les chiffres seront faux/zero : voir section 4 (`watch-progress` jamais appele). |
| Portefeuille : soldes | `GET /wallets/balance` (tout role) | `GET /payouts/balance` -> `wallet_balance` + `withdrawable_balance` (createur uniquement) (creator_repository.dart:55-70) | Mobile ne marche pas pour un viewer (403) -> toute la zone gains est gelee tant que non createur (creator_dashboard_screen.dart:64-72). |
| Portefeuille : historique | `GET /wallets/transactions` (+ icone credit/debit) | Idem, mappe `transaction_type` vers 6 categories (creator_repository.dart:382-399 ; wallet_ledger_entry.dart) ; lien vers le detail du retrait si `reference_type=='payout'` (earnings_screen.dart:142-150) | Equivalent ; mobile meilleur (types + navigation). Devise affichee : voir ligne "Devise". |
| Recharge | `POST /payments/topup/initiate` + redirection plein ecran vers DexPay (wallet:50-63) | Meme appel puis `launchUrl(externalApplication)` + polling 3 s x 100 (~5 min) + verification immediate au retour dans l'app (`didChangeAppLifecycleState`) (topup_controller.dart:34-131 ; topup_sheet.dart:30-53) | Mobile meilleur (polling 5 min vs 12 s). PROBLEME PARTAGE : apres paiement, DexPay redirige le navigateur vers `<FRONTEND_URL>/wallet/callback` (payments.py:65-74), page web qui exige une session web et renvoie sur `/login` pour un utilisateur mobile. Prevoir un deep link / page de retour neutre cote backend. |
| Callback de recharge | `wallet/callback` : 6 essais x 2 s, etats succes/echec/timeout (callback:18-63) | Pas de callback : statut suivi par polling uniquement (topup_controller.dart:96-119) | Pas d'equivalent necessaire si le polling suffit ; mais l'utilisateur mobile atterrit quand meme sur la page web (voir ci-dessus). |
| Retrait | Formulaire + validations (montant>0, <= solde, operateur) ; pas de min/max operateur ; pas de gestion speciale 429 (wallet:65-82) | Validation min du fournisseur (`min_amount`), "Solde insuffisant", bouton "Tout retirer", message dedie 429 "limite de demandes de retrait", prefill du telephone (payout_request_screen.dart:68-100, 187-203) | Mobile meilleur. Ne verifie pas `max_amount`. |
| Historique + suivi des retraits | Liste `GET /payouts` (statuts FR) ; pas de detail ; pas de rafraichissement | Ecran detail `GET /payouts/{id}` avec polling 6 s tant que pending/processing, affichage du motif d'echec (payout_detail_screen.dart:23-40,199-200). `payoutsProvider` (liste `GET /payouts`) est defini et invalide mais JAMAIS affiche (payout_providers.dart:12-18) ; l'acces se fait via les lignes du ledger | Mobile en avance sur le detail ; il manque une vraie liste d'historique des retraits (statut par statut). |
| Devise | "XOF" en dur | "GNF" en dur partout (gn_formatters.dart:16 ; earnings_screen.dart:185 ; payout_request_screen.dart:127,173 ; video_detail_screen.dart:865,1064 ; register_screen.dart:35) | INCOHERENCE : la recharge DexPay est creee en `XOF` quelle que soit la devise (dexpay_service.py:27) alors que le minimum de retrait depend de la devise du pays (GNF 10 000, payout_service.py:16-20,106-117). Choisir une devise unique cote API (champ `currency` dans les reponses) et ne plus la coder en dur. |
| Notifications | ABSENTES | `GET /notifications?limit&offset`, `GET /unread-count`, `PATCH /{id}/read`, `PATCH /read-all` (notification_repository.dart:15-78 ; notifications_screen.dart) | Mobile en avance, mais le backend ne cree qu'un type (`new_video`, destine aux ABONNES, video_processing.py:405-425) : liste vide pour un createur (confirme par docs/creator-app-design.md:117). Pas de notif "video prete", "retrait termine", "paiement recu". |
| Lecture video | `POST /videos/{id}/playback-session?device_id=` + hls.js + filigrane 15 s (watch:47-52, 70-85) | Meme appel + `video_player` HLS + filigrane 5 s ; re-register automatique et retry sur 403 "device" (creator_repository.dart:125-157 ; creator_content_provider.dart:55-88 ; full_video_player_screen.dart:124-209) | Mobile plus tolerant. A garder : jamais l'ancien `/videos/{id}/access` (cf. commentaire creator_repository.dart:112-124). Pas de mapping 403->achat ; message clair attendu. |
| Reporting de visionnage | Non | Non | Les deux omettent `POST /videos/{id}/watch-progress` : `view_count`, spectateurs uniques et taux de completion ne montent jamais (section 4). |
| Catalogue / achat / like / bibliotheque / recherche | `GET /videos`, `/library`, `POST /videos/{id}/purchase`, `like` (page.tsx, library, VideoCard) | Hors perimetre (app createur) | Normal. |

---------------------------------------------------------------------------------------------------

## 3. Bonnes idees du web a reprendre / defauts du web a NE PAS reproduire

### 3.1 A reprendre dans le mobile
1. Reprise d'upload (upload/page.tsx:66-82, 215-327) : sauvegarde `{videoId, uploadId, fileName, fileSize}` + `GET /videos/upload/{id}/status` + `POST .../parts/presign` des seules parts manquantes + `GET .../parts` pour reconstruire la liste ETag avant `complete`. Les routes backend sont deja la et le mobile a deja `getUploadStatus` et `presignUploadParts`.
2. Progression en octets reels + vitesse + ETA (upload:50-63) - le mobile n'a que `parts/total`.
3. Garde-fou `|| undefined` sur `page_name` vide (profile:40) pour eviter `""` UNIQUE en base.
4. Gestion explicite du premier plan : `reportPartProgress(part, 0, ...)` quand une part echoue (le fragment repart de zero dans la barre) (upload:175).
5. Mapping lisible des statuts de retrait (wallet:9-15) - le mobile a deja `PayoutStatus.label` (payout_request.dart) ; garder la meme terminologie FR.
6. Le web ne bloque PAS le polling sur une erreur reseau passagere (upload:370-372) : a reprendre cote mobile (creator_content_provider.dart:344-348 echoue aujourd'hui sur la moindre erreur).
7. Traitement des `failed|cancelled` / `timeout` en 3 etats distincts sur la recharge (callback:41-55,130-147) - le mobile fusionne timeout et echec en "failed" (topup_controller.dart:83-88) ; garder un etat "en attente de confirmation" distinct qui ne dit pas "echec".

### 3.2 Defauts du web a NE PAS reproduire
1. Rendu du `detail` brut de l'API dans le state d'erreur : sur un 422 FastAPI `detail` est un TABLEAU d'objets -> React leve "Objects are not valid as a React child" et casse la page (login:22, register:27-33,44,53, upload:209, profile:43, wallet:78). Le mobile traite deja `detail` liste -> `msg` (creator_repository.dart:662-669 ; auth_repository.dart:315-322) ; NB : device_repository.dart:127 et notification_repository.dart:103 ne traitent que `detail` chaine.
2. Code de limite d'appareils base sur un 400 "Maximum" qui n'existe plus (store:199 ; AppInitializer:48-118) ; et 403/400 de playback toujours traduits par "Contenu Premium - Acheter" (watch:56-58). Ne pas dupliquer cette confusion paiement/appareil.
3. Absence d'`abort` quand on recommence ou en cas d'echec (upload:207-211,344-349) -> videos `UPLOADING` orphelines et multipart R2 non nettoyes.
4. `PATCH /videos/{id}` apres `init` pour les metadonnees (upload:130-134) : un appel de plus et un etat intermediaire sans titre si le PATCH echoue.
5. Polling sans borne de temps ni nettoyage (`setInterval` jamais efface au demontage, upload:353) et qui avale 401/403/404 (upload:370).
6. Fichier restreint a `video/mp4` alors que le backend accepte webm et quicktime (upload:464).
7. Page callback dependante d'une session navigateur (callback:35-60, api.ts:68-74) : inutilisable pour un paiement lance depuis un autre appareil/app.
8. Recherche d'une video via la liste `GET /videos?limit=100` (watch:32-35) : fragile (pagination) et masque les videos non publiees du proprietaire. Utiliser `GET /videos/mine` (createur) ou une route detail.
9. Validation cote client quasi inexistante (register/login : non vide seulement) alors que le backend a des minimums (full_name>=6, password>=4, phone>=9, schemas/auth.py:12-19) ; prix saisi en texte converti par `Number()` (decimaux -> 422).
10. Ignorer le `detail` serveur pour l'avatar (profile:56) et ne pas controler taille/format avant envoi.
11. `confirm()`/`alert()` natifs pour les etapes d'argent (wallet:52-62, watch:89-100) et jeton dans `localStorage` (exposition XSS) ; sur mobile conserver le stockage securise.
12. `device_id` genere par `Math.random` (store:186), non cryptographique.
13. Devise "XOF" codee en dur (wallet) - meme erreur que le "GNF" code en dur du mobile.
14. Etat mort / variables inutilisees : `partsFinishedCount` jamais lu (upload:150,189,244,293), `maxMaxBufferLength` (option hls.js inexistante, VideoPlayer.tsx:18).

### 3.3 Defauts propres au mobile releves au passage (a corriger)
- Bootstrap : echec reseau -> session videe (auth_controller.dart:268-271) alors que `AuthenticatedClient` sait deja distinguer reseau vs 4xx.
- Compte a rebours OTP factice "00:45" (register_screen.dart:384-390).
- Champ miniature de la publication non branche (publish_screen.dart:454 / 151-176).
- `payoutsProvider` jamais affiche ; `getUploadStatus` jamais appele.
- Textes de limite d'appareils obsoletes (devices_screen.dart:87-98) et libelle "3 appareils" vs limite de sessions = 2.
- Validation mot de passe/reset trop faible (forgot_password_screen.dart:152,166).
- Libelles "GNF" en dur.

---------------------------------------------------------------------------------------------------

## 4. Routes backend (app/api/v1/routes/) : utilisees par le web, par le mobile, ou aucun

Legende : W = utilise par le web, M = utilise par le mobile, (indirect) = via le lecteur HLS.

| Route | Fichier:ligne | W | M | Remarque |
|---|---|---|---|---|
| POST /auth/request-otp | auth.py:27 | oui | oui | |
| POST /auth/verify-otp | auth.py:33 | oui | oui | |
| POST /auth/refresh-token | auth.py:39 | oui | oui | |
| POST /auth/login | auth.py:45 | oui | oui | |
| POST /auth/register | auth.py:55 | oui | oui | |
| POST /auth/logout | auth.py:62 | oui | oui | |
| POST /auth/request-password-reset | auth.py:67 | NON | oui | |
| POST /auth/reset-password | auth.py:73 | NON | oui | |
| GET /users/me | users.py:19 | oui | oui | |
| PATCH /users/me | users.py:24 | oui | oui | |
| POST /users/me/become-creator | users.py:34 | oui | oui | |
| POST /users/me/profile-picture | users.py:41 | oui | oui | |
| GET /wallets/balance | wallets.py:14 | oui | NON | Le mobile utilise `payouts/balance`. |
| GET /wallets/transactions | wallets.py:22 | oui | oui | |
| POST /devices/register | devices.py:16 | oui | oui | |
| GET /devices | devices.py:83 | oui | oui | |
| DELETE /devices/{device_id} | devices.py:91 | oui | oui | accepte id de ligne ou device_id |
| POST /payments/topup/initiate | payments.py:19 | oui | oui | |
| GET /payments/topup/status/{reference} | payments.py:139 | oui | oui | |
| GET /payments/topup/success , /failure | payments.py:65,71 | redirection DexPay | redirection DexPay | Redirigent vers le FRONTEND web : a adapter pour le mobile |
| POST /payments/topup/webhook | payments.py:77 | serveur | serveur | DexPay -> backend |
| GET /payouts/balance | payouts.py:22 | oui | oui | createur strict |
| GET /payouts/providers | payouts.py:29 | oui | oui | |
| POST /payouts/request | payouts.py:41 | oui | oui | 5/heure |
| GET /payouts | payouts.py:76 | oui | defini, jamais affiche | |
| GET /payouts/{payout_id} | payouts.py:87 | NON | oui | rafraichit le statut DexPay |
| POST /videos/upload/init | videos.py:174 | oui | oui | pas de controle de role createur |
| POST /videos/upload/{id}/parts/presign | videos.py:864 | oui (reprise) | oui (retry) | |
| POST /videos/upload/{id}/parts/confirm | videos.py:906 | oui | oui | |
| GET /videos/upload/{id}/parts | videos.py:838 | oui (reprise) | NON | utile pour la reprise mobile |
| GET /videos/upload/{id}/status | videos.py:945 | oui (reprise) | defini, jamais appele | |
| POST /videos/upload/{id}/complete | videos.py:308 | oui | oui | |
| POST /videos/upload/{id}/abort | videos.py:981 | NON | oui | le web devrait l'appeler |
| GET /videos/{id}/processing-status | videos.py:1016 | oui | oui | |
| PATCH /videos/{id} | videos.py:420 | oui (meta apres init) | oui | |
| DELETE /videos/{id} | videos.py:470 | NON | oui | soft-delete si deja achetee |
| GET /videos (catalogue public) | videos.py:535 | oui | NON | hors perimetre mobile |
| GET /videos/mine | videos.py:553 | NON | oui | |
| POST /videos/{id}/purchase | videos.py:596 | oui | NON | viewer |
| POST/DELETE /videos/{id}/like | videos.py:773,807 | oui | NON | viewer |
| GET /videos/{id}/access | videos.py:713 | NON | NON | OBSOLETE : URL presignee du master seul, inutilisable pour lire du HLS chiffre (commentaire creator_repository.dart:112-124). Candidat a suppression. |
| PUT /videos/upload/local/{upload_id}/{part} | videos.py:1040 | NON | NON | dev (`USE_LOCAL_STORAGE`) uniquement |
| POST /internal/videos/r2-notification | videos.py:1072 | serveur | serveur | R2 -> backend |
| POST /internal/videos/test-r2-notification | videos.py:1116 | NON | NON | outil de test |
| POST /internal/videos/{id}/retry-transcode | videos.py:1158 | NON | oui | |
| GET /library | library.py:13 | oui | NON | viewer |
| POST /videos/{id}/playback-session | streaming.py:64 | oui | oui | device_id en query |
| GET /stream/{id}/master.m3u8 , /key , /{filename} | streaming.py:175,199,222 | (indirect) | (indirect) | via le lecteur HLS |
| GET /videos/{id}/analytics | analytics.py:18 | NON | oui | |
| GET /creators/me/analytics | analytics.py:64 | NON | oui | |
| GET /notifications , /unread-count , PATCH /{id}/read , /read-all | notifications.py:13,30,39,56 | NON | oui | |
| POST /videos/{id}/watch-progress | watch_history.py:33 | NON | NON | **CRITIQUE** : seule route qui incremente `view_count` et alimente spectateurs uniques / vues completees / taux de completion (watch_history.py:51-73 ; analytics.py:28-48). Aucun client ne l'appelle : toutes les stats de vues restent a 0. Attention : le proprietaire passe aussi le controle d'acces (watch_history.py:19-23) donc sa propre lecture gonflerait les vues ; exclure le proprietaire cote backend avant de l'appeler depuis l'app createur. |
| GET /videos/continue-watching , /videos/history | watch_history.py:89,110 | NON | NON | viewer |
| POST/DELETE /videos/{id}/favorite , GET /favorites | favorites.py:22,44,60 | NON | NON | viewer |
| POST/GET/PATCH/DELETE /playlists, /playlists/{id}, .../videos/{vid} | favorites.py:90-179 | NON | NON | viewer |
| POST/DELETE /creators/{id}/follow | follows.py:17,44 | NON | NON | viewer |
| GET /creators/me/following , GET /feed | follows.py:60,88 | NON | NON | viewer |
| GET /creators/{id}/followers/count | follows.py:78 | NON | NON | redondant avec `total_followers` de `/creators/me/analytics` |
| POST /videos/{id}/download/authorize , GET manifest , GET key , DELETE | downloads.py:60,121,159,176 | NON | NON | telechargement hors-ligne (viewer) |
| GET /admin/fraud-flags , PATCH /admin/fraud-flags/{id} , PATCH /admin/users/{id}/deactivate , /reactivate | admin.py:18,38,55,67 | NON | NON | admin uniquement (pas de client) |

Routes utiles au createur mais absentes des deux clients (priorite decroissante) :
1. `POST /videos/{id}/watch-progress` : sans elle, `Vues`, `Spectateurs`, `Taux de completion` du mobile restent a 0 (video_detail_screen.dart:853-905). A appeler depuis le lecteur "viewer" (web/watch et une future app spectateur), pas depuis l'apercu createur.
2. `GET /videos/upload/{id}/parts` : indispensable pour terminer une reprise d'upload mobile.
3. `GET /videos/{id}/access` : a supprimer (obsolete et trompeur).
4. `POST /videos/upload/{id}/abort` cote web.
5. `GET /creators/{id}/followers/count` : a ignorer (deja dans l'analytics).
6. `GET /payouts` cote UI mobile (liste d'historique des retraits).

Manques cote backend qui impactent le createur (hors "route existante non utilisee") :
- Pas de notification pour les createurs (video prete, paiement recu, retrait termine) ; seules les notifications `new_video` aux abonnes existent.
- Pas de route d'upload de miniature (seulement `thumbnail_url` libre via PATCH).
- Pas de route de changement de mot de passe avec ancien mot de passe ; pas de liste des sessions.
- `POST /videos/upload/init` sans restriction de role.
- `UserService.update_user` : pas de gestion du doublon/chaine vide pour `page_name` (UNIQUE).
- Devise : topup toujours `XOF` cote DexPay vs minimum de retrait par devise du pays ; aucune devise renvoyee a l'API.
- Redirections de paiement figees sur `FRONTEND_URL` (payments.py:65-74) : aucun parametre pour un retour mobile.
