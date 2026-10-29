import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/features/creator/domain/video_with_stats.dart';
import 'package:gnplay/features/videos/presentation/video_filter.dart';
import 'package:gnplay/features/videos/presentation/video_formatters.dart';

VideoWithStats _video(
  String title,
  String status, {
  bool published = false,
  String? description,
  int duration = 60,
}) => VideoWithStats.fromJson({
  'id': title,
  'title': title,
  'description': description,
  'status': status,
  'is_published': published,
  'duration': duration,
  'created_at': '2026-06-12T09:41:00Z',
  'updated_at': '2026-06-12T09:41:00Z',
});

void main() {
  final videos = [
    _video('Marché', 'ready', published: true),
    _video('Éclat', 'ready', description: 'Soirée à Kaloum'),
    _video('Mix', 'processing'),
    _video('Mix 2', 'queued'),
    _video('Raté', 'failed'),
    _video('Brouillon', 'draft'),
    _video('Interdite', 'blocked'),
  ];

  test('chaque statut tombe dans son filtre', () {
    List<String> titles(VideoFilter filter) => [
      for (final video in videos)
        if (filter.matches(video)) video.title,
    ];

    expect(titles(VideoFilter.online), ['Marché']);
    expect(titles(VideoFilter.hidden), ['Éclat']);
    expect(titles(VideoFilter.processing), ['Mix', 'Mix 2']);
    expect(titles(VideoFilter.failed), ['Raté']);
    expect(titles(VideoFilter.incomplete), ['Brouillon']);
    expect(titles(VideoFilter.blocked), ['Interdite']);
    expect(titles(VideoFilter.all), hasLength(7));
  });

  test('compteurs et puces utiles', () {
    final counts = VideoFilterCounts(videos);
    expect(counts.of(VideoFilter.all), 7);
    expect(counts.of(VideoFilter.processing), 2);
    expect(counts.visible(VideoFilter.all), VideoFilter.values);

    final simple = VideoFilterCounts([
      _video('A', 'ready', published: true),
      _video('B', 'ready', published: true),
    ]);
    expect(simple.visible(VideoFilter.all), isEmpty);
    // Le filtre actif reste proposé même vide, pour ne pas disparaître.
    expect(
      simple.visible(VideoFilter.failed),
      containsAll([VideoFilter.all, VideoFilter.failed]),
    );
  });

  test('recherche : casse, accents, titre et description', () {
    List<String> search(String query) => [
      for (final video in filterVideos(
        videos,
        filter: VideoFilter.all,
        query: query,
      ))
        video.title,
    ];

    expect(search('MARCHE'), ['Marché']);
    expect(search('eclat'), ['Éclat']);
    expect(search('soiree a kaloum'), ['Éclat']);
    expect(search('  '), hasLength(7));
    expect(search('zzz'), isEmpty);
  });

  test('durée lisible, jamais « 0 min »', () {
    expect(formatVideoDuration(0), isNull);
    expect(formatVideoDuration(45), '45 s');
    expect(formatVideoDuration(1448), '24 min 08 s');
    expect(formatVideoDuration(3720), '1 h 02 min');
    expect(formatPlayerTime(const Duration(seconds: 187)), '3:07');
    expect(formatPlayerTime(const Duration(seconds: 3723)), '1:02:03');
    expect(formatPlayerTime(const Duration(seconds: -4)), '0:00');
  });

  test('date en français avec l\'année, en heure locale', () {
    final date = DateTime.utc(2026, 3, 1, 12);
    final local = date.toLocal();
    expect(
      formatVideoDate(date),
      '${local.day == 1 ? '1er' : local.day} mars 2026',
    );
    expect(formatVideoDate(DateTime(2026, 12, 25, 12)), '25 décembre 2026');
  });
}
