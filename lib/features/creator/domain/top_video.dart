class TopVideo {
  const TopVideo({
    required this.videoId,
    required this.title,
    required this.viewCount,
    required this.likesCount,
    this.revenue = 0,
    this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final int viewCount;
  final int likesCount;
  final int revenue;
  final String? thumbnailUrl;

  factory TopVideo.fromJson(Map<String, dynamic> json) {
    return TopVideo(
      videoId: json['video_id'] as String,
      title: json['title'] as String,
      viewCount: json['view_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      revenue: json['revenue'] as int? ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }

  TopVideo copyWith({int? revenue, String? thumbnailUrl}) {
    return TopVideo(
      videoId: videoId,
      title: title,
      viewCount: viewCount,
      likesCount: likesCount,
      revenue: revenue ?? this.revenue,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
