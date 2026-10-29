import '../../creator/domain/video_with_stats.dart';
import 'video_formatters.dart';

/// Filtres de « Mes vidéos », dans l'ordre d'affichage. Seuls ceux qui
/// contiennent des vidéos sont proposés (voir [VideoFilterCounts]).
enum VideoFilter {
  all('Toutes'),
  online('En ligne'),
  hidden('Masquées'),
  processing('En traitement'),
  incomplete('Envoi incomplet'),
  failed('Échecs'),
  blocked('Bloquées');

  const VideoFilter(this.label);

  final String label;

  bool matches(VideoWithStats video) {
    return switch (this) {
      VideoFilter.all => true,
      VideoFilter.online => video.lifecycle == VideoLifecycle.online,
      VideoFilter.hidden => video.lifecycle == VideoLifecycle.hidden,
      VideoFilter.processing => video.lifecycle == VideoLifecycle.processing,
      VideoFilter.incomplete => video.lifecycle == VideoLifecycle.uploading,
      VideoFilter.failed => video.lifecycle == VideoLifecycle.failed,
      VideoFilter.blocked => video.lifecycle == VideoLifecycle.blocked,
    };
  }
}

/// Nombre de vidéos par filtre, sur la liste complète (sans recherche).
class VideoFilterCounts {
  VideoFilterCounts(List<VideoWithStats> videos)
    : _counts = {
        for (final filter in VideoFilter.values)
          filter: videos.where(filter.matches).length,
      };

  final Map<VideoFilter, int> _counts;

  int of(VideoFilter filter) => _counts[filter] ?? 0;

  /// Filtres à proposer : « Toutes » plus les catégories qui ont au moins une
  /// vidéo, et le filtre [selected] même vide (pour ne pas faire disparaître
  /// la puce qu'on vient de toucher). Vide quand filtrer n'apporterait rien :
  /// une seule catégorie présente, donc identique à « Toutes ».
  List<VideoFilter> visible(VideoFilter selected) {
    final categories = [
      for (final filter in VideoFilter.values)
        if (filter != VideoFilter.all && of(filter) > 0) filter,
    ];
    if (categories.length < 2 && selected == VideoFilter.all) return const [];
    return [
      for (final filter in VideoFilter.values)
        if (filter == VideoFilter.all ||
            filter == selected ||
            categories.contains(filter))
          filter,
    ];
  }
}

/// Vidéos correspondant au filtre et à la recherche (titre ou description,
/// sans tenir compte de la casse ni des accents).
List<VideoWithStats> filterVideos(
  List<VideoWithStats> videos, {
  required VideoFilter filter,
  required String query,
}) {
  final needle = foldForSearch(query);
  return [
    for (final video in videos)
      if (filter.matches(video) &&
          (needle.isEmpty ||
              foldForSearch(video.title).contains(needle) ||
              foldForSearch(video.description ?? '').contains(needle)))
        video,
  ];
}
