import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/repositories.dart';
import '../../../profile/presentation/providers/current_user_provider.dart';
import '../../../auth/domain/user_read.dart';
import '../../domain/creator_analytics.dart';
import '../../domain/creator_dashboard.dart';
import '../../domain/payout_balances.dart';
import '../../domain/top_video.dart';
import '../../domain/video_with_stats.dart';
import 'creator_content_provider.dart';

/// Tableau de bord : compte, statistiques globales, soldes et meilleures
/// vidéos. Les appels partent en parallèle ; la liste des vidéos est partagée
/// avec l'onglet Vidéos (pas de second téléchargement).
final creatorDashboardProvider = FutureProvider.autoDispose<CreatorDashboard>((
  ref,
) async {
  // Future.wait écoute tous les appels : une erreur sur l'un ne laisse pas
  // les autres échouer sans gestionnaire.
  final results = await Future.wait<Object?>([
    ref.watch(currentUserProvider.future),
    ref.watch(creatorAnalyticsRepositoryProvider).load(),
    ref.watch(walletRepositoryProvider).loadBalances(),
    ref.watch(creatorVideosProvider.future),
  ]);
  final user = results[0] as UserRead?;
  final analytics = results[1] as CreatorAnalytics;
  final balances = results[2] as PayoutBalances;
  final videos = results[3] as List<VideoWithStats>;

  if (user == null) {
    throw const ApiException(
      'Vous devez vous connecter.',
      kind: ApiErrorKind.unauthorized,
      statusCode: 401,
    );
  }

  return CreatorDashboard(
    user: user,
    withdrawableBalance: balances.withdrawableBalance,
    walletBalance: balances.walletBalance,
    analytics: analytics,
    topVideos: _topVideos(analytics.topVideos, videos),
  );
});

/// Le top 5 de `/creators/me/analytics` n'a ni miniature ni revenu : on les
/// complète depuis la liste des vidéos. Sans top (aucune vue), on prend les
/// vidéos les plus vues.
List<TopVideo> _topVideos(
  List<TopVideo> fromAnalytics,
  List<VideoWithStats> videos,
) {
  final byId = {for (final video in videos) video.id: video};
  if (fromAnalytics.isNotEmpty) {
    return [
      for (final top in fromAnalytics)
        top.copyWith(
          revenue: byId[top.videoId]?.revenue,
          thumbnailUrl: byId[top.videoId]?.thumbnailUrl,
        ),
    ];
  }
  final sorted = [...videos]
    ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
  return [
    for (final video in sorted.take(5))
      TopVideo(
        videoId: video.id,
        title: video.title,
        viewCount: video.viewCount,
        likesCount: video.likesCount,
        revenue: video.revenue,
        thumbnailUrl: video.thumbnailUrl,
      ),
  ];
}
