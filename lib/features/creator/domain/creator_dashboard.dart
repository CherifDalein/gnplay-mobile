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

  factory CreatorDashboard.sample() {
    final now = DateTime.now();
    final user = UserRead(
      id: 'sample-user',
      fullName: 'Mariama Diallo',
      phoneNumber: '+224 621 45 88 07',
      role: 'creator',
      isActive: true,
      isSuperuser: false,
      isVerified: true,
      createdAt: now,
      updatedAt: now,
    );
    const topVideos = [
      TopVideo(
        videoId: 'sample-1',
        title: 'Nuits de Conakry — épisode 3',
        viewCount: 14208,
        likesCount: 0,
        revenue: 1842000,
      ),
      TopVideo(
        videoId: 'sample-2',
        title: 'Marché Madina, 5h du matin',
        viewCount: 9461,
        likesCount: 0,
        revenue: 946000,
      ),
    ];

    return CreatorDashboard(
      user: user,
      withdrawableBalance: 4820000,
      walletBalance: 5310000,
      analytics: const CreatorAnalytics(
        totalVideos: 12,
        totalViews: 38942,
        totalFollowers: 1284,
        revenueTotal: 4820000,
        revenueThisMonth: 1240000,
        topVideos: topVideos,
      ),
      topVideos: topVideos,
    );
  }
}
