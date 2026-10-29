import '../../../shared/utils/json_helpers.dart';

/// Réponse de `POST /videos/{id}/preview`.
///
/// - 200 `ready` : l'aperçu existe, [previewUrl] est renseigné ;
/// - 202 `generating` : génération lancée (ou déjà en cours) en tâche de
///   fond, [previewUrl] est vide : il faut relire la vidéo jusqu'à le voir.
class PreviewGeneration {
  const PreviewGeneration({required this.status, this.previewUrl});

  final String status;
  final String? previewUrl;

  bool get isReady => previewUrl != null && previewUrl!.isNotEmpty;

  factory PreviewGeneration.fromJson(Map<String, dynamic> json) {
    return PreviewGeneration(
      status: jsonString(json['status'], fallback: 'generating').toLowerCase(),
      previewUrl: jsonNullableString(json['preview_url']),
    );
  }
}
