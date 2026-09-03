/// Résultat prêt à l'emploi d'une session de lecture
/// (`POST /videos/{id}/playback-session`) : l'URL du manifeste HLS proxié
/// et réécrit par le backend (`/stream/{id}/master.m3u8?token=...`), déjà
/// authentifiée via son paramètre `token` — aucun en-tête HTTP requis.
class VideoPlaybackAccess {
  const VideoPlaybackAccess({
    required this.url,
    this.expiresAt,
    this.watermark,
  });

  final String url;
  final DateTime? expiresAt;
  final String? watermark;
}
