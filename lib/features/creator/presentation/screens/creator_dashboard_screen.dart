import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/currency_provider.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../profile/presentation/providers/notification_provider.dart';
import '../../domain/creator_dashboard.dart';
import '../providers/creator_content_provider.dart';
import '../providers/creator_dashboard_provider.dart';
import '../widgets/creator_avatar.dart';
import '../widgets/creator_content_widgets.dart';
import '../widgets/dashboard_balance_card.dart';
import '../widgets/dashboard_stats_grid.dart';
import '../widgets/dashboard_top_videos.dart';
import '../widgets/notification_bell.dart';

/// Onglet Accueil du créateur.
///
/// Le contenu déjà chargé reste à l'écran pendant un rafraîchissement (tirer
/// pour actualiser, retour sur l'onglet) : seul un fin trait de progression
/// l'indique. Le plein écran de chargement n'apparaît qu'au tout premier
/// chargement.
class CreatorDashboardScreen extends ConsumerStatefulWidget {
  const CreatorDashboardScreen({
    super.key,
    this.minRefreshInterval = const Duration(seconds: 20),
  });

  /// Délai minimal entre deux actualisations automatiques au retour sur
  /// l'onglet, pour ne pas relancer quatre requêtes à chaque va-et-vient.
  final Duration minRefreshInterval;

  @override
  ConsumerState<CreatorDashboardScreen> createState() =>
      _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState
    extends ConsumerState<CreatorDashboardScreen> {
  ValueListenable<bool>? _tabActive;
  bool _wasActive = true;
  bool _pulling = false;
  DateTime _lastRefresh = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // L'onglet reste monté quand on en change ou qu'on ouvre un écran par-
    // dessus : seul `TickerMode` signale qu'il redevient visible.
    final notifier = TickerMode.getNotifier(context);
    if (!identical(notifier, _tabActive)) {
      _tabActive?.removeListener(_onTabVisibilityChanged);
      _tabActive = notifier..addListener(_onTabVisibilityChanged);
      _wasActive = notifier.value;
    }
  }

  @override
  void dispose() {
    _tabActive?.removeListener(_onTabVisibilityChanged);
    super.dispose();
  }

  void _onTabVisibilityChanged() {
    final active = _tabActive?.value ?? true;
    final becameVisible = active && !_wasActive;
    _wasActive = active;
    if (!becameVisible) return;
    // Le notifier change pendant la construction de l'arbre : on invalide les
    // providers après le cadre.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final recent =
          DateTime.now().difference(_lastRefresh) < widget.minRefreshInterval;
      if (recent || ref.read(creatorDashboardProvider).isLoading) return;
      _reload();
    });
  }

  /// Recharge le tableau de bord ET le compteur de notifications. La liste des
  /// vidéos est invalidée aussi : le tableau de bord la lit en cache, sans quoi
  /// les revenus des vidéos du top ne bougeraient pas.
  Future<void> _reload() {
    _lastRefresh = DateTime.now();
    ref.invalidate(creatorVideosProvider);
    return Future.wait([
      _ignoreErrors(ref.refresh(creatorDashboardProvider.future)),
      _ignoreErrors(ref.refresh(unreadNotificationCountProvider.future)),
    ]);
  }

  // L'erreur reste dans l'état du provider, où l'écran l'affiche.
  Future<void> _ignoreErrors(Future<Object?> future) =>
      future.then((_) {}, onError: (Object _) {});

  Future<void> _pullToRefresh() async {
    setState(() => _pulling = true);
    try {
      await _reload();
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creatorDashboardProvider);
    final dashboard = state.valueOrNull;
    // Indicateur discret ; le RefreshIndicator a déjà le sien au tirage.
    final refreshing = dashboard != null && state.isLoading && !_pulling;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: Column(
            children: [
              SizedBox(
                height: 2,
                child: refreshing
                    ? const LinearProgressIndicator(
                        color: AppColors.accent500,
                        backgroundColor: Colors.transparent,
                        semanticsLabel: 'Actualisation en cours',
                      )
                    : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accent500,
                  backgroundColor: AppColors.surface1,
                  onRefresh: _pullToRefresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: _slivers(state, dashboard),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _slivers(
    AsyncValue<CreatorDashboard> state,
    CreatorDashboard? dashboard,
  ) {
    if (dashboard != null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          sliver: SliverToBoxAdapter(
            child: _DashboardContent(
              dashboard: dashboard,
              // Échec d'un rafraîchissement : on garde les données affichées.
              refreshError: state.hasError && !state.isLoading
                  ? state.error
                  : null,
              onRetry: _reload,
            ),
          ),
        ),
      ];
    }

    // Une nouvelle tentative après une erreur repasse par le chargement.
    if (state.isLoading || !state.hasError) {
      return const [
        SliverFillRemaining(child: GnLoadingView(message: 'Chargement…')),
      ];
    }

    final error = state.error!;
    // 403 : compte non créateur. Le routeur l'en empêche normalement ; on
    // garde un état propre plutôt qu'une erreur réseau trompeuse.
    final notCreator =
        error is ApiException && error.kind == ApiErrorKind.forbidden;
    return [
      SliverFillRemaining(
        child: notCreator
            ? GnEmptyView(
                title: 'Espace réservé aux créateurs',
                message:
                    'Activez votre profil créateur pour publier des vidéos '
                    'et suivre vos gains.',
                actionLabel: 'Devenir créateur',
                onAction: () => context.go('/become-creator'),
              )
            : GnErrorView(
                message: friendlyErrorMessage(error),
                onRetry: _reload,
              ),
      ),
    ];
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.dashboard,
    required this.refreshError,
    required this.onRetry,
  });

  final CreatorDashboard dashboard;
  final Object? refreshError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(userCurrencyProvider);
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final user = dashboard.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (refreshError != null) ...[
          GnBanner(
            tone: GnBannerTone.danger,
            title: 'Actualisation impossible',
            message: friendlyErrorMessage(refreshError!),
            actionLabel: 'Réessayer',
            onAction: onRetry,
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            CreatorAvatar(initials: user.initials, imageUrl: user.avatar),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.text1,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const GnStatusPill(
                    label: 'CRÉATEUR',
                    tone: GnStatusTone.brand,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            NotificationBell(
              unreadCount: unread,
              onPressed: () => context.push('/notifications'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DashboardBalanceCard(
          withdrawableBalance: dashboard.withdrawableBalance,
          walletBalance: dashboard.walletBalance,
          revenueThisMonth: dashboard.analytics.revenueThisMonth,
          currency: currency,
          onWithdraw: () => context.push('/payout'),
        ),
        const SizedBox(height: 14),
        DashboardStatsGrid(analytics: dashboard.analytics),
        const SizedBox(height: 24),
        DashboardTopVideos(
          videos: dashboard.topVideos,
          currency: currency,
          onSeeAll: () => context.go('/videos'),
          // `push` : on garde l'onglet Accueil dessous et le retour y ramène.
          onOpenVideo: (video) => context.push('/videos/${video.videoId}'),
          onPublish: () => context.go('/publish'),
        ),
      ],
    );
  }
}
