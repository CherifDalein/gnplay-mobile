# Intégration API - Gestion des Vidéos (Application Créateur Flutter)

Ce document décrit en détail les endpoints, les modèles de données et les flux de travail nécessaires pour permettre aux créateurs de lire, uploader et gérer leurs vidéos depuis l'application Flutter.

## 1. Modèles de Données

### 1.1 VideoResponse
Représente une vidéo standard dans le système.
```dart
class Video {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final String? previewUrl;
  final int price;
  final int duration;
  final String status; // 'uploading', 'uploaded', 'queued', 'processing', 'ready', 'failed', 'deleted'
  final bool isPublished;
  final int viewCount;
  final int likesCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Utilisé par le endpoint /videos/mine
  final int? revenue; 
}
```

---

## 2. Endpoints de Gestion des Vidéos

Tous les appels nécessitent le token d'authentification du créateur (`Authorization: Bearer <token>`).

### 2.1 Lister les vidéos du créateur
Permet de récupérer toutes les vidéos du créateur, incluant les statistiques de revenus.

- **Méthode** : `GET`
- **URL** : `/api/v1/videos/mine`
- **Query Params** : `limit` (défaut: 20), `offset` (défaut: 0)
- **Réponse** : Liste d'objets `VideoResponse` avec le champ `revenue`.

### 2.2 Obtenir le lien de lecture (Visionner sa vidéo)
Le créateur (comme tout acheteur) a besoin d'une URL sécurisée pour lire la vidéo. Cet endpoint génère une URL pré-signée pointant vers le manifeste HLS (`.m3u8`) de la vidéo.

- **Méthode** : `GET`
- **URL** : `/api/v1/videos/{video_id}/access`
- **Réponse** :
```json
{
  "url": "https://url-presignee-securisee-vers-manifest.m3u8",
  "expires_in": 3600
}
```
*Note Flutter : Vous passez cette URL récupérée au lecteur vidéo (ex: `video_player` ou `chewie`). Le format étant du HLS, la vidéo s'adaptera à la connexion de l'utilisateur.*

### 2.3 Modifier une vidéo (Métadonnées)
Permet de mettre à jour le titre, la description, le prix, la miniature, ou de publier/dépublier la vidéo.

- **Méthode** : `PATCH`
- **URL** : `/api/v1/videos/{video_id}`
- **Body** :
```json
{
  "title": "Nouveau Titre",
  "description": "Nouvelle Description",
  "price": 100, // En devise de l'app (ex: tokens ou francs)
  "thumbnail_url": "https://url-vers-image.jpg",
  "is_published": true
}
```
- **Réponse** : L'objet `VideoResponse` mis à jour.

### 2.3 Supprimer une vidéo
Supprime la vidéo ou la marque comme supprimée si elle a déjà été achetée par des utilisateurs.

- **Méthode** : `DELETE`
- **URL** : `/api/v1/videos/{video_id}`
- **Réponse** : `204 No Content` (Succès).

---

## 3. Le Flux d'Upload de Vidéos (Multipart)

L'upload de vidéo s'effectue en morceaux (chunks) directement vers le stockage (R2 Cloudflare / S3) ou vers le serveur local.

### Étape 1 : Initialiser l'upload
- **Méthode** : `POST`
- **URL** : `/api/v1/videos/upload/init`
- **Body** :
```json
{
  "filename": "ma_video.mp4",
  "file_size": 150000000,
  "mime_type": "video/mp4",
  "title": "Ma Vidéo",
  "description": "Description optionnelle",
  "price": 500
}
```
- **Réponse** :
Vous recevrez un `video_id`, un `upload_id`, et une liste de `parts` (avec des URLs pré-signées pour l'upload).
```json
{
  "video_id": "uuid-video",
  "upload_id": "id-upload-multipart",
  "chunk_size": 10485760, // 10 Mo
  "total_parts": 15,
  "parts": ["https://url-presignee-part-1", "https://url-presignee-part-2", "..."]
}
```

### Étape 2 : Uploader les morceaux (Chunks)
Pour chaque URL dans le tableau `parts`, lisez la portion correspondante du fichier vidéo local (de la taille de `chunk_size`) et envoyez-la via une requête `PUT`.

- **Méthode** : `PUT`
- **URL** : *L'URL pré-signée reçue à l'étape 1*
- **Headers** : `Content-Type` correspondant à la vidéo.
- **Réponse** : Vous devez récupérer le header `ETag` renvoyé par le serveur après chaque succès (ex: `"1b2cf535f27731c974343645a3985328"`).

*Note Flutter : Utilisez un package comme `dio` ou `http` pour gérer ces envois de binaires en parallèle (limitez à 3 requêtes simultanées comme conseillé).*

### Étape 3 : Compléter l'upload
Une fois toutes les parties envoyées, notifiez le backend pour qu'il assemble la vidéo et lance le transcodage.

- **Méthode** : `POST`
- **URL** : `/api/v1/videos/upload/{video_id}/complete`
- **Body** :
```json
{
  "upload_id": "id-upload-multipart",
  "parts": [
    { "PartNumber": 1, "ETag": "etag_1" },
    { "PartNumber": 2, "ETag": "etag_2" }
  ]
}
```
- **Réponse** : `202 Accepted`

### Étape 4 : Suivre l'état du transcodage
La vidéo passera à l'état `queued`, puis `processing`, puis `ready`. Vous pouvez vérifier son état pour informer l'utilisateur.

- **Méthode** : `GET`
- **URL** : `/api/v1/videos/{video_id}/processing-status`
- **Réponse** : Retourne l'état actuel (`status`) et éventuellement un pourcentage de progression.

---

## 4. Recommandations Flutter

1. **Upload en arrière-plan** : L'upload d'une vidéo peut être long. Il est fortement recommandé d'utiliser un package comme [flutter_uploader](https://pub.dev/packages/flutter_uploader) ou de gérer l'upload dans un `Isolate` pour ne pas bloquer l'UI de l'application.
2. **Lecture des vidéos** : Utilisez le package [video_player](https://pub.dev/packages/video_player) pour lire les vidéos, avec le format HLS (`m3u8`) qui sera généré par le backend une fois la vidéo à l'état `ready`.
3. **Optimisation des chunks** : Divisez le fichier vidéo (`File.openRead()`) en morceaux exacts de `chunk_size` pour les requêtes `PUT` de l'Étape 2.
