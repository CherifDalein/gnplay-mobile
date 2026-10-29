import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/currency_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_analytics.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';
import '../widgets/video_picker_sheet.dart';

/// Statistiques détaillées d'une vidéo.
///
/// Le sélecteur « Changer » ouvre la liste des vidéos pour passer de l'une à
/// l'autre sans repasser par « Mon contenu ». Les chiffres déjà affichés
/// restent à l'écran pendant un rafraîchissement.
class VideoStatsScreen extends ConsumerStatefulWidget {
  const VideoStatsScreen({super.key, required this.videoId});

  final String videoId;

  @override
  ConsumerState<VideoStatsScreen> createState() => _VideoStatsScreenState();
}

class _VideoStatsScreenState extends ConsumerState<VideoStatsScreen> {
  late String _videoId = widget.videoId;
  bool _pulling = false;

  @override
  void didUpdateWidget(covariant VideoStatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) _videoId = widget.videoId;
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/videos/$_videoId');
    }
  }

  Future<void> _reload() {
    return Future.wait([
      ref
          .refresh(creatorVideosProvider.future)
          .then((_) {}, onError: (Object _) {}),
      ref
          .refresh(videoAnalyticsProvider(_videoId).future)
          .then((_) {}, onError: (Object _) {}),
    ]);
  }

  Future<void> _pullToRefresh() async {
    setState(() => _pulling = true);
    try {
      await _reload();
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  Future<void> _pickVideo(List<VideoWithStats> videos) async {
    final chosen = await showVideoPickerSheet(
      context,
      videos: videos,
      selectedId: _videoId,
    );
    if (chosen != null && chosen != _videoId && mounted) {
      setState(() => _videoId = chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoByIdProvider(_videoId));
    final listState = ref.watch(creatorVideosProvider);
    final analytics = ref.watch(videoAnalyticsProvider(_videoId));
    final refreshing =
        (listState.isLoading && listState.hasValue ||
            analytics.isLoading && analytics.hasValue) &&
        !_pulling;

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
                    slivers: [
                      SliverToBoxAdapter(
                        child: GnScreenHeader(
                          title: 'Statistiques',
                          onBack: _goBack,
                          padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                        ),
                      ),
                      ..._slivers(videoState, listState, analytics),
                    ],
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
    AsyncValue<VideoWithStats?> videoState,
    AsyncValue<List<VideoWithStats>> listState,
    AsyncValue<VideoAnalytics> analytics,
  ) {
    final video = videoState.valueOrNull;
    if (video == null) {
      final Widget message;
      if (videoState.hasValue) {
        final hasVideos = listState.valueOrNull?.isNotEmpty ?? false;
        message = GnEmptyView(
          title: hasVideos
              ? 'Cette vidéo n’existe plus'
              : 'Aucune vidéo pour le moment',
          message: hasVideos
              ? 'Elle a peut-être été supprimée.'
              : 'Les statistiques apparaissent dès que vous avez publié une '
                    'vidéo.',
          actionLabel: hasVideos ? 'Voir mes vidéos' : 'Publier une vidéo',
          onAction: () => context.go(hasVideos ? '/videos' : '/publish'),
        );
      } else if (videoState.hasError) {
        message = GnErrorView(
          message: friendlyErrorMessage(videoState.error!),
          onRetry: _reload,
        );
      } else {
        message = const GnLoadingView(message: 'Chargement…');
      }
      return [SliverFillRemaining(hasScrollBody: false, child: message)];
    }

    final videos = listState.valueOrNull ?? const <VideoWithStats>[];
    final currency = ref.watch(userCurrencyProvider);
    final data = analytics.valueOrNull;
    final refreshError =
        analytics.hasError && !analytics.isLoading && data != null
        ? analytics.error
        : null;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        sliver: SliverList.list(
          children: [
            _VideoPicker(
              video: video,
              onChange: videos.length > 1 ? () => _pickVideo(videos) : null,
            ),
            const SizedBox(height: 26),
            if (refreshError != null) ...[
              GnBanner(
                tone: GnBannerTone.danger,
                title: 'Actualisation impossible',
                message: friendlyErrorMessage(refreshError),
                actionLabel: 'Réessayer',
                onAction: _reload,
              ),
              const SizedBox(height: 14),
            ],
            if (data != null)
              _StatsContent(analytics: data, currency: currency)
            else if (analytics.hasError && !analytics.isLoading)
              GnErrorView(
                compact: true,
                message: friendlyErrorMessage(analytics.error!),
                onRetry: () => ref.invalidate(videoAnalyticsProvider(_videoId)),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: GnLoadingView(compact: true),
              ),
          ],
        ),
      ),
    ];
  }
}

/// Bouton h48 avec le titre de la vidéo et « Changer ⌄ » en or.
class _VideoPicker extends StatelessWidget {
  const _VideoPicker({required this.video, required this.onChange});

  final VideoWithStats video;

  /// `null` quand il n'y a qu'une vidéo : rien à changer.
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: const BorderSide(color: AppColors.border1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChange,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(color: AppColors.text1),
                  ),
                ),
                if (onChange != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    'Changer',
                    style: AppTextStyles.bodyText(
                      size: 11,
                      weight: FontWeight.w600,
                      color: AppColors.accent500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const GnLineIcon(
                    GnLineIconData.chevronDown,
                    size: 14,
                    color: AppColors.accent500,
                    strokeWidth: 2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.analytics, required this.currency});

  final VideoAnalytics analytics;
  final String currency;

  bool get _noActivity =>
      analytics.views == 0 &&
      analytics.purchasesCount == 0 &&
      analytics.likesCount == 0;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _Row('Vues totales', formatGrouped(analytics.views)),
      _Row('Spectateurs uniques', formatGrouped(analytics.uniqueViewers)),
      _Row('Vues complétées', formatGrouped(analytics.completedViews)),
      _Row('Likes', formatGrouped(analytics.likesCount)),
      _Row('Nombre d’achats', formatGrouped(analytics.purchasesCount)),
      _Row(
        'Revenu net (part créateur)',
        formatMoney(analytics.revenue, currency: currency),
        AppColors.accent300,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_noActivity) ...[
          const GnBanner(
            message:
                'Pas encore de statistiques : elles apparaissent dès que '
                'vos spectateurs regardent ou achètent la vidéo.',
          ),
          const SizedBox(height: 18),
        ],
        Center(child: GnCompletionRing(percent: analytics.completionPercent)),
        const SizedBox(height: 26),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface1,
            border: Border.all(color: AppColors.border1),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                _TableLine(row: rows[i], showDivider: i < rows.length - 1),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Les vues comptent les lectures de vos spectateurs : vos propres '
          'visionnages ne sont pas comptés. Le revenu affiché est déjà net '
          'de la commission de la plateforme.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.text3,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _TableLine extends StatelessWidget {
  const _TableLine({required this.row, required this.showDivider});

  final _Row row;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border2))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text2,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Un grand montant rétrécit au lieu de déborder.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  row.value,
                  maxLines: 1,
                  style: AppTextStyles.label.copyWith(
                    color: row.color,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value, [this.color = AppColors.text1]);

  final String label;
  final String value;
  final Color color;
}
