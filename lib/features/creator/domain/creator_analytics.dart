import 'top_video.dart';

class CreatorAnalytics {
  const CreatorAnalytics({
    required this.totalVideos,
    required this.totalViews,
    required this.totalFollowers,
    required this.revenueTotal,
    required this.revenueThisMonth,
    required this.topVideos,
  });

  final int totalVideos;
  final int totalViews;
  final int totalFollowers;
  final int revenueTotal;
  final int revenueThisMonth;
  final List<TopVideo> topVideos;

  factory CreatorAnalytics.fromJson(Map<String, dynamic> json) {
    final videos = json['top_videos'];

    return CreatorAnalytics(
      totalVideos: json['total_videos'] as int? ?? 0,
      totalViews: json['total_views'] as int? ?? 0,
      totalFollowers: json['total_followers'] as int? ?? 0,
      revenueTotal: json['revenue_total'] as int? ?? 0,
      revenueThisMonth: json['revenue_this_month'] as int? ?? 0,
      topVideos: videos is List
          ? videos
                .whereType<Map<String, dynamic>>()
                .map(TopVideo.fromJson)
                .toList()
          : const [],
    );
  }
}
