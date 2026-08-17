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
      videoId: _string(json['video_id'], fallback: ''),
      views: _int(json['views']),
      uniqueViewers: _int(json['unique_viewers']),
      completedViews: _int(json['completed_views']),
      averageCompletionRate: _double(json['average_completion_rate']),
      likesCount: _int(json['likes_count']),
      purchasesCount: _int(json['purchases_count']),
      revenue: _int(json['revenue']),
    );
  }

  factory VideoAnalytics.sample({String videoId = 'sample-1'}) {
    return VideoAnalytics(
      videoId: videoId,
      views: 14208,
      uniqueViewers: 11840,
      completedViews: 10230,
      averageCompletionRate: 72,
      likesCount: 842,
      purchasesCount: 123,
      revenue: 1842000,
    );
  }
}

String _string(Object? value, {required String fallback}) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return fallback;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

double _double(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }
  return 0;
}
