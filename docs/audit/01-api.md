# Audit exhaustif de l'API GNPlay (FastAPI) pour l'app mobile Créateur

Périmètre : `/home/saliou/Bureau/gnplay/app` (lecture seule). Tous les chemins `app/...` sont relatifs à `/home/saliou/Bureau/gnplay/`.
Méthode : lecture du code + énumération réelle des routes montées (`app.routes` importé avec des variables d'env factices, SQLite mémoire) -> **84 endpoints sous `/api/v1`** (+ 2 de santé hors préfixe + docs OpenAPI). Les routes de `internal_router` sont montées sous `/api/v1/internal/videos/...` (`app/main.py:136`).
Convention : « R: » = routes, « S: » = service, `fichier:ligne`. « à vérifier » = non confirmé par le code seul.

---

## 0. Conventions transverses (à lire avant tout)

### 0.1 Authentification
- Schéma : `OAuth2PasswordBearer(tokenUrl="api/v1/auth/login")` (`app/core/dependencies.py:13`). Header `Authorization: Bearer <access_token>`.
- `get_current_user` (`dependencies.py:19-41`) : décode le JWT, exige `type == "access"`, charge l'utilisateur **en base** à chaque requête. Erreurs communes à tous les endpoints « utilisateur connecté » :
  - header absent -> 401 `{"detail":"Not authenticated"}` (comportement FastAPI par défaut)
  - JWT invalide/expiré -> 401 `"Invalid or expired token"` (`core/security.py:83-87`, avec `WWW-Authenticate: Bearer`)
  - token de type refresh -> 401 `"Access token required"` (`dependencies.py:22-26`)
  - pas de `sub` -> 401 `"Invalid token"` ; user introuvable -> 401 `"User not found"` (`:31`, `:36`)
  - compte désactivé (`is_active=False`) -> **403** `"Votre compte est desactivé veuillez contacter un administrateur"` (`:39`)
- **Rôles** (`app/enums/user.py`) : `UserRole` = `"admin"`, `"viewer"`, `"creator"` (valeurs en minuscules). Rôle par défaut à l'inscription : `viewer` (`models/user.py:17`).
- `require_roles(*roles)` (`dependencies.py:49-55`) : le rôle est lu depuis **la base** (`current_user.role`), pas depuis le claim `role` du JWT -> un changement de rôle (ex. `become-creator`) est effectif immédiatement sans re-login. Si le rôle n'est pas dans la liste -> 403 `"Vous n'avez pas les permissions nécessaires pour accéder à cette ressource"`.
  - `require_roles` n'est utilisé que dans `wallets.py:12` (ADMIN, VIEWER, CREATOR = tout utilisateur), `payouts.py:19` (**CREATOR uniquement** : un ADMIN est refusé), `admin.py:15` (ADMIN).
  - Beaucoup d'autres endpoints font un contrôle de rôle/propriété « à la main » (ex. `user.role != UserRole.ADMIN`).
- **Aucun endpoint vidéo n'exige le rôle CREATOR** : `POST /videos/upload/init` est ouvert à tout utilisateur connecté (viewer compris). Seuls `payouts/*` imposent CREATOR ; `creators/me/analytics` impose CREATOR ou ADMIN.
- Durées de token : `ACCESS_TOKEN_EXPIRE_MINUTES`, `REFRESH_TOKEN_EXPIRE_DAYS` viennent de l'env (`.env.example` : 150 min / 14 jours ; valeurs de prod à vérifier).
- Les access tokens ne sont **pas** liés à une session : `logout` / éviction de session ne révoquent que le refresh token ; l'access token reste valide jusqu'à son expiration (aucune vérification de session dans `get_current_user`).

### 0.2 Format d'erreur
- Erreurs métier : `{"detail": "<message>"}`. Validation Pydantic : 422 avec `detail` = **liste** d'objets `{type, loc, msg, input}`.
- **Rate limit (slowapi)** : 429 avec corps `{"error": "Rate limit exceeded: 5 per 1 minute"}` -> clé **`error`** et non `detail` (`slowapi/extension.py::_rate_limit_exceeded_handler`, branché `main.py:96-98`). Clé de limitation : IP (`get_remote_address`, `core/limiter.py:7`) et **pas** l'utilisateur ; derrière un proxy (Coolify) sans `--proxy-headers` configuré (`Dockerfile:54` : `uvicorn app.main:app --host 0.0.0.0 --port 8000`), tous les clients peuvent partager la même IP vue -> à vérifier en prod.
- Beaucoup de routes enveloppent les exceptions en 500 avec `detail = f"... {str(e)}"` (fuite du message interne).

### 0.3 Types & formats
- Tous les `id` = UUID string (36 car., `core/database.py:30`). Montants = **entiers** (`Integer`), « XOF » par convention (voir §4). Dates : `datetime` ISO-8601 (aware si Postgres).
- Enums renvoyés **en minuscules** (ex. `"ready"`, `"credit"`, `"earning"`, `"viewer"`), car `str, Enum` sérialisé par valeur (vérifié : `VideoResponse.model_dump_json()` -> `"status":"ready"`). En base, Postgres stocke les **noms** en majuscules (`READY`), invisible côté API.
- CORS : seules `FRONTEND_URL` (+ `http://localhost:3000` si DEBUG) sont autorisées (`main.py:104-116`) ; sans effet pour une app mobile native.

### 0.4 Schémas réutilisés
- **UserRead** (`schemas/auth.py:20-31`) : `id:str, full_name:str(min 6), phone_number:str(min 9), page_name:str|null, bio:str|null, avatar:str|null, role:"admin"|"viewer"|"creator", is_active:bool, is_superuser:bool, is_verified:bool, created_at, updated_at`. (`bio`/`avatar` valent `null` si NULL en base, malgré le défaut `""` du schéma.)
- **VideoResponse** (`schemas/videos.py:67-83`) : `id, user_id, title, description|null, thumbnail_url|null, preview_url|null, price:int, duration:int(secondes), status:str, is_published:bool, view_count:int, likes_count:int, created_at, updated_at`. **Absents** : `playback_url, width, height, codec_*, error_message`.
- **VideoWithStatsResponse** = VideoResponse + `revenue:int` (`schemas/videos.py:86-87`).
- **TokenResponse** : `{access_token, refresh_token, token_type:"bearer"}`.
- **OTPRequestResponse** (`schemas/otp_codes.py:13-18`) : `{phone_number, otp_type:"register"|"reset_password", expires_at, debug_code:str|null}` (`debug_code` rempli seulement si `DEBUG=True` et pas de fournisseur NG).
- **LedgerEntry (ORM brut, sans response_model)** : colonnes `id, created_at, updated_at, wallet_id, user_id, amount:int, direction:"credit"|"debit", transaction_type:"topup"|"purchase"|"earning"|"commission"|"refund"|"withdrawal", reference_id:str|null, reference_type:str|null ("video"|"topup"|"payout"), description:str|null` (`models/wallets.py:22-36`).
- **PayoutRequest (ORM brut)** : `id, created_at, updated_at, user_id, wallet_id, amount:int, fees:int|null, status:"pending"|"processing"|"completed"|"failed"|"cancelled", reference, gateway_payout_id|null, destination_phone, operator, country_iso, failure_reason|null, processed_at|null` (`models/payouts.py:17-34`).

---

## 1. Fiches endpoint par endpoint

> Tous les chemins sont à préfixer par `/api/v1` sauf mention contraire.

### 1.1 Auth (`app/api/v1/routes/auth.py`, service `app/services/auth_service.py`)

#### POST `/api/v1/auth/request-otp` — auth.py:27-30
- Auth : aucune. Rate limit : **5/minute/IP**. Succès **201**.
- Body `OTPRequest` : `phone_number:str` (requis, aucune validation/normalisation de format), `otp_type:"register"|"reset_password"` (défaut `"register"`).
- Réponse : `OTPRequestResponse` (voir §0.4).
- Erreurs (S: auth_service.py:55-108) : 400 `"Vous avez déjà un compte, connectez-vous"` (type register et numéro existant, :64) ; 429 `"Trop de tentatives, ressayez dans 1min"` (un OTP non utilisé/non révoqué créé < 1 min, quel que soit son type, :66-70) ; NG Messaging activé : 400 avec le `detail` du fournisseur (erreur 4xx) ou 502 (5xx/réseau, ex. `"Service d'envoi de code indisponible, réessayez."`) (:81-84) ; 429 rate limit (`{"error":...}`).
- Effets : révoque l'OTP actif précédent (`is_revoked=True`) ; si `NG_MESSAGING_API_KEY` défini, le fournisseur génère/envoie (WhatsApp/SMS) le code et seul `provider_request_id` est stocké (`ng_messaging_service.py:68-73`) ; sinon code local haché (bcrypt) — loggué si DEBUG. Expiration `OTP_CODE_EXPIRES_MINUTES` (5 dans `.env.example`), longueur `OTP_CODE_LENGTH` (6).

#### POST `/api/v1/auth/verify-otp` — auth.py:33-36
- Auth : aucune. Rate limit **10/minute/IP**. Succès **204** (sans corps).
- Body `VerifyOtpRequest` : `phone_number:str`, `otp_type` (défaut register, **ignoré** : la requête filtre toujours `OTPType.REGISTER`, auth_service.py:128), `code:str`.
- Erreurs : 400 `"OTP Invalide ou Déjà expiré"` (aucun OTP valide, :136) ; 400 `"Code OTP Invalide"` (code local erroné, :138/:123) ; avec NG : 400 = `detail` du fournisseur (ex. « Code incorrect — N tentative(s) restante(s) ») ou 502.
- Effets : marque l'OTP `is_used=True`. Le compteur `attempts_count` du modèle n'est jamais incrémenté (pas de verrouillage local ; en mode local seul le rate limit IP protège le brute-force).

#### POST `/api/v1/auth/register` — auth.py:55-59
- Auth : aucune. Rate limit **5/minute/IP**. Succès **201**.
- Body `UserCreate` : `full_name:str (min_length=6)`, `phone_number:str (min_length=9)`, `country_iso2:str` (ex. `"GN"`), `password:str (min_length=4)`.
- Réponse : `UserRead` (role `"viewer"`, `is_verified:true`, `is_active:true`). **Aucun token renvoyé** : appeler ensuite `/auth/login`.
- Erreurs (auth_service.py:144-184) : 400 `"Vous devez d'abord valider votre numéro de téléphone"` (aucun OTP register `is_used=True` pour ce numéro, quel que soit son âge, :157) ; 409 `"Un compte avec ce numéro de téléphone existe déjà"` (:162) ; 404 `"Ce pays n'existe pas"` (:16 country_service) ; 422.
- Effets : crée `User` + `Wallet(balance=0)` (:168-182).

#### POST `/api/v1/auth/login` — auth.py:45-52
- Auth : aucune. Rate limit **10/minute/IP**. Succès **200**.
- Body : **`application/x-www-form-urlencoded`** (`OAuth2PasswordRequestForm`, PAS du JSON) : `username` = numéro de téléphone, `password`. (`grant_type`, `scope`, `client_id`, `client_secret` facultatifs.) Header optionnel `X-DEVICE-NAME` (stocké comme `device_name` de la session, défaut `"api request"`, auth_service.py:230).
- Réponse : `TokenResponse`.
- Erreurs : 401 `"Numéro de téléphone ou Mot de passe incorrect"` (utilisateur inconnu, **inactif**, **non vérifié**, ou mauvais mot de passe — :197/:201 ; un compte désactivé reçoit donc ce 401, pas le 403 de `get_current_user`).
- Effets : crée une `Session` (refresh token en base). Limite `MAX_SESSIONS_PER_USER` (2 par défaut) : les sessions les plus anciennes (par `expires_at`) sont **révoquées** pour faire de la place (:209-217) — pas de blocage.

#### POST `/api/v1/auth/refresh-token` — auth.py:39-42
- Auth : aucune. Rate limit **30/minute/IP**. Succès **200**.
- Body `RefreshTokenRequest` : `refresh_token:str`. Réponse `TokenResponse` (nouvelle paire).
- Erreurs : 401 `"Invalid or expired token"` (JWT illisible/expiré) ; 401 `"Refresh token invalide ou expiré"` (mauvais type ou session absente/révoquée/expirée, :262).
- Effets : **rotation** : l'ancienne session est révoquée, une nouvelle est créée (même device_name/ip/user_agent). Réutiliser un ancien refresh token -> 401. Les JWT n'ont pas de `jti` : deux refresh créés dans la même seconde pour le même user peuvent être identiques (à vérifier).
- NB : le chemin est **`/auth/refresh-token`** (le doc `docs/creator-app-design.md` écrit `/refresh`).

#### POST `/api/v1/auth/logout` — auth.py:62-64
- Auth : utilisateur connecté. Pas de rate limit. Succès **204**.
- Body `LogoutRequest` : `refresh_token:str|null`. Si fourni : révoque cette session (si elle appartient à l'user, silencieux sinon) ; si absent : révoque **toutes** les sessions actives (auth_service.py:313-335).
- Le body est obligatoire (au moins `{}`) : `logout_request` n'a pas de défaut -> envoyer `{}` sinon 422.

#### POST `/api/v1/auth/request-password-reset` — auth.py:67-70
- Auth : aucune. Rate limit **5/minute/IP**. Succès **202**.
- Body `ResetPasswordRequest` : `phone_number:str` (+ `otp_type` hérité, ignoré/forcé à reset_password). Réponse `OTPRequestResponse`.
- Erreurs : 404 `"Utilisateur inexistant"` (énumération de comptes possible) ; mêmes 429/400/502 que request-otp.

#### POST `/api/v1/auth/reset-password` — auth.py:73-76
- Auth : aucune. Rate limit **10/minute/IP**. Succès **204**.
- Body `ResetPassword` : `phone_number:str, code:str, new_password:str` (**aucune contrainte de longueur**, contrairement à register `min 4`).
- Erreurs : 404 `"Utilisateur inexistant"` ; 400 `"Code OTP invalide ou expiré"` (:304) ; 400 `"Code OTP invalide"` (:123/:306) ; NG : 400/502.
- Effets : change le hash du mot de passe, marque l'OTP utilisé. **Ne révoque pas** les sessions existantes.

### 1.2 Users (`app/api/v1/routes/users.py`, service `app/services/user_service.py`)

#### GET `/api/v1/users/me` — users.py:95-97
- Auth : utilisateur connecté. Succès 200. Réponse `UserRead`.
- **Piège** : le `response_model` valide `full_name` avec `min_length=6` -> si le nom en base est plus court (possible via PATCH, voir ci-dessous), la réponse lève une ResponseValidationError -> **500** (vérifié en important `UserRead`).

#### PATCH `/api/v1/users/me` — users.py:100-107
- Auth : connecté. Succès 200. Body `UserUpdate` (`schemas/users.py`) : `full_name:str|null`, `page_name:str|null`, `bio:str|null` (tous optionnels, **aucune contrainte**). Seuls les champs non `null` sont modifiés (impossible de vider un champ avec `null`).
- Réponse `UserRead`. Erreurs : 404 `"User not found"` (:25 user_service).
- **Pièges** : (1) `page_name` est `unique` en base (`models/user.py:15`) ; un doublon provoque une `IntegrityError` non interceptée -> **500** (`get_by_page_name` existe mais n'est pas utilisé, user_service.py:19). (2) `full_name` < 6 caractères est accepté en écriture mais fait échouer la réponse (500) et **tous les `GET /users/me` suivants** (validation `UserRead`). Idem pour `/admin/users/*` qui renvoient `UserRead`.

#### POST `/api/v1/users/me/become-creator` — users.py:110-114
- Auth : connecté. Succès 200. Pas de body. Réponse `UserRead`.
- Effets : `viewer -> creator` ; déjà creator = no-op renvoyant l'user ; **admin -> 400** `"Seul un compte standard peut devenir créateur"` (user_service.py:55). Irréversible via l'API. Pas de nouveau JWT nécessaire (rôle lu en base).

#### POST `/api/v1/users/me/profile-picture` — users.py:117-146
- Auth : connecté. Succès 200. Body : `multipart/form-data`, champ **`file`** (UploadFile).
- Réponse : `{"profile_picture_url": "<url publique>"}` (dict construit à la main) ; met aussi à jour `user.avatar`.
- Validations : taille > `MAX_IMAGE_SIZE` (2 Mo) -> 400 `"La taille du fichier dépasse la limite autorisée"` ; extension (après le dernier `.`, insensible à la casse) hors `jpeg|png|jpg` -> 400 `"Format d'image non valide"` (webp/heic refusés ; un nom de fichier sans point est refusé). Le `content_type` n'est pas vérifié. Toute exception d'upload -> 500 avec `str(e)`.
- Stockage : `profile-pictures/{user.id}/{uuid}.{ext}` dans le bucket public R2. L'ancien avatar n'est pas supprimé. En stockage local l'URL est `http://localhost:8000/local_storage/public/...` (codé en dur, r2_service.py:53).

### 1.3 Wallets (`app/api/v1/routes/wallets.py`)

#### GET `/api/v1/wallets/balance` — wallets.py:160-165
- Auth : connecté + `require_roles(ADMIN, VIEWER, CREATOR)` (= tout le monde). Succès 200.
- Réponse (dict) : `{"balance": int}` — `Wallet.balance` brut (**tout** : recharges + gains - achats - retraits). `{"balance": 0}` si pas de wallet. Ce n'est PAS le solde retirable (voir `/payouts/balance`).

#### GET `/api/v1/wallets/transactions` — wallets.py:168-173
- Auth : idem. Succès 200. **Pas de pagination, pas de tri explicite** (relation SQLAlchemy `wallet.ledger_entries`, ordre indéfini), **pas de response_model**.
- Réponse : liste de `LedgerEntry` ORM (colonnes en §0.4) ; `[]` si pas de wallet. Descriptions mélangées : anglais (`"Purchase of video '<titre>'"`, `"Earning from video '<titre>'"`), français (`"Recharge de crédit via DexPay"`, `"Retrait des gains créateur"`, `"Remboursement suite à échec de retrait"`).
- Note : l'ancien `POST /wallets/topup` (crédit sans paiement) est supprimé (wallets.py:176-180).

### 1.4 Videos (`app/api/v1/routes/videos.py`)

#### POST `/api/v1/videos/upload/init` — videos.py:174-301
- Auth : connecté (**tout rôle**). Pas de rate limit. Succès **200** (pas de `status_code` -> 200, pas 201).
- Body `VideoInitRequest` (`schemas/videos.py:7-13`) : `filename:str` (requis), `file_size:int` (requis, aucune borne), `mime_type:str` (requis), `title:str|null` (défaut -> `filename` complet avec extension), `description:str|null`, `price:int|null` (défaut 0, `ge=0`, pas de max).
- Réponse (dict) : `{video_id, upload_id, object_key, chunk_size, total_parts, max_parallel_uploads:3, expires_in:3600, file_key, part_size, parts:[{"part_number":int,"url":str}, ...]}` (les 4 clés `file_key, part_size, parts` sont « compat » ; **`parts[].url`** ici vs **`parts[].upload_url`** dans `/parts/presign`). `chunk_size` = 10 485 760 (10 Mo) ; `total_parts = ceil(file_size / 10 Mo)`.
- Erreurs : 400 `"Invalid file size"` (`file_size <= 0`) ; 400 `"Unsupported video format"` (mime hors `video/mp4`, `video/webm`, `video/quicktime`) ; 500 `"Upload init failed: <exception>"` (dont : `file_size` > 2 147 483 647 octets car colonne `Integer`, models/videos.py:53 + migration 404e89bb25d4:44 ; R2 indisponible).
- Effets : crée `Video(status="uploading", is_published=false, duration=0, price)` + `VideoUpload(id=upload_id S3, upload_status="pending")` + multipart R2 (bucket privé) ; la clé est `videos/{user_id}/{uuid}.{ext}`.
- Pièges : toutes les URLs présignées de **toutes** les parts sont générées d'emblée (pour un gros fichier, réponse volumineuse) ; en stockage local les URLs pointent `http://localhost:8000/api/v1/videos/upload/local/{upload_id}/{n}` (codé en dur, r2_service.py:189).

#### POST `/api/v1/videos/upload/{video_id}/parts/presign` — videos.py:864-903
- Auth : connecté, propriétaire. Succès 200. Body `PartsPresignRequest` : `upload_id:str`, `parts:List[int]`.
- Réponse : `{"parts":[{"part_number":int,"upload_url":str,"expires_in":3600}]}`.
- Erreurs : 404 `"Video not found or access denied"` ; 404 `"Video upload session not found"` ; 400 `"Cannot presign more than 100 parts at once"` ; 500 `"Failed to generate presigned URLs: ..."` (**dont** l'`HTTPException` 400 `"Invalid part number N"` (`part_num < 1`) qui est capturée par le `except Exception` englobant et devient un 500 — videos.py:884-903).

#### POST `/api/v1/videos/upload/{video_id}/parts/confirm` — videos.py:906-942
- Auth : connecté, propriétaire. Succès 200. Body `PartsConfirmRequest` : `part_number:int, etag:str, size:int`.
- Réponse `{"status":"confirmed"}`. Idempotent (si la part existe déjà, rien n'est écrit — **l'ETag n'est pas mis à jour**).
- Erreurs : 404 (mêmes messages) ; 500 `"Failed to confirm part: ..."`.

#### GET `/api/v1/videos/upload/{video_id}/parts` — videos.py:838-861
- Auth : propriétaire. Succès 200. Réponse `{"parts":[{"part_number":int,"etag":str|null}]}` triée par `part_number` (parts **confirmées** uniquement). Erreur : 404 `"Video not found or access denied"`.

#### GET `/api/v1/videos/upload/{video_id}/status` — videos.py:945-978
- Auth : propriétaire. Succès 200.
- Réponse : `{video_id, status (statut vidéo, minuscule), upload_id, chunk_size:10485760, total_parts, uploaded_parts:[int], missing_parts:[int], expires_at: ISO (= created_at de l'upload + 1h)}`.
- Erreurs : 404 `"Video not found or access denied"` ; 404 `"Video upload session not found"` (**aussi une fois le transcodage réussi**, car l'enregistrement `VideoUpload` est supprimé par le worker, workers/video_processing.py:331-334).
- Piège : `expires_at` est calculé (created_at + 1h) alors que l'upload multipart R2 n'expire pas ; les URLs présignées, elles, expirent à 3600 s.

#### POST `/api/v1/videos/upload/{video_id}/complete` — videos.py:308-417
- Auth : propriétaire (filtre `Video.user_id == user.id`). Succès **202**.
- Body `CompleteMultipartUploadRequest` : `upload_id:str`, `parts:[{"PartNumber":int,"ETag":str}]` (clés en PascalCase !).
- Réponse (dict) : `{"message":"Upload completed","video_id":str,"status":"queued"}` si `USE_LOCAL_STORAGE`, sinon `"status":"uploaded_waiting_r2_notification"` — **valeur codée en dur même si le job ARQ vient d'être enfilé** (videos.py:402-406 : le vrai statut vidéo peut déjà être `queued`).
- Erreurs : 404 `"Video not found"` ; 404 `"Upload not found"` ; 500 `"Complete upload failed: <exception>"` (R2 : parts manquantes, etc.).
- Effets : `upload.upload_status="uploaded"`. Mode local : `video.status="queued"` + job `queued` + transcodage lancé en BackgroundTask. Mode R2 : `video.status="uploaded"` ; si ARQ dispo -> enfile `process_video`, statut `queued` ; sinon si `TRANSCODE_WEBHOOK_URL` -> `queued` + appel du webhook interne ; sinon (ou si l'enfilage échoue, exception avalée :399-400) la vidéo **reste `uploaded`** en attendant la notification R2 (`/internal/videos/r2-notification`) — réponse 202 quand même.

#### POST `/api/v1/videos/upload/{video_id}/abort` — videos.py:981-1013
- Auth : propriétaire. Succès **200**. Réponse `{"message":"Upload aborted successfully"}`.
- Erreurs : 404 `"Video not found or access denied"` ; 404 `"Video upload session not found"` ; 500 `"Abort failed: ..."`.
- Effets : abort R2 (erreur ignorée, `print`), supprime parts + upload + **la vidéo** (hard delete). **Aucun contrôle de statut** : un propriétaire peut « abort » une vidéo `uploaded/queued/processing/failed` ; après succès du transcodage l'upload n'existe plus donc 404.

#### GET `/api/v1/videos/{video_id}/processing-status` — videos.py:1016-1037
- Auth : propriétaire ou ADMIN. Succès 200.
- Réponse : `{video_id, status: <statut du JOB>, progress:int(0-100), attempts:int, error_message:str|null}` ; sans job : `status:"not_started", progress:0, attempts:0`. **Le statut est celui du `VideoTranscodeJob`** (chaîne libre : `queued|processing|ready|failed`), pas `Video.status`.
- Erreurs : 404 `"Video not found"` ; 403 `"Access denied"`.
- Piège : `progress` ne vaut que 0 (queued/processing) ou 100 (ready) — le worker ne met jamais à jour la progression en cours (workers/video_processing.py:68-79, 308-313). `attempts` n'est incrémenté qu'aux relances.

#### POST `/api/v1/internal/videos/{video_id}/retry-transcode` — videos.py:1158-1190 (router interne, **auth utilisateur JWT**, pas le token R2)
- Auth : propriétaire ou ADMIN. Succès 200. Pas de body.
- Réponse `{"message":"Transcode job retried","status":"queued"}`.
- Erreurs : 404 `"Video not found"` ; 403 `"Access denied"` ; 400 `"Cannot retry: source upload record not found."` (vidéo déjà traitée avec succès : upload supprimé et source supprimée de R2) ; 503 `"Video processing queue is not available"` (R2 sans ARQ ni webhook ; **le statut `queued` a déjà été commité** -> vidéo bloquée en `queued`) ; 500 `"Retry failed: ..."`.
- Effets : `video.status="queued"`, job remis à `queued/0%`, transcodage replanifié. Utile uniquement pour `failed` (la source n'est conservée que tant que le transcodage n'a pas réussi). Pas de contrôle de statut (relancer un `processing` provoquerait un double traitement).

#### PATCH `/api/v1/videos/{video_id}` — videos.py:420-467
- Auth : propriétaire ou ADMIN. Succès 200. Body `VideoUpdateRequest` (`schemas/videos.py:58-63`) : `title:str|null (min_length=1)`, `description:str|null`, `price:int|null (ge=0)`, `thumbnail_url:str|null` (URL libre, **aucune validation**), `is_published:bool|null`. Seuls les champs non `null` sont écrits (impossible d'effacer description/thumbnail).
- Réponse : `VideoResponse`.
- Erreurs : 404 `"Video not found"` ; 403 `"Vous n'avez pas les permissions nécessaires pour modifier cette vidéo"` ; 500 `"Failed to update video metadata: ..."`. (Le 400 `"Price must be greater than or equal to 0"` :440-444 est **inatteignable** : Pydantic renvoie 422 avant.)
- Effets : **aucun contrôle de statut** : on peut passer `is_published=true` sur une vidéo `uploading/failed/deleted` (elle reste invisible des listes car celles-ci exigent aussi `status in (ready, published)`) ; modifier le prix n'affecte que les achats futurs.
- Pas d'upload de miniature (aucun endpoint) : `thumbnail_url` doit être une URL déjà hébergée.

#### DELETE `/api/v1/videos/{video_id}` — videos.py:470-532
- Auth : propriétaire ou ADMIN. Succès **204**.
- Erreurs : 404 `"Video not found"` ; 403 `"Vous n'avez pas les permissions nécessaires pour supprimer cette vidéo"` ; 500 `"Failed to delete video: ..."`.
- Effets : si au moins un achat (`LedgerEntry` purchase/debit, reference_type video) -> **soft-delete** : `status="deleted"`, `is_published=false` (la ligne et les fichiers R2 sont conservés). Sinon hard-delete : supprime la source R2 (seulement si `VideoUpload` existe, ce qui n'est plus le cas après succès du transcodage) puis la ligne vidéo (cascade ORM sur files/likes, cascade FK sur jobs/clés/sessions de lecture/favoris/historique/notifications). **Les fichiers HLS (`videos/{id}/*`), la miniature (`thumbnails/{id}.jpg`) et la preview (`previews/{id}.mp4`) ne sont jamais supprimés de R2** (orphelins).

#### GET `/api/v1/videos` — videos.py:535-550 (catalogue public)
- Auth : **aucune**. Query : `limit` (défaut 10, `ge=1, le=100`), `offset` (défaut 0, `ge=0`). Succès 200. Réponse `List[VideoResponse]`.
- Filtre : `status in (published, ready)` ET `is_published == true`. **Aucun `order_by`** -> pagination instable. Pas de filtre par créateur/recherche/total.

#### GET `/api/v1/videos/mine` — videos.py:553-593
- Auth : connecté (pas de contrôle de rôle). Query : `limit` (défaut **20**, 1-100), `offset` (0). Succès 200.
- Réponse : `List[VideoWithStatsResponse]` = VideoResponse + `revenue:int` (somme des `LedgerEntry` earning/credit de la vidéo = part créateur nette de commission). Tri `created_at DESC`. **Tous statuts** (y compris `deleted`, `failed`, `uploading`). Pas de total/`has_next`.
- Seul moyen de lire une vidéo « en détail » côté créateur : **il n'existe pas de `GET /videos/{id}`**.

#### POST `/api/v1/videos/{video_id}/purchase` — videos.py:596-710
- Auth : connecté. Succès **200**. Réponse `{"message":"Purchase successful","video_id":str}`.
- Erreurs (400 sauf indication) : 404 `"Video not found"` ; `"Video is not published"` ; `"Video is not ready"` (statut hors ready/published) ; `"You cannot purchase your own video"` ; `"Video already purchased"` ; `"Insufficient balance"` ; 500 `"Purchase failed: ..."`.
- Effets : voir §4.2 (débit acheteur, crédit créateur net de commission, 2 écritures ledger). Aucune notification au créateur.

#### GET `/api/v1/videos/{video_id}/access` — videos.py:713-770
- Auth : connecté. Accès : propriétaire, acheteur ou ADMIN (le prix 0 n'ouvre PAS l'accès ici, contrairement à playback-session). Succès 200. Réponse `{"url": "<URL présignée du master.m3u8 privé>", "expires_in": 3600}`.
- Erreurs : 404 `"Video not found"` ; 403 `"You do not have access to this video"` ; 404 `"Master HLS manifest not found for this video"` ; 500 `"Failed to generate secure URL: ..."`.
- À vérifier : les variantes (`480p.m3u8`, segments) sont relatives et le manifeste référence la clé AES via `/api/v1/stream/{id}/key` (jeton requis) -> l'URL présignée seule ne suffit probablement pas pour lire la vidéo ; le chemin de lecture réel est `playback-session` + `/stream/...`. En stockage local, l'URL `.../local_storage/private/...` n'est pas montée (main.py:118 ne monte que `public`).

#### POST `/api/v1/videos/{video_id}/like` — videos.py:773-804 ; DELETE même chemin — videos.py:807-835
- Auth : connecté. POST : 200 `{"message":"Video liked successfully"}` (idempotent, `likes_count += 1` si nouveau). DELETE : 204 (idempotent, `max(count-1,0)`). 404 `"Video not found"`, 500 `"Like failed: ..."` / `"Unlike failed: ..."`. Aucun contrôle de statut/publication/accès.

#### PUT `/api/v1/videos/upload/local/{upload_id}/{part_number}` — videos.py:1040-1066
- Auth : **aucune** (stockage local de dev uniquement). Corps binaire brut ; réponse 200 vide avec header `ETag: "local-etag-{upload_id}-{part}"`. 404 `"Upload session not found"` ; 500 `"Failed to upload part: ..."`. Non pertinent en production R2.

#### POST `/api/v1/internal/videos/r2-notification` — videos.py:1072-1113
- Auth : **token R2** (`x-r2-token` ou `Authorization: Bearer <R2_TOKEN_VALUE>`), 401 `"Invalid R2 notification token"`. Succès **202**.
- Body `R2NotificationRequest` : `video_id?`, `key?` (alias `object_key`), `bucket?`, `event_type?`, `Records?` (format S3). Réponse `{"message":"R2 notification accepted","queued":[{"video_id","object_key"}]}`. Erreurs : 400 `"Missing R2 object key or video_id"` ; 404 `"No pending upload found for this R2 object"` / `"Video not found"` ; 503 `"Video processing queue is not available"` ; 500.
- Effets : `upload_status="uploaded"`, vidéo -> `queued` (sauf si déjà `ready/published/processing`), transcodage planifié. **Pas pour l'app mobile.**

#### POST `/api/v1/internal/videos/test-r2-notification` — videos.py:1116-1155
- Même auth R2. Body `R2TestNotificationRequest` : `video_id?`, `key?`, `process_inline:bool=true`. 202 `{"message","video_id","object_key","status":"queued","direct_worker":bool}`. 400 `"Missing object_key or video_id"`. **Pas pour l'app mobile.**

### 1.5 Library (`app/api/v1/routes/library.py`)

#### GET `/api/v1/library` — library.py:192-214
- Auth : connecté. Query : `limit` (défaut 10, 1-100), `offset` (0). Succès 200. Réponse `List[VideoResponse]`.
- Vidéos **achetées** par l'utilisateur (jointure ledger purchase/debit/reference_type "video"), tri par date d'achat décroissante. Inclut les vidéos soft-supprimées (`status:"deleted"`). Ne contient pas les vidéos du créateur ni les vidéos gratuites.

### 1.6 Devices (`app/api/v1/routes/devices.py`)

#### POST `/api/v1/devices/register` — devices.py:16-80
- Auth : connecté. Succès **200**. Body `DeviceRegisterRequest` : `device_id:str` (requis), `platform:str|null`, `device_name:str|null`. Réponse `DeviceResponse` : `{id, user_id, device_id, platform|null, device_name|null, is_active:bool, last_seen_at|null, created_at}`.
- Effets : upsert ; réactive un appareil connu (`is_active=true`, `last_seen_at=now`). Nouveau device : si déjà `MAX_ACTIVE_DEVICES=3` actifs, les **plus anciens (last_seen_at) sont désactivés automatiquement** (pas d'erreur). Évaluation anti-fraude non bloquante (`FraudFlag` si l'appareil est déjà lié à un autre compte). 500 `"Device registration failed: ..."`.
- Un créateur doit enregistrer son appareil pour lire **sa propre** vidéo.

#### GET `/api/v1/devices` — devices.py:83-88
- Auth : connecté. 200 `List[DeviceResponse]` (tous les appareils, actifs ou non, sans pagination).

#### DELETE `/api/v1/devices/{device_id}` — devices.py:91-117
- Auth : connecté. Succès **204**. `{device_id}` accepte **soit l'`id` de la ligne, soit le `device_id`** client. 404 `"Device not found"` ; 500 `"Device revocation failed: ..."`. Suppression physique de la ligne.

### 1.7 Streaming (`app/api/v1/routes/streaming.py`)

#### POST `/api/v1/videos/{video_id}/playback-session` — streaming.py:64-153
- Auth : connecté. Succès **200**. **`device_id` est un paramètre de QUERY obligatoire** (`?device_id=...`), pas dans le body. Pas de body.
- Réponse (dict) : `{"token": str (urlsafe 32 octets), "expires_at": ISO (now + 2 h), "watermark": "<full_name> • •••<4 derniers chiffres du téléphone>"}`.
- Erreurs : 404 `"Video not found"` ; 400 `"Video is not ready for streaming"` (statut hors ready/published, y compris `deleted`) ; 403 `"You must purchase this video before streaming"` ; 403 `"Playback is restricted to registered active devices"` (device inconnu/inactif pour cet user) ; 422 si `device_id` absent.
- Accès accordé si : `price == 0` OU propriétaire OU achat. Aucune vérification de `is_published`.
- Effets : crée `PlaybackSession(token_hash=sha256(token), ip, user_agent, expires_at=+2h)` (le token en clair n'est jamais stocké) ; scoring fraude non bloquant (appareil partagé entre comptes / ≥2 IP en 15 min -> `FraudFlag`).

#### GET `/api/v1/stream/{video_id}/master.m3u8?token=...` — streaming.py:175-196
- Auth : **aucun header Authorization** ; `token` (query, requis) = token de playback. Réponse : manifeste HLS (`application/x-mpegURL`) dont chaque ligne de variante est réécrite en `...?token=<token>`. Erreurs : 403 `"Invalid or expired playback token"` (token inconnu, mauvaise vidéo, expiré, ou `revoked_at` non nul — aucun code ne le renseigne actuellement) ; 404 `"Master manifest not found"`.

#### GET `/api/v1/stream/{video_id}/key?token=...` — streaming.py:199-215
- Auth : token de playback. Réponse : **16 octets bruts** (`application/octet-stream`), clé AES-128. Erreurs : 403 token ; 404 `"Encryption key not found"`.

#### GET `/api/v1/stream/{video_id}/{filename}?token=...` — streaming.py:222-250 (catch-all)
- `.m3u8` : manifeste de qualité réécrit (ajoute `&token=` aux segments et à `URI="..."` de la clé `/api/v1/stream/{id}/key`). Autre : segment `.ts` brut (`video/MP2T`). Erreurs : 403 token ; 404 `"Stream file not found"`. Le token n'est pas lié au `device_id`/IP après création.

### 1.8 Payments / recharge (`app/api/v1/routes/payments.py`, service `app/services/dexpay_service.py`)

#### POST `/api/v1/payments/topup/initiate` — payments.py:19-63
- Auth : connecté (tout rôle). Pas de rate limit. Succès **200**.
- Body `WalletTopUpRequest` (`schemas/wallets.py`) : `amount:int (gt=0)` — **aucun minimum/maximum métier**, devise toujours **XOF** (dexpay_service.py:27).
- Réponse (dict) : `{"payment_url": str, "reference": "topup_<12 hex>"}`.
- Erreurs : 400 `"Montant invalide"` (inatteignable, validé avant par Pydantic -> 422) ; 500 avec `detail=str(e)` si DexPay échoue (ex. `"DexPay checkout creation failed (status 4xx): ..."`, ou `ValueError "DEXPAY_PUBLIC_KEY n'est pas configurée..."`) — dans ce cas la `TopupTransaction` créée est supprimée (:60-61).
- Effets : crée `TopupTransaction(status="pending")`, appelle DexPay `POST /checkout-sessions` avec `success_url`/`failure_url` pointant vers `BACKEND_URL/api/v1/payments/topup/{success|failure}?reference=...` et `webhook_url=DEXPAY_WEBHOOK_URL`. Verrou `with_for_update` sur le wallet.

#### GET `/api/v1/payments/topup/success?reference=` — payments.py:65-69 ; GET `/api/v1/payments/topup/failure?reference=` — payments.py:71-75
- Auth : aucune. Redirection 307 vers `{FRONTEND_URL}/wallet/callback?reference=<ref>` (+ `&failed=true` pour failure). **URL web** : pour une app mobile, il faudra intercepter la redirection (WebView) ou sonder le statut ; `reference` n'est pas échappé dans l'URL.

#### POST `/api/v1/payments/topup/webhook` — payments.py:77-137
- Appelé par DexPay (pas par l'app). Auth : header `x-webhook-signature` = HMAC-SHA256 hex du corps brut avec `DEXPAY_SECRET_KEY` -> sinon 401 `"Signature invalide"`. 400 `"JSON invalide"`. Événement autre que `checkout.completed` -> 200 `{"status":"event <X> ignored"}` (**les échecs/annulations ne sont donc jamais enregistrés** : la transaction reste `pending`). 404 `"Transaction introuvable"`.
- Réponses : `{"status":"processed"}` ou `{"status":"already processed"}`.
- Effets : si `pending` -> `completed`, `gateway_reference = checkout_session_id`, `wallet.balance += amount`, `LedgerEntry(topup, credit, reference_id=<ref>, reference_type="topup", description="Recharge de crédit via DexPay")`, scoring fraude (flag si vélocité/gros montant). Le montant crédité est `tx.amount` (celui de l'initiation), pas celui du webhook.
- À vérifier : `fraud_service.maybe_flag` commite la session (fraud_service.py:118) avant la mutation de la transaction, ce qui libère le verrou `FOR UPDATE` sur la ligne `tx` en cas de flag ; fenêtre de double traitement en cas de webhooks concurrents.

#### GET `/api/v1/payments/topup/status/{reference}` — payments.py:139-149
- Auth : connecté (la transaction doit appartenir à l'user). Succès 200. Réponse `{"status": "pending"|"completed"|"failed"|"cancelled", "amount": int}` (dict ; `failed`/`cancelled` ne sont **jamais écrits** par le code actuel). 404 `"Transaction non trouvée"`.

### 1.9 Payouts / retraits (`app/api/v1/routes/payouts.py`, service `app/services/payout_service.py`)

Tous : `Depends(require_roles(UserRole.CREATOR))` (payouts.py:19) -> **un viewer ou un admin reçoit 403** `"Vous n'avez pas les permissions nécessaires pour accéder à cette ressource"`.

#### GET `/api/v1/payouts/balance` — payouts.py:22-26
- Succès 200. Réponse (dict, payout_service.py:82-88) : `{"withdrawable_balance":int, "wallet_balance":int, "total_earnings":int, "total_withdrawn":int, "total_refunded":int}`. Formules en §4.1.

#### GET `/api/v1/payouts/providers` — payouts.py:29-38
- Succès 200. Réponse : liste brute `data` de DexPay `GET /payouts-providers?filters[provider_country]=<iso2 du pays de l'user>` (champs DexPay : `provider_name, provider_short_name (= valeur d'`operator`, ex. "wave_sn_payout"), provider_logo, provider_country, provider_currency, provider_type, provider_status, provider_fee_type, provider_fee, min_amount, max_amount` — d'après `skills/dexpay/references/api-reference.md`, non garanti). Liste `[]` si DexPay répond 422 (pays non couvert). Une seule page (limite DexPay par défaut, pas de pagination).
- Erreur : 502 `"Impossible de récupérer la liste des opérateurs"` (toute exception, y compris clés DexPay non configurées).

#### POST `/api/v1/payouts/request` — payouts.py:41-73
- Rate limit **5/heure/IP** (`@limiter.limit("5/hour")`). Succès **200** (pas de status_code).
- Body `PayoutRequestCreate` : `amount:int (gt=0)`, `operator:str` (ex. `wave_sn_payout`, non validé côté GNPlay), `destination_phone:str|null` (défaut = `user.phone_number`).
- Réponse : **`PayoutRequest` ORM brut** (colonnes §0.4), statut possible `pending|processing|completed` (le cas `failed` lève 502).
- Erreurs : 400 `"Le montant doit être supérieur à 0"` ; 400 `"Pays de l'utilisateur non renseigné"` ; 400 `"Le montant minimum de retrait est de {min} {devise}"` ; 400 `"Aucun portefeuille associé à cet utilisateur"` ; 400 `"Solde retirable insuffisant (disponible: N)"` ; **502** `"Le retrait a échoué et a été remboursé: <raison>"` (échec DexPay : raison = message d'exception tel que `"DexPay payout creation failed (status 4xx): ..."`, tronqué à 255 car. dans `failure_reason`) ; 403 rôle ; 429 `{"error":...}`.
- Effets : voir §4.4 (débit immédiat du wallet + ledger `withdrawal`, appel DexPay, remboursement automatique si échec).

#### GET `/api/v1/payouts` — payouts.py:76-84
- Succès 200. Historique de l'user, `created_at DESC`, liste de `PayoutRequest` ORM. **Aucune pagination.** Ne rafraîchit pas les statuts.

#### GET `/api/v1/payouts/{payout_id}` — payouts.py:87-117
- Succès 200 : `PayoutRequest` ORM brut. 404 `"Retrait introuvable"`. Si `pending|processing` avec `gateway_payout_id` : interroge DexPay `GET /payouts/{id}` ; `COMPLETED` -> `completed` + `processed_at` ; `FAILED` -> remboursement + `failed`. Les erreurs de rafraîchissement sont avalées (log). Statut DexPay `CANCELLED` non géré (reste `processing`, wallet débité). **Pas de webhook payout** : sans appel à cette route, le statut ne change jamais.
- À vérifier : dans la branche `FAILED`, `payout.wallet` est chargé (:109) -> la réponse JSON sans response_model peut inclure un sous-objet `wallet`.

### 1.10 Favoris & playlists (`app/api/v1/routes/favorites.py`) — spectateur

Toutes : auth connecté, sans rate limit. Schémas : `schemas/playlists.py`.
- POST `/api/v1/videos/{video_id}/favorite` — :22-41 — **201** `{"message":"Video added to favorites"}` (idempotent) ; 404 `"Video not found"` ; 500 `"Failed to add favorite: ..."`.
- DELETE `/api/v1/videos/{video_id}/favorite` — :44-57 — 204 (idempotent).
- GET `/api/v1/favorites` — :60-74 — `limit` 20 (1-100), `offset` ; `List[FavoriteResponse]` = `{id, video: VideoResponse, created_at}` (tri `created_at DESC`).
- POST `/api/v1/playlists` — :90-101 — 201 `PlaylistResponse` `{id, user_id, name, description|null, is_public, created_at, updated_at}` ; body `{name:str(1-255), description:str|null, is_public:bool=false}`.
- GET `/api/v1/playlists` — :104-118 — `limit` 20, `offset` ; `List[PlaylistResponse]`.
- GET `/api/v1/playlists/{playlist_id}` — :121-128 — `PlaylistDetailResponse` = PlaylistResponse + `items:[{id, video: VideoResponse, position:int}]` ; 404 `"Playlist not found"` ; 403 `"Vous n'avez pas accès à cette playlist"` (non propriétaire et non publique).
- PATCH `/api/v1/playlists/{playlist_id}` — :131-144 — body `{name?, description?, is_public?}` ; `PlaylistResponse` ; 404/403 idem.
- DELETE `/api/v1/playlists/{playlist_id}` — :147-151 — 204 ; 404/403 idem.
- POST `/api/v1/playlists/{playlist_id}/videos/{video_id}` — :154-176 — **201** `{"message":"Video added to playlist"}` (idempotent) ; 404 `"Video not found"`/`"Playlist not found"` ; 403 ; 500 `"Failed to add video to playlist: ..."`.
- DELETE `/api/v1/playlists/{playlist_id}/videos/{video_id}` — :179-194 — 204.

### 1.11 Historique de visionnage (`app/api/v1/routes/watch_history.py`)

#### POST `/api/v1/videos/{video_id}/watch-progress` — :33-86
- Auth : connecté. Succès 200. Body `WatchProgressRequest` : `position_seconds:int (ge=0)`, `duration_seconds:int|null (ge=0)`. Réponse `{"message":"Watch progress updated","completed":bool}`.
- Erreurs : 404 `"Video not found"` ; 400 `"Video is not ready for streaming"` ; 403 `"You do not have access to this video"` (ni gratuit, ni propriétaire, ni acheté) ; 500 `"Failed to update watch progress: ..."`.
- Effets : upsert `WatchHistory` ; `completed` = `position >= 90 %` de `duration` (cumulatif, ne repasse jamais à `false`). **Premier appel d'un utilisateur pour une vidéo => `video.view_count += 1`** (une vue par spectateur unique ; c'est la seule source de `view_count`). Le créateur qui regarde sa propre vidéo compte.

#### GET `/api/v1/videos/continue-watching` — :89-107 ; GET `/api/v1/videos/history` — :110-124
- Auth : connecté. `limit` 20 (1-100), `offset`. `List[WatchHistoryResponse]` = `{video: VideoResponse, progress_seconds:int, duration_seconds:int|null, completed:bool, last_watched_at|null}`. continue-watching : `completed=false` et `progress>0`.

### 1.12 Follows & feed (`app/api/v1/routes/follows.py`)

- POST `/api/v1/creators/{creator_id}/follow` — :17-41 — auth connecté ; **201** `{"message":"Creator followed successfully"}` ; 400 `"Vous ne pouvez pas vous suivre vous-même"` ; 404 `"Creator not found"` ; 400 `"Cet utilisateur n'est pas un créateur"` (role ≠ creator). Idempotent.
- DELETE `/api/v1/creators/{creator_id}/follow` — :44-57 — 204.
- GET `/api/v1/creators/me/following` — :60-75 — `limit` 20 (1-100), `offset` ; `List[CreatorPublicResponse]` = `{id, full_name, page_name|null, avatar|null, bio|null}`.
- GET `/api/v1/creators/{creator_id}/followers/count` — :78-85 — **auth : aucune** (pas de `UserDependency`) ; `FollowersCountResponse` `{creator_id, followers_count}` ; 404 `"Creator not found"` (accepte n'importe quel user, pas seulement un créateur). Il n'existe **aucune liste nominative d'abonnés**.
- GET `/api/v1/feed` — :88-106 — connecté ; `limit` 20 (1-100), `offset` ; `List[VideoResponse]` des créateurs suivis (status ready/published ET is_published), `created_at DESC`.

### 1.13 Analytics (`app/api/v1/routes/analytics.py`)

#### GET `/api/v1/videos/{video_id}/analytics` — :18-61
- Auth : propriétaire ou ADMIN (pas de contrôle de rôle creator). Succès 200. `VideoAnalyticsResponse` : `{video_id, views:int (= view_count), unique_viewers:int (= nb de lignes watch_history), completed_views:int, average_completion_rate:float (0.0-1.0, arrondi 4 déc.), likes_count:int, purchases_count:int, revenue:int}`. `revenue` = somme des earning/credit de la vidéo (net de commission).
- Erreurs : 404 `"Video not found"` ; 403 `"Vous n'avez pas accès aux statistiques de cette vidéo"`.
- Pas de série temporelle (aucune ventilation par jour/pays).

#### GET `/api/v1/creators/me/analytics` — :64-106
- Auth : rôle `creator` ou `admin` (contrôle manuel) sinon 403 `"Réservé aux créateurs"`. Succès 200.
- `CreatorAnalyticsResponse` : `{total_videos:int, total_views:int, total_followers:int, revenue_total:int, revenue_this_month:int (depuis le 1er du mois UTC), top_videos:[{video_id, title, view_count, likes_count}] (5 max, tri par view_count)}`. `total_videos` compte **toutes** les vidéos y compris `deleted/failed/uploading`.

### 1.14 Téléchargements offline (`app/api/v1/routes/downloads.py`) — spectateur

- POST `/api/v1/videos/{video_id}/download/authorize` — :60-118 — connecté ; body `{device_id:str (min 1)}` ; **200** `DownloadAuthorizeResponse` `{license_token, device_id, expires_at (= now + OFFLINE_LICENSE_DAYS, 30 j)}` ; 404 `"Video not found"` ; 400 `"Video is not ready for download"` ; 403 `"You must purchase this video before downloading it"` ; 403 `"Offline download is restricted to registered active devices"`. Upsert de la licence (hash stocké).
- GET `/api/v1/videos/{video_id}/download/manifest?device_id=&license_token=` — :121-156 — **sans Authorization** (licence) ; `DownloadManifestResponse` `{video_id, files:[{storage_key, quality|null, file_type|null, url}], expires_in:86400}` ; 403 `"Invalid or expired offline download license"` ; 404 `"No downloadable files found for this video"` ; 500 `"Failed to generate download URL: ..."`.
- GET `/api/v1/videos/{video_id}/download/key?device_id=&license_token=` — :159-173 — 16 octets bruts ; 403 licence ; 404 `"Encryption key not found"`.
- DELETE `/api/v1/videos/{video_id}/download?device_id=` — :176-198 — connecté ; 204 ; révoque les licences (`revoked_at`), `device_id` optionnel.

### 1.15 Notifications (`app/api/v1/routes/notifications.py`)

Seul type existant : `"new_video"` (`enums/notifications.py`), créé pour les **abonnés** quand le créateur publie ; rien de côté créateur.
- GET `/api/v1/notifications` — :13-27 — connecté ; `limit` 20 (1-100), `offset` ; `List[NotificationResponse]` `{id, type:"new_video", title, body|null, video_id|null, read_at|null, created_at}` ; tri `created_at DESC`.
- GET `/api/v1/notifications/unread-count` — :30-36 — `{"unread_count":int}`.
- PATCH `/api/v1/notifications/{notification_id}/read` — :39-53 — `NotificationResponse` ; 404 `"Notification not found"`. Idempotent.
- PATCH `/api/v1/notifications/read-all` — :56-64 — `{"message":"All notifications marked as read"}`.
- Pas de push (aucun FCM/APNs/device token dans l'API) : le mobile doit sonder.

### 1.16 Admin (`app/api/v1/routes/admin.py`) — `require_roles(ADMIN)` (403 sinon)

- GET `/api/v1/admin/fraud-flags` — :18-35 — query `status` (alias, enum `pending|confirmed|dismissed`), `limit` 20 (1-100), `offset` ; `List[FraudFlagResponse]` `{id, user_id, event_type:"topup"|"device_anomaly", risk_score:int, reasons:str|null, status, related_reference_id|null, created_at}`.
- PATCH `/api/v1/admin/fraud-flags/{flag_id}` — :38-52 — body `{status}` ; `FraudFlagResponse` ; 404 `"Fraud flag not found"`.
- PATCH `/api/v1/admin/users/{user_id}/deactivate` — :55-64 — `UserRead` ; 404 `"User not found"` ; `is_active=false` (le user reçoit 403 sur tout appel authentifié jusqu'à réactivation ; les sessions ne sont pas révoquées).
- PATCH `/api/v1/admin/users/{user_id}/reactivate` — :67-76 — idem `is_active=true`.

### 1.17 Santé (hors `/api/v1`, `app/health.py`)
- GET `/health/` -> `{"status":"ok","message":"API is healthy and running"}` ; GET `/health/db` -> `{"status":"ok"|"error","message":...}` (toujours HTTP 200, même en erreur). Pas d'auth.

---

## 2. Pertinence créateur

Légende : **A** indispensable, **B** utile, **C** spectateur/admin/infra uniquement.

| Endpoint | Classe | Justification |
|---|---|---|
| POST /auth/request-otp | A | Premier pas de l'inscription (vérification du téléphone). |
| POST /auth/verify-otp | A | Valide le numéro avant `register`. |
| POST /auth/register | A | Création du compte. |
| POST /auth/login | A | Seul moyen d'obtenir les tokens (form-urlencoded). |
| POST /auth/refresh-token | A | Maintien de session (access token court, rotation). |
| POST /auth/logout | A | Déconnexion ciblée ou globale. |
| POST /auth/request-password-reset | A | Récupération de compte. |
| POST /auth/reset-password | A | Idem (finalise avec le code OTP). |
| GET /users/me | A | Profil, rôle (viewer/creator) et état du compte. |
| PATCH /users/me | A | Édition nom, `page_name` (identité publique) et bio. |
| POST /users/me/become-creator | A | Seule façon de devenir créateur (viewer -> creator, requis par les payouts). |
| POST /users/me/profile-picture | B | Avatar de la page créateur ; pas bloquant. |
| GET /wallets/balance | A | Solde du portefeuille. |
| GET /wallets/transactions | A | Seul historique des gains (`earning`), achats, retraits, remboursements (non paginé). |
| POST /videos/upload/init | A | Démarre un upload (crée la vidéo + URLs multipart). |
| POST /videos/upload/{id}/parts/presign | A | Re-signer des parts expirées / reprise. |
| POST /videos/upload/{id}/parts/confirm | A | Suivi de reprise d'upload (parts confirmées). |
| GET /videos/upload/{id}/parts | B | Reconstruire la liste ETag à la reprise (peut être gardée côté client). |
| GET /videos/upload/{id}/status | A | Parts manquantes pour reprendre un upload interrompu. |
| POST /videos/upload/{id}/complete | A | Finalise et déclenche le transcodage. |
| POST /videos/upload/{id}/abort | A | Annuler un upload en cours. |
| GET /videos/{id}/processing-status | A | Suivi du transcodage (queued/processing/ready/failed). |
| POST /internal/videos/{id}/retry-transcode | B | Relancer une vidéo `failed` (préfixe « internal » mais auth utilisateur). |
| GET /videos/mine | A | Liste des vidéos du créateur avec statut + revenu (seule « vue détail » disponible). |
| PATCH /videos/{id} | A | Titre/description/prix/miniature/publier-dépublier. |
| DELETE /videos/{id} | A | Suppression (soft-delete si déjà achetée). |
| GET /videos (catalogue) | C | Découverte spectateur (non filtrable par créateur). |
| POST /videos/{id}/purchase | C | Achat spectateur (le créateur ne peut pas acheter sa propre vidéo). |
| GET /videos/{id}/access | C | URL de manifeste présignée ; redondant avec playback-session. |
| POST/DELETE /videos/{id}/like | C | Action spectateur (le `likes_count` est lu via /mine, /analytics). |
| PUT /videos/upload/local/{upload_id}/{part} | C | Dev local uniquement (stockage local), sans auth. |
| POST /internal/videos/r2-notification, /test-r2-notification | C | Webhooks serveur-à-serveur (token R2). |
| GET /library | C | Achats du spectateur (un créateur peut aussi acheter). |
| POST /devices/register | B | Requis pour prévisualiser/lire ses propres vidéos (playback-session) ; auto-éviction à 3 appareils. |
| GET /devices | B | Écran « appareils connectés ». |
| DELETE /devices/{id} | B | Révoquer un appareil. |
| POST /videos/{id}/playback-session | B | Lecture de sa propre vidéo dans l'app (aperçu de rendu final). |
| GET /stream/{id}/master.m3u8, /key, /{filename} | B | Chemin de lecture HLS chiffré pour le lecteur (si l'app lit les vidéos). |
| POST /payments/topup/initiate | B | Un créateur peut recharger pour acheter ; pas central. |
| GET /payments/topup/success, /failure | C | Redirections navigateur vers `FRONTEND_URL`. |
| POST /payments/topup/webhook | C | Appelé par DexPay. |
| GET /payments/topup/status/{ref} | B | Sonder le résultat d'une recharge lancée dans l'app. |
| GET /payouts/balance | A | Solde retirable (distinct du solde wallet) + total des gains. |
| GET /payouts/providers | A | Liste des opérateurs (`operator`) pour le pays du créateur. |
| POST /payouts/request | A | Retrait des gains (cœur de la monétisation). |
| GET /payouts | A | Historique des retraits (non paginé). |
| GET /payouts/{id} | A | Détail + rafraîchissement du statut auprès de DexPay (seul mécanisme de mise à jour). |
| GET /videos/{id}/analytics | A | Statistiques par vidéo (vues, complétion, achats, revenu). |
| GET /creators/me/analytics | A | Tableau de bord (vues, abonnés, revenus total/mois, top 5). |
| GET /creators/{id}/followers/count | B | Compteur d'abonnés (déjà présent dans /creators/me/analytics -> `total_followers`). |
| POST/DELETE /creators/{id}/follow, GET /creators/me/following, GET /feed | C | Fonctions spectateur. |
| GET /notifications, /unread-count, PATCH /{id}/read, /read-all | B | Cloche de notifications ; n'a de contenu créateur que `new_video` côté abonnés (rien pour ventes/retraits). |
| POST/DELETE /videos/{id}/favorite, GET /favorites, /playlists* (8) | C | Fonctions spectateur. |
| POST /videos/{id}/watch-progress, GET /videos/continue-watching, /videos/history | C | Fonctions spectateur (alimente `view_count`). |
| POST /videos/{id}/download/authorize, GET /download/manifest, /download/key, DELETE /download | C | Offline spectateur. |
| GET/PATCH /admin/* (4) | C | Back-office. |
| GET /health/, /health/db | C | Infra. |

**Manques côté API pour une app créateur** (vérifiés par `grep` : aucun code correspondant) : pas de `GET /videos/{id}` (détail), pas d'upload de miniature, pas de liste nominative d'abonnés, pas de notifications créateur (vente, retrait, vidéo prête), pas de statut `PUBLISHED` jamais écrit, pas de planification de publication, pas de pagination sur `/wallets/transactions` et `/payouts`, pas de webhook de payout.

---

## 3. Cycle de vie d'une vidéo

### 3.1 Statuts
- **`VideoStatus`** (`app/enums/videos.py`, valeurs minuscules) : `draft`, `uploading`, `uploaded`, `queued`, `processing`, `ready`, `published`, `failed`, `blocked`, `deleted`.
  - **Jamais écrits par le code** : `draft`, `published`, `blocked`. `published` est seulement *accepté* dans les filtres (`ready` suffit). Le statut « en ligne » réel est **`ready`** (+ `is_published=true`).
  - Postgres : les valeurs `UPLOADED, QUEUED, READY, BLOCKED, DELETED` ont été ajoutées par la migration `alembic/versions/c7d2f8a91b34_add_missing_videostatus_values.py`.
- **`VideoUploadStatus`** : `pending`, `uploaded`, `failed` (`failed` jamais écrit).
- **Statut du job de transcodage** (`VideoTranscodeJob.status`, chaîne libre `models/videos.py:117`) : `queued` (défaut), `processing`, `ready`, `failed`. Plus `"not_started"` (valeur synthétique de `/processing-status` quand aucun job n'existe).

### 3.2 Transitions et responsables
| Transition | Qui | Où |
|---|---|---|
| (création) -> `uploading`, `is_published=false`, `duration=0` | `POST /videos/upload/init` | videos.py:214-222 |
| `uploading` -> `queued` (mode local) | `POST /upload/{id}/complete` | videos.py:370-372 |
| `uploading` -> `uploaded` (mode R2) | `complete` | videos.py:374 |
| `uploaded` -> `queued` | `complete` si ARQ dispo (ou `TRANSCODE_WEBHOOK_URL`), sinon notification R2 | videos.py:388-398, 164-171 |
| tout -> `queued` | `retry-transcode` | videos.py:1178 |
| `queued` -> `processing` | worker `process_video` | workers/video_processing.py:78 (ignore silencieusement si statut ∉ {queued, processing}, :56-58) |
| `processing` -> `ready` **+ `is_published=true`** | worker, en fin de pipeline | workers/video_processing.py:318-319 |
| `processing` -> `failed` (`error_message="Video processing failed"`) | worker sur exception | workers/video_processing.py:366-367 |
| `*` -> `deleted` + `is_published=false` | `DELETE /videos/{id}` si achats existants | videos.py:501-502 |
| `is_published` true/false | `PATCH /videos/{id}` (créateur/admin), **sans contrôle de statut** | videos.py:455-456 |

### 3.3 `is_published`
- Faux à la création. **Mis à `true` automatiquement par le worker** quand le transcodage réussit (la vidéo est donc en ligne dès qu'elle est prête, sans action du créateur). Le créateur peut ensuite la dépublier via `PATCH {"is_published": false}`. Le soft-delete la met à `false`.
- Visible dans `GET /videos`, `/feed` : `is_published=true` ET `status ∈ {ready, published}`. L'achat exige aussi les deux (`"Video is not published"`, `"Video is not ready"`). `playback-session`, `watch-progress` et `download/authorize` ne regardent **que le statut**, pas `is_published`.

### 3.4 Remplissage des champs
- Le worker (`workers/video_processing.py`) : `thumbnail_url` = capture JPEG à `min(2 s, 10 % de la durée)` envoyée vers le bucket **public** `thumbnails/{video_id}.jpg` (:111-133) ; `preview_url` = extrait MP4 H.264/AAC des **15 premières secondes**, non chiffré, bucket public `previews/{video_id}.mp4` (:135-161). Échecs ffmpeg pour ces deux artefacts : simple warning, champs laissés `null`. Ils sont écrits sur la vidéo seulement au succès final (:326-329), donc `null` pendant `uploading/queued/processing`.
- `PATCH` peut écraser `thumbnail_url` avec n'importe quelle URL. Le worker, lui, n'écrase jamais une miniature quand il n'en a pas produit.
- Au succès : `duration` (secondes, entier), `width`, `height`, `codec_video`, `codec_audio`, `playback_url="/api/v1/stream/{id}/master.m3u8"` (non exposé dans `VideoResponse`), `VideoFile` rows (master, variantes, segments), `VideoEncryptionKey` (AES-128 hex), suppression de l'enregistrement `VideoUpload` **et** de la source sur R2 (:331-355).
- Ladder HLS : prod = 240p (300 kb/s), 360p (600), 480p (1000), 720p (2200) limité à la hauteur source ; local = 480p seul (:164-178). Segments de 6 s, VOD, AES-128 (IV aléatoire dans le keyinfo). Timeout ARQ : 3600 s (`WorkerSettings.job_timeout`).
- Notification abonnés : après succès, `notify_followers_of_new_video` crée une `Notification(type="new_video", title="Nouvelle vidéo publiée", body="<titre> vient d'être publiée")` par abonné (idempotent) — inline ou via ARQ (:341-349, :391-444).

### 3.5 Erreurs de pipeline
- Échec : vidéo `failed`, job `failed`, `error_message` générique (« Video processing failed ») ; la vraie cause n'est que dans les logs. L'API ne l'expose qu'à travers `/processing-status` (message générique). `VideoResponse` n'expose pas `error_message`. L'exception est re-levée (`raise e`, :381) ; le rejeu ARQ éventuel serait ignoré car le statut `failed` n'est pas `queued/processing`.
- Relance : `retry-transcode` (source conservée jusqu'au succès).

### 3.6 Playback-session, `/stream` et watermark
1. Le client enregistre son appareil : `POST /devices/register {device_id,...}` (max 3 actifs, éviction automatique des plus anciens).
2. `POST /videos/{id}/playback-session?device_id=<id>` -> `{token, expires_at (+2 h), watermark}`. Conditions : statut `ready|published`, accès (prix 0 / propriétaire / achat), appareil enregistré et actif **pour cet utilisateur**.
3. Le lecteur HLS charge `GET /stream/{id}/master.m3u8?token=<token>` ; chaque URI relative (variantes, segments, **`URI="/api/v1/stream/{id}/key"`**) est réécrite avec `?token=` / `&token=`. Aucun header `Authorization` n'est nécessaire sur `/stream/*`. La clé AES (16 octets) se récupère sur `/stream/{id}/key?token=`.
4. Validation du token (`streaming.py:156-172`) : hash SHA-256 en base, même `video_id`, non expiré, `revoked_at IS NULL`. **Le token n'est pas relié au `device_id` ni à l'IP après la création** ; aucun endpoint ne révoque une session de lecture (`revoked_at` n'est jamais écrit).
5. Watermark : texte `"{full_name} • •••{4 derniers chiffres du téléphone}"` renvoyé par l'API ; **l'incrustation est à la charge du client** (le flux HLS n'est pas filigrané côté serveur). La docstring parle de « prénom » mais le code utilise `full_name` (streaming.py:146-147).
6. Il n'existe pas de route de « prévisualisation » authentifiée : `preview_url` est publique (15 s) et la miniature aussi.

### 3.7 Suppression
- Soft-delete si au moins un achat (`status=deleted`, `is_published=false`, fichiers conservés) ; sinon hard-delete (ligne + éventuelle source R2). Dans le soft-delete, la miniature/preview/HLS restent publics/privés sur R2.
- Incohérence : le commentaire du soft-delete dit que les acheteurs « doivent garder l'accès en lecture » (videos.py:497-499), mais `playback-session` refuse `status=deleted` (400 `"Video is not ready for streaming"`, streaming.py:80-84) ; `/library` les liste toujours ; `/access` n'exige pas de statut.
- `POST /upload/{id}/abort` fait un hard-delete sans contrôle d'achats ni de statut (voir §5).

---

## 4. Argent

Unité : entiers, « XOF » par convention (`models/wallets.py:53`, topup envoyé en `"XOF"`). Voir le piège devise GNF au §5.

### 4.1 Soldes
- **`wallet_balance`** (`/payouts/balance`) = `Wallet.balance` (colonne `Integer`, défaut 0) = recharges complétées + gains créateur + remboursements de retraits échoués - achats - retraits. C'est aussi `{"balance"}` de `/wallets/balance`. Un seul wallet par user (`user.wallet[0]`).
- **`total_earnings`** = Σ `LedgerEntry.amount` où `transaction_type=earning`, `direction=credit` (tous les crédits de ventes, nets de commission).
- **`total_withdrawn`** = Σ amount `withdrawal`/`debit`. **`total_refunded`** = Σ amount `refund`/`credit` (uniquement générés par un payout échoué).
- **`withdrawable_balance`** = `max( min( wallet_balance , max(total_earnings - total_withdrawn + total_refunded, 0) ), 0 )` (payout_service.py:56-88). Donc : un topup personnel n'est jamais retirable ; des gains dépensés en achats réduisent le retirable. La docstring dit « wallet.balance - retraits en cours » mais le code n'utilise que `wallet_balance` (les retraits en cours sont déjà débités ; `_sum_reserved_pending_payouts`, payout_service.py:44, n'est pas utilisée).

### 4.2 Achat d'une vidéo (`POST /videos/{id}/purchase`, videos.py:596-710)
- Prix `video.price` (entier). `platform_share = (price * PLATFORM_COMMISSION_PERCENT) // 100` (30 % par défaut, `core/config.py:168`, division entière), `creator_share = price - platform_share`.
- Transaction avec verrous `FOR UPDATE` sur les 2 wallets (ordre trié par id) : `acheteur.balance -= price` ; `créateur.balance += creator_share`.
- Deux écritures ledger : acheteur `purchase`/`debit` `amount=price` ; créateur `earning`/`credit` `amount=creator_share` (`reference_id=video.id`, `reference_type="video"`, descriptions en anglais).
- **La part plateforme n'est écrite nulle part** : aucune écriture `commission` n'existe (enum prévu mais jamais utilisé). Plateforme = différence implicite.
- Vidéo à `price=0` : l'achat est possible (écritures à 0) mais inutile ; la lecture est gratuite de toute façon.
- Pas de remboursement d'achat ni de litige dans l'API.

### 4.3 Recharge (topup DexPay)
1. `POST /payments/topup/initiate {amount}` -> `TopupTransaction(pending, reference="topup_xxxxxxxxxxxx")` + checkout DexPay (`item_name="Recharge portefeuille gnplay"`, devise `XOF`, `is_one_shot_payment=true`) -> `{payment_url, reference}`.
2. L'utilisateur paie sur `payment_url` (sandbox : `sandbox_payment_url`). DexPay redirige le navigateur vers `BACKEND_URL/.../topup/success|failure`, qui redirige vers `FRONTEND_URL/wallet/callback?reference=...[&failed=true]`.
3. Le crédit n'a lieu **que** par le webhook signé `checkout.completed` : `wallet.balance += tx.amount`, ledger `topup`/`credit` (`reference_type="topup"`). Statut `pending -> completed`. Idempotent (`already processed`).
4. Le client sonde `GET /payments/topup/status/{reference}` -> `{"status","amount"}`. Les échecs/annulations ne changent jamais le statut (reste `pending`).
- Aucun minimum/maximum côté GNPlay. Anti-fraude non bloquant : flag si ≥4 recharges en 10 min, montant > 5× la moyenne des recharges complétées, ou 1ʳᵉ recharge ≥ 500 000 (fraud_service.py:24-63) ; flags consultables par les admins seulement.

### 4.4 Retraits (payouts, `POST /payouts/request`)
- Rôle `creator` obligatoire. Rate limit 5/heure/IP.
- Devise = `country.country_code` (enum `CurrencyEnum` : XOF, GNF, EUR, USD) ; hors {XOF, XAF, GNF} -> `XOF`. **Montants minimum** (`MINIMUM_PAYOUT_AMOUNTS`, payout_service.py:16-20) : XOF 100, XAF 100, GNF 10 000 (autres -> XOF 100). Pas de maximum. NB : la doc DexPay fixe XOF/XAF à 250 (`skills/dexpay/references/api-reference.md`, « Montants minimum »), donc un retrait de 100-249 XOF passe la validation locale mais est refusé par DexPay -> remboursé + 502.
- `amount` doit être ≤ `withdrawable_balance`.
- **Frais** : GNPlay ne les prélève pas. `fees` est simplement recopié de la réponse DexPay (`payout.fees = result.get("fees")`, nullable) ; la doc DexPay indique que le solde marchand (la plateforme) est débité de `amount + fees` et que le bénéficiaire reçoit `amount` net. Le wallet du créateur est débité de `amount` uniquement.
- **Providers/operator** : `operator` = `provider_short_name` DexPay (ex. `wave_sn_payout`, `om_sn_payout`, `mtn_ci_payout`, `moov_ci_payout`), liste via `GET /payouts/providers` filtrée sur `user.country.iso2`. Non validé localement. `destination_phone` : défaut = numéro du compte ; DexPay attend un format international (`+221...`) — le numéro du compte n'est pas normalisé (à vérifier).
- Séquence (payout_service.py:91-192) : verrou wallet -> recalcul du retirable -> `wallet.balance -= amount` ; `PayoutRequest(status=pending, reference="payout_xxxxxxxxxxxx")` ; ledger `withdrawal`/`debit` (`reference_type="payout"`, `reference_id=payout.id`) ; **commit** ; puis appel DexPay `POST /payouts` hors transaction.
  - Exception réseau/HTTP != 201 -> remboursement immédiat (voir ci-dessous) ; 502 renvoyé.
  - Statut DexPay `FAILED` -> remboursement ; 502.
  - `COMPLETED` -> `completed` + `processed_at` ; `PROCESSING`/`PENDING` -> `processing`/`pending` ; autre -> `processing`. `gateway_payout_id = result["id"]`.
- **Remboursement** (`_refund_failed_payout`, payout_service.py:195-214) : `wallet.balance += amount`, ledger `refund`/`credit` (`reference_type="payout"`), `payout.status="failed"`, `failure_reason` (≤ 255 car.). Seul cas de `refund` dans le code.
- Suivi : pas de webhook ; `GET /payouts/{id}` sonde DexPay tant que `pending|processing`. `cancelled` n'est jamais écrit.
- Statuts renvoyés : `pending`, `processing`, `completed`, `failed`, `cancelled` (minuscules).

### 4.5 Résumé des écritures ledger
| Événement | transaction_type | direction | reference_type | reference_id | amount |
|---|---|---|---|---|---|
| Webhook topup | topup | credit | topup | référence `topup_...` | montant initié |
| Achat (acheteur) | purchase | debit | video | video.id | prix |
| Achat (créateur) | earning | credit | video | video.id | prix - 30 % (entier) |
| Retrait demandé | withdrawal | debit | payout | payout.id | amount |
| Retrait échoué | refund | credit | payout | payout.id | amount |
| (jamais écrit) | commission | - | - | - | - |

---

## 5. Incohérences / pièges pour un client

### 5.1 Format & contrat
1. **Login en form-urlencoded** avec `username` (=téléphone) : `auth.py:47` (pas de JSON, pas de champ `phone_number`).
2. **429 : clé `error`, pas `detail`** (slowapi). Limites par IP : `request-otp` 5/min, `register` 5/min, `request-password-reset` 5/min, `verify-otp` 10/min, `login` 10/min, `reset-password` 10/min, `refresh-token` 30/min, `payouts/request` 5/h. Partage d'IP possible derrière proxy (à vérifier).
3. **ORM bruts sans `response_model`** : `GET /wallets/transactions` (wallets.py:173), `GET /payouts`, `GET /payouts/{id}`, `POST /payouts/request` (payouts.py:73,79,117). Les colonnes exposées dépendent du modèle (§0.4) ; tout champ ajouté au modèle fuit automatiquement. `POST /payouts/request` renvoie 200 même pour `pending`.
4. **Dicts construits à la main** (aucun schéma) : upload init/complete/status/parts, processing-status, access, playback-session, balance, payouts/balance, topup initiate/status, messages `{"message": ...}`. Pas d'OpenAPI utile pour ces réponses.
5. **Incohérence de clés** dans l'upload : `parts[].url` (init) vs `parts[].upload_url` (`/parts/presign`) ; `chunk_size` vs `part_size` (doublons de compat) ; `PartNumber`/`ETag` (PascalCase) pour `/complete` vs `part_number`/`etag` pour `/parts/confirm`.
6. **Statuts** : `Video.status` en minuscules (`"ready"`) ; statut du *job* (`/processing-status`) = autre vocabulaire (`queued|processing|ready|failed|not_started`) ; DexPay renvoie `COMPLETED/FAILED` en majuscules mais l'API GNPlay renvoie `completed/failed`. Les noms d'enum en base sont en MAJUSCULES (invisible côté API).
7. **`complete` : `status` trompeur** (`"uploaded_waiting_r2_notification"` même si déjà `queued`, videos.py:405) ; `complete` répond 202 même si l'enfilage échoue (exception avalée :399-400) -> la vidéo peut rester `uploaded` indéfiniment.
8. **Codes de succès non standard** : `upload/init` 200 (pas 201), `payouts/request` 200, `abort` 200 avec corps, `purchase` 200, `devices/register` 200, `request-otp` 201, `request-password-reset` 202.
9. **Pagination** : absente sur `/wallets/transactions`, `/payouts`, `/devices`, `/payouts/providers` ; présente (`limit`/`offset`, sans total ni `has_next`) ailleurs, avec des défauts différents : `/videos` 10, `/library` 10, `/videos/mine` 20, notifications/favorites/playlists/feed/history 20 ; `limit` ≤ 100 partout. `/videos` n'a pas d'`order_by` (ordre non déterministe) ; `/library` et le reste ont un tri.
10. **`response_model=UserRead` valide l'*entrée en base*** : `full_name` doit faire ≥ 6 caractères et `phone_number` ≥ 9, sinon 500. Or `PATCH /users/me` n'a aucune contrainte -> un client peut « casser » son propre `GET /users/me` en saisissant un nom court (schemas/auth.py:12-13 vs schemas/users.py). Côté client : imposer min 6 sur le nom.
11. **`PATCH` ne peut pas vider un champ** (`null` = non modifié) : `/users/me` et `/videos/{id}`.
12. `bio` et `avatar` valent `null` (pas `""`) quand non renseignés.
13. **Aucun `GET /videos/{id}`** ; `VideoResponse` omet `error_message`, `playback_url`, dimensions/codecs ; `GET /videos/mine` inclut les vidéos `deleted` (à filtrer côté client) et ne donne ni total ni filtre par statut.
14. `GET /creators/{id}/followers/count` est publique et accepte tout `id` utilisateur.
15. `docs/creator-app-design.md` (untracked) contient des écarts avec le code : `/auth/refresh` (réel : `/auth/refresh-token`), « 3 appareils, au-delà il faut en révoquer un » (réel : éviction automatique silencieuse, devices.py:36-49), payouts mini « 100 » (cohérent avec le code, mais DexPay demande 250).

### 5.2 Risques de 500 / comportements dangereux
16. `PATCH /users/me` avec un `page_name` déjà pris -> `IntegrityError` non gérée -> 500 (user_service.py:29-36, unique en base).
17. `PATCH /users/me` avec un nom < 6 car. -> la réponse elle-même échoue (500) et `GET /users/me` ensuite (validation UserRead) ; idem endpoints admin.
18. `POST /videos/upload/init` : `file_size` > 2 147 483 647 (colonne `Integer`, models/videos.py:53) -> 500 `"Upload init failed: ..."` ; `file_size` énorme -> milliers d'URLs présignées générées dans la même réponse ; > 10 000 parts (≈ 98 Go) dépasse la limite S3 multipart.
19. `parts/presign` : `Invalid part number` (400) est avalé par le `except Exception` et devient un 500 (videos.py:884-903).
20. `PATCH /videos/{id}` : validation `price < 0` en 400 inatteignable (422 avant). Aucune validation de `thumbnail_url` (n'importe quelle chaîne).
21. `retry-transcode` sans ARQ/webhook (mode R2) : 503 mais statut déjà `queued` commité -> vidéo bloquée (videos.py:1178-1183).
22. `abort` (videos.py:981-1013) hard-delete la vidéo sans contrôle de statut ni d'achats ; en pratique il ne fonctionne que tant que l'enregistrement `VideoUpload` existe (donc avant le succès du transcodage : `uploading/uploaded/queued/processing/failed`), après quoi il répond 404 `"Video upload session not found"`. Les achats (`LedgerEntry.reference_id`) n'ont aucune FK vers `videos`, donc aucune intégrité référentielle ne s'oppose à un hard-delete.
23. Hard-delete d'une vidéo traitée : **aucune suppression R2** des HLS/miniature/preview (upload supprimé par le worker, `delete_video` ne purge que `upload.file_key`).
24. Soft-delete : les acheteurs ne peuvent plus lire (playback 400) alors que le commentaire promet le contraire (§3.7).
25. `playback-session` : `device_id` en **query** (pas body) et le propriétaire doit aussi avoir un appareil enregistré ; token non lié à l'appareil ni à l'IP ; watermark non incrusté côté serveur.
26. `GET /videos/{id}/access` : prix 0 n'ouvre pas l'accès (≠ playback-session) ; URL présignée du master seul probablement inutilisable pour lire (clé AES derrière un token) -> ne pas l'utiliser pour la lecture (à vérifier).
27. `payments/topup/webhook` : `maybe_flag` commite avant la mutation de `tx` (fenêtre de course sur webhooks concurrents) ; événements `checkout.failed/cancelled` ignorés -> `TopupTransaction` `pending` à vie ; `failed`/`cancelled` n'existent que dans l'enum.
28. `payments/topup/success|failure` redirigent vers une URL **web** (`FRONTEND_URL`) -> pas de deep link pour mobile ; le client doit détecter la fin de paiement autrement (WebView + polling `topup/status`).
29. **Devise** : le wallet et les topups sont en XOF (`models/wallets.py:53`, `dexpay_service.py:27`) alors que le minimum de retrait et la devise du payout dépendent du pays (GNF min 10 000). Un créateur guinéen (GNF) retire un montant XOF interprété en GNF par DexPay (`create_payout(currency=...)`, payout_service.py:159-167) -> cohérence monétaire à vérifier côté métier avant d'afficher des devises.
30. `payouts/request` : pas de validation d'`operator`/téléphone ; une erreur DexPay = débit puis remboursement, avec 502 et message brut `"DexPay payout creation failed (status N): ..."`. `payouts` est réservé au rôle **CREATOR** strict (admin refusé). Pas de webhook payout ; un statut DexPay `CANCELLED` laisse le retrait en `processing` et le wallet débité.
31. `GET /payouts/balance` et `/wallets/balance` ont des noms de fonction identiques (`get_balance`) mais des contenus différents ; ne pas les confondre (`balance` vs `withdrawable_balance`/`wallet_balance`).
32. `Wallet.balance`, `LedgerEntry.amount`, `TopupTransaction.amount` sont `Integer` 32 bits (migrations `98584cf9bb65`, `3e68abfbe2c4`, `7a1c9e2f4b6d`) : plafond ≈ 2,1 milliards.
33. `view_count` = nombre de spectateurs uniques ayant envoyé au moins un `watch-progress` (le créateur compte lui-même) ; `unique_viewers` = nb de lignes `watch_history` -> les deux sont presque toujours égaux ; `views` n'est donc pas un nombre de lectures.
34. `analytics` : `revenue_this_month` calculé sur le mois **UTC** ; `total_videos` inclut les vidéos supprimées/échouées.
35. Logout : l'access token reste utilisable jusqu'à expiration (150 min dans `.env.example`) ; `reset-password` ne révoque pas les sessions ; pas de blocage local des essais d'OTP (le champ `attempts_count` n'est jamais incrémenté).
36. `register` n'exige que **l'existence** d'un OTP register `is_used=True` pour le numéro, sans notion de fraîcheur/lien : une fois le numéro vérifié une fois, l'inscription reste possible indéfiniment (auth_service.py:148-157). Le numéro de téléphone n'est jamais normalisé : `+224...` et `224...` sont deux comptes distincts et le même texte exact doit être utilisé à l'OTP, au register et au login.
37. Stockage local : URLs codées en `http://localhost:8000` (r2_service.py:53, :189, :391) ; `/local_storage/private` non monté -> inutilisable hors dev. Production = `USE_LOCAL_STORAGE=False`.
38. `watermark`/messages mixtes anglais/français (erreurs métier en français sur auth/payouts/analytics, en anglais sur videos/streaming/downloads) : ne pas dépendre des textes `detail` pour la logique client (sauf si figés).
39. `GET /health/db` répond toujours 200, même en erreur (corps `status:"error"`).
40. Les routes `internal/*` sont exposées publiquement sous `/api/v1/internal/videos/...` ; `retry-transcode` y est accessible avec un JWT utilisateur (pas le token R2), les deux autres exigent `R2_TOKEN_VALUE`.

### 5.3 Routes dupliquées / ordre
- Aucune route dupliquée (même méthode + même chemin) : vérifié sur la liste complète des routes montées.
- Chevauchements bénins vérifiés : `GET /videos/mine`, `/videos/continue-watching`, `/videos/history` n'entrent pas en collision avec `/videos/{video_id}/...` (aucun `GET /videos/{video_id}` n'existe) ; `/creators/me/following` et `/creators/me/analytics` ne sont pas capturés par `/creators/{creator_id}/...` (segments différents) ; `PATCH /notifications/read-all` vs `/{id}/read` : segments différents ; `/stream/{id}/master.m3u8` et `/key` sont déclarés avant le catch-all `/stream/{id}/{filename}`.
- Pas de code mort au niveau des routes, mais : le router `internal_router` est dans `videos.py` (`/internal/...` sous `/api/v1`), `health` hors préfixe.

---

## 6. Récapitulatif des 84 routes (compte vérifié)

auth 8 · users 4 · wallets 2 · videos 20 (dont 3 internes `/internal/videos/...` et 1 PUT local) · library 1 · devices 3 · streaming 4 · payments 5 · payouts 5 · favorites/playlists 10 · watch_history 3 · follows 5 · analytics 2 · downloads 4 · admin 4 · notifications 4 ; total vérifié par introspection : 84 routes `/api/v1/*` (+ `/health/`, `/health/db`, `/docs`, `/redoc`, `/openapi.json`, `/docs/oauth2-redirect`).
