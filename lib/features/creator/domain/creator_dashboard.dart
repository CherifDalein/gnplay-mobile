import '../../auth/domain/user_read.dart';
import 'creator_analytics.dart';
import 'top_video.dart';

class CreatorDashboard {
  const CreatorDashboard({
    required this.user,
    required this.withdrawableBalance,
    required this.walletBalance,
    required this.analytics,
    required this.topVideos,
  });

  final UserRead user;
  final int withdrawableBalance;
  final int walletBalance;
  final CreatorAnalytics analytics;
  final List<TopVideo> topVideos;
}
