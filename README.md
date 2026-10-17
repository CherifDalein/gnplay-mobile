# GNPlay Créateur (mobile)

Application Flutter destinée aux créateurs de GNPlay : publication et suivi de
vidéos, portefeuille, retraits mobile money, notifications et appareils.
Elle consomme l'API FastAPI du dépôt parent (`../app`), sans la modifier.

## Lancer

```bash
flutter pub get
flutter run                                   # API de production
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # API locale (émulateur Android)
```

Tests et analyse :

```bash
flutter analyze
flutter test
```

## Architecture

`lib/features/<domaine>/{data,domain,presentation}` — dépôts HTTP, modèles, puis
providers Riverpod et écrans. Routage : `go_router` (`lib/core/router`).

- **Réseau** (`lib/core/network`) : `AuthenticatedClient` ajoute le jeton le plus
  récent, renouvelle la session sur 401 (refresh token rotatif, une seule
  requête de renouvellement à la fois) et rejoue la requête. Si le refresh est
  refusé, la session est vidée et l'utilisateur revient sur `/login`.
- **Lecture vidéo** : `POST /videos/{id}/playback-session` (appareil enregistré
  requis, 3 max) puis flux HLS chiffré `/stream/{id}/master.m3u8?token=`.
  L'aperçu de 15 s utilise `preview_url`, public.
- **Envoi vidéo** : upload multipart par morceaux de 10 Mo vers R2 (URL
  pré-signées, 3 envois parallèles, 3 tentatives par morceau), puis suivi du
  traitement ; « Relancer le traitement » appelle `retry-transcode`.
- **Portefeuille** : solde et retirable (`/payouts/balance`), historique
  (`/wallets/transactions`), recharge DexPay (`/payments/topup/*`), retraits
  (`/payouts/*`).

Aucune donnée d'exemple n'est affichée en cas d'erreur : les écrans montrent un
état de chargement ou d'erreur avec relance.

`CreatorRepository` regroupe encore tous les appels créateur (dashboard,
vidéos, upload, portefeuille, retraits) ; à découper par domaine si elle grossit.
