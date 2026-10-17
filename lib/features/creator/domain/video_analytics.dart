import '../../../shared/utils/json_helpers.dart';

class VideoAnalytics {
  const VideoAnalytics({
    required this.videoId,
    required this.views,
    required this.uniqueViewers,
    required this.completedViews,
    required this.averageCompletionRate,
    required this.likesCount,
    required this.purchasesCount,
    required this.revenue,
  });

  final String videoId;
  final int views;
  final int uniqueViewers;
  final int completedViews;
  final double averageCompletionRate;
  final int likesCount;
  final int purchasesCount;
  final int revenue;

  double get completionPercent {
    final rate = averageCompletionRate <= 1
        ? averageCompletionRate * 100
        : averageCompletionRate;
    return rate.clamp(0, 100);
  }

  factory VideoAnalytics.fromJson(Map<String, dynamic> json) {
    return VideoAnalytics(
      videoId: jsonString(json['video_id'], fallback: ''),
      views: jsonInt(json['views']),
      uniqueViewers: jsonInt(json['unique_viewers']),
      completedViews: jsonInt(json['completed_views']),
      averageCompletionRate: jsonDouble(json['average_completion_rate']),
      likesCount: jsonInt(json['likes_count']),
      purchasesCount: jsonInt(json['purchases_count']),
      revenue: jsonInt(json['revenue']),
    );
  }
}
