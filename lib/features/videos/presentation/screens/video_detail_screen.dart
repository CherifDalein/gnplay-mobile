import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/currency_provider.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/repositories.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_analytics.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';
import '../video_actions.dart';
import '../video_display.dart';
import '../video_formatters.dart';
import '../video_polling.dart';
import '../widgets/video_edit_sheet.dart';
import '../widgets/video_preview_hero.dart';
import 'full_video_player_screen.dart';

/// Détail d'une vidéo : aperçu, informations, statistiques résumées,
/// publication, édition et suppression.
///
/// Comme la liste, l'écran garde son contenu pendant un rafraîchissement.
/// Tant que la vidéo est en traitement (ou qu'un aperçu est en cours de
/// création) ET que l'écran est visible, la vidéo est relue toute seule.
class VideoDetailScreen extends ConsumerStatefulWidget {
  const VideoDetailScreen({
    super.key,
    required this.videoId,
    this.pollInterval = const Duration(seconds: 5),
    this.previewTimeout = const Duration(minutes: 2),
  });

  final String videoId;

  /// Délai entre deux relectures de la vidéo (traitement, création d'aperçu).
  final Duration pollInterval;

  /// Durée maximale d'attente d'un aperçu demandé au serveur.
  final Duration previewTimeout;

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen>
    with ScreenVisibility<VideoDetailScreen> {
  static const _toastOffset = 32.0;

  late final RefreshPoller _poller = RefreshPoller(
    interval: widget.pollInterval,
    onTick: _pollTick,
  );
  PreviewGenerationPhase _phase = PreviewGenerationPhase.idle;
  String? _generationMessage;
  // Adresse renvoyée directement par le serveur (200), avant que la liste ne
  // soit relue.
  String? _previewUrl;
  Timer? _previewTimeout;
  bool _pulling = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<VideoWithStats?>>(
      videoByIdProvider(widget.videoId),
      (_, _) => _scheduleReconcile(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _poller.dispose();
    _previewTimeout?.cancel();
    super.dispose();
  }

  VideoWithStats? get _currentVideo =>
      ref.read(videoByIdProvider(widget.videoId)).valueOrNull;

  // Le fournisseur dérivé peut notifier pendant la construction : on règle
  // l'état de l'écran après le cadre.
  void _scheduleReconcile() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reconcile();
    });
  }

  void _reconcile() {
    final video = _currentVideo;
    if (_phase == PreviewGenerationPhase.waiting && video?.hasPreview == true) {
      _previewTimeout?.cancel();
      setState(() => _phase = PreviewGenerationPhase.idle);
    }
    _syncPolling();
  }

  void _syncPolling() {
    final waiting = _phase == PreviewGenerationPhase.waiting;
    _poller.sync(
      isScreenVisible && (waiting || (_currentVideo?.isTranscoding ?? false)),
    );
  }

  void _pollTick() {
    if (!mounted || ref.read(creatorVideosProvider).isLoading) return;
    ref.invalidate(creatorVideosProvider);
  }

  @override
  void onScreenVisibilityChanged(bool visible) => _syncPolling();

  Future<void> _reload() {
    ref.invalidate(videoAnalyticsProvider(widget.videoId));
    return ref
        .refresh(creatorVideosProvider.future)
        .then((_) {}, onError: (Object _) {});
  }

  Future<void> _pullToRefresh() async {
    setState(() => _pulling = true);
    try {
      await _reload();
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/videos');
    }
  }

  Future<void> _generatePreview(VideoWithStats video) async {
    if (_phase == PreviewGenerationPhase.requesting ||
        _phase == PreviewGenerationPhase.waiting) {
      return;
    }
    setState(() {
      _phase = PreviewGenerationPhase.requesting;
      _generationMessage = null;
    });
    try {
      final result = await ref
          .read(videoRepositoryProvider)
          .generatePreview(video.id);
      if (!mounted) return;
      if (result.isReady) {
        // 200 : l'aperçu existe déjà, on l'affiche sans attendre la liste.
        setState(() {
          _phase = PreviewGenerationPhase.idle;
          _previewUrl = result.previewUrl;
        });
        ref.invalidate(creatorVideosProvider);
        return;
      }
      // 202 : génération lancée en tâche de fond ; on relit la vidéo jusqu'à
      // voir `preview_url`, dans la limite du délai.
      setState(() => _phase = PreviewGenerationPhase.waiting);
      _previewTimeout?.cancel();
      _previewTimeout = Timer(widget.previewTimeout, _onPreviewTimeout);
      _syncPolling();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = PreviewGenerationPhase.idle;
        _generationMessage = friendlyErrorMessage(error);
      });
      // 409 : la liste que l'écran affiche est périmée (vidéo plus prête).
      if (error is ApiException && error.statusCode == 409) {
        ref.invalidate(creatorVideosProvider);
      }
    }
  }

  void _onPreviewTimeout() {
    if (!mounted || _phase != PreviewGenerationPhase.waiting) return;
    setState(() => _phase = PreviewGenerationPhase.timedOut);
    _syncPolling();
  }

  Future<void> _edit(VideoWithStats video) async {
    final saved = await showVideoEditSheet(context, video);
    if (saved && mounted) {
      showGnToast(
        context,
        'Modifications enregistrées.',
        tone: GnToastTone.success,
        bottomOffset: _toastOffset,
      );
    }
  }

  Future<void> _confirmDelete(VideoWithStats video) async {
    final confirmed = await showGnConfirmSheet(
      context,
      title: 'Supprimer cette vidéo ?',
      message:
          '« ${video.title} » disparaît de votre catalogue. Si personne ne '
          'l’a achetée, elle est supprimée définitivement ; sinon elle est '
          'seulement retirée du catalogue et reste conservée pour les '
          'spectateurs qui l’ont déjà achetée.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final controller = ref.read(videoMutationControllerProvider.notifier);
    try {
      final done = await controller.deleteVideo(video.id);
      if (!mounted || !done) return;
      // Le toast vit dans l'overlay racine : il survit à la fermeture.
      showGnToast(
        context,
        'Vidéo supprimée.',
        tone: GnToastTone.success,
        bottomOffset: _toastOffset,
      );
      _goBack();
    } catch (error) {
      if (!mounted) return;
      showGnToast(
        context,
        friendlyErrorMessage(error),
        tone: GnToastTone.error,
        bottomOffset: _toastOffset,
      );
    }
  }

  void _openFullPlayer(VideoWithStats video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FullVideoPlayerScreen(videoId: video.id, title: video.title),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoByIdProvider(widget.videoId));
    final listState = ref.watch(creatorVideosProvider);
    final refreshing = state.hasValue && listState.isLoading && !_pulling;

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
                  child: _body(state, listState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    AsyncValue<VideoWithStats?> state,
    AsyncValue<List<VideoWithStats>> listState,
  ) {
    final video = state.valueOrNull;
    if (video != null) {
      final shown = !video.hasPreview && _previewUrl != null
          ? video.copyWith(previewUrl: _previewUrl)
          : video;
      return _content(shown, listState);
    }

    final Widget message;
    if (state.hasValue) {
      message = GnEmptyView(
        title: 'Cette vidéo n’existe plus',
        message: 'Elle a peut-être été supprimée.',
        actionLabel: 'Retour à mes vidéos',
        onAction: () => context.go('/videos'),
      );
    } else if (state.hasError) {
      message = GnErrorView(
        message: friendlyErrorMessage(state.error!),
        onRetry: _reload,
      );
    } else {
      message = const GnLoadingView(message: 'Chargement…');
    }
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: GnScreenHeader(
            title: 'Vidéo',
            onBack: _goBack,
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
          ),
        ),
        SliverFillRemaining(hasScrollBody: false, child: message),
      ],
    );
  }

  Widget _content(
    VideoWithStats video,
    AsyncValue<List<VideoWithStats>> listState,
  ) {
    final currency = ref.watch(userCurrencyProvider);
    final busy = ref.watch(videoMutationControllerProvider).isBusy(video.id);
    final refreshError = listState.hasError && !listState.isLoading
        ? listState.error
        : null;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: VideoPreviewHero(
            video: video,
            onBack: _goBack,
            generation: _phase,
            generationMessage: _generationMessage,
            onGenerate: () => _generatePreview(video),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          sliver: SliverList.list(
            children: [
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
              _TitleBlock(
                video: video,
                currency: currency,
                onEdit: busy ? null : () => _edit(video),
              ),
              const SizedBox(height: 16),
              _StatusBanner(
                video: video,
                busy: busy,
                onRetry: () => retryVideoProcessing(
                  context,
                  ref,
                  video,
                  toastOffset: _toastOffset,
                ),
              ),
              if (video.isReady || video.isBlocked) ...[
                _StatsSection(video: video, currency: currency),
                const SizedBox(height: 14),
              ],
              GnButton(
                label: 'Voir la vidéo complète',
                variant: GnButtonVariant.ghost,
                icon: const GnLineIcon(
                  GnLineIconData.video,
                  color: AppColors.text1,
                  size: 17,
                ),
                onPressed: video.isReady ? () => _openFullPlayer(video) : null,
              ),
              if (video.isReady || video.isBlocked) ...[
                const SizedBox(height: 10),
                _StatsLink(
                  onTap: () => context.push('/videos/${video.id}/stats'),
                ),
              ],
              const SizedBox(height: 14),
              _PublishCard(
                video: video,
                busy: busy,
                onToggle: (value) => toggleVideoPublished(
                  context,
                  ref,
                  video,
                  value,
                  toastOffset: _toastOffset,
                ),
              ),
              const SizedBox(height: 22),
              GnButton(
                label: 'Supprimer la vidéo',
                variant: GnButtonVariant.danger,
                height: 48,
                icon: const GnLineIcon(
                  GnLineIconData.trash,
                  color: AppColors.danger,
                  size: 17,
                ),
                onPressed: busy ? null : () => _confirmDelete(video),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.video,
    required this.currency,
    required this.onEdit,
  });

  final VideoWithStats video;
  final String currency;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final duration = formatVideoDuration(video.duration);
    final meta = [
      video.statusLabel,
      videoPriceLabel(video.price, currency),
      ?duration,
    ].join(' · ');
    final dateLabel = video.lifecycle == VideoLifecycle.online
        ? 'Publiée le ${formatVideoDate(video.createdAt)}'
        : 'Ajoutée le ${formatVideoDate(video.createdAt)}';
    final description = video.description?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.text1,
                      fontSize: 19,
                      height: 25 / 19,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meta,
                    style: AppTextStyles.caption.copyWith(
                      color: videoStatusTone(video) == GnStatusTone.danger
                          ? AppColors.danger
                          : AppColors.text2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.text3,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GnButton(
              label: 'Modifier',
              variant: GnButtonVariant.ghost,
              size: GnButtonSize.sm,
              expand: false,
              icon: const GnLineIcon(
                GnLineIconData.edit,
                size: 15,
                color: AppColors.text1,
              ),
              onPressed: onEdit,
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.text2),
          ),
        ],
      ],
    );
  }
}

/// Bandeau d'état : échec (avec relance), traitement, envoi ou blocage.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.video,
    required this.busy,
    required this.onRetry,
  });

  final VideoWithStats video;
  final bool busy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (video.lifecycle) {
      case VideoLifecycle.failed:
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GnBanner(
                tone: GnBannerTone.danger,
                title: 'Le traitement de la vidéo a échoué',
                message:
                    'Votre fichier est conservé : relancez le traitement '
                    'sans tout renvoyer.',
              ),
              const SizedBox(height: 10),
              GnButton(
                label: 'Relancer le traitement',
                isLoading: busy,
                onPressed: busy ? null : onRetry,
              ),
            ],
          ),
        );
      case VideoLifecycle.processing:
        return const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: GnBanner(
            tone: GnBannerTone.warning,
            title: 'Traitement en cours',
            message:
                'La vidéo est en cours de préparation. Cette page se met à '
                'jour toute seule.',
          ),
        );
      case VideoLifecycle.uploading:
        return const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: GnBanner(
            tone: GnBannerTone.warning,
            title: 'Envoi incomplet',
            message:
                'L’envoi de cette vidéo n’est pas terminé : elle n’est pas '
                'encore visible dans le catalogue.',
          ),
        );
      case VideoLifecycle.blocked:
        return const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: GnBanner(
            tone: GnBannerTone.danger,
            title: 'Vidéo bloquée',
            message: 'Cette vidéo a été bloquée par la modération.',
          ),
        );
      case VideoLifecycle.online:
      case VideoLifecycle.hidden:
      case VideoLifecycle.deleted:
        return const SizedBox.shrink();
    }
  }
}

/// Six tuiles de statistiques puis le taux de complétion moyen.
class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.video, required this.currency});

  final VideoWithStats video;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoAnalyticsProvider(video.id));
    // Pendant un rechargement on garde les chiffres déjà affichés.
    final analytics = state.valueOrNull;

    if (analytics == null) {
      return state.hasError
          ? GnErrorView(
              compact: true,
              title: 'Statistiques indisponibles',
              message: friendlyErrorMessage(state.error!),
              onRetry: () => ref.invalidate(videoAnalyticsProvider(video.id)),
            )
          : const GnLoadingView(compact: true);
    }
    return _StatsContent(analytics: analytics, currency: currency);
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.analytics, required this.currency});

  final VideoAnalytics analytics;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final percent = analytics.completionPercent;

    Widget row(List<Widget> tiles) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 9),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );

    return Column(
      children: [
        row([
          GnMetricTile(value: formatGrouped(analytics.views), label: 'Vues'),
          GnMetricTile(
            value: formatGrouped(analytics.uniqueViewers),
            label: 'Spectateurs uniques',
          ),
          GnMetricTile(
            value: formatGrouped(analytics.completedViews),
            label: 'Vues complétées',
          ),
        ]),
        const SizedBox(height: 9),
        row([
          GnMetricTile(
            value: formatGrouped(analytics.likesCount),
            label: 'Likes',
          ),
          GnMetricTile(
            value: formatGrouped(analytics.purchasesCount),
            label: 'Achats',
          ),
          GnMetricTile(
            value: formatGrouped(analytics.revenue),
            label: 'Revenu net ($currency)',
            valueColor: AppColors.accent300,
          ),
        ]),
        const SizedBox(height: 9),
        GnCard(
          radius: AppRadii.r13,
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Taux de complétion moyen',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.text2,
                      ),
                    ),
                  ),
                  Text(
                    '${percent.round()} %',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.text1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              GnProgressBar(value: percent / 100),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsLink extends StatelessWidget {
  const _StatsLink({required this.onTap});

  final VoidCallback onTap;

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
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Voir les statistiques détaillées',
                    style: AppTextStyles.bodyText(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: AppColors.text1,
                    ),
                  ),
                ),
                const GnLineIcon(GnLineIconData.chevronRight, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublishCard extends StatelessWidget {
  const _PublishCard({
    required this.video,
    required this.busy,
    required this.onToggle,
  });

  final VideoWithStats video;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final canToggle = video.canTogglePublish;
    final String title;
    final String subtitle;
    if (!canToggle) {
      title = 'Publication indisponible';
      subtitle = switch (video.lifecycle) {
        VideoLifecycle.blocked => 'Cette vidéo est bloquée par la modération.',
        VideoLifecycle.failed => 'Relancez d’abord le traitement.',
        _ => 'Disponible une fois la vidéo traitée.',
      };
    } else if (video.isPublished) {
      title = 'En ligne';
      subtitle = 'Visible dans le catalogue public';
    } else {
      title = 'Masquée';
      subtitle = 'Non visible dans le catalogue public';
    }

    return GnCard(
      radius: AppRadii.r13,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.text1,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text3,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GnSwitch(
            value: video.isPublished,
            loading: busy,
            onChanged: canToggle ? onToggle : null,
            semanticLabel: 'Publier la vidéo dans le catalogue',
          ),
        ],
      ),
    );
  }
}
