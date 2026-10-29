import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/currency_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart'
    show friendlyErrorMessage;
import '../video_actions.dart';
import '../video_filter.dart';
import '../video_polling.dart';
import '../widgets/video_card.dart';

/// Onglet « Mon contenu » : toutes les vidéos du créateur.
///
/// Le contenu déjà chargé reste à l'écran pendant un rafraîchissement (tirer
/// pour actualiser, sondage, retour sur l'onglet, bascule de publication) : un
/// fin trait de progression l'indique, le plein écran de chargement n'apparaît
/// qu'au tout premier chargement.
///
/// Tant qu'une vidéo est en traitement ET que l'onglet est visible, la liste
/// se recharge toute seule ; le sondage s'arrête dès que l'une de ces deux
/// conditions tombe.
class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({
    super.key,
    this.pollInterval = const Duration(seconds: 6),
    this.minRefreshInterval = const Duration(seconds: 20),
  });

  /// Délai entre deux rechargements pendant qu'une vidéo est en traitement.
  final Duration pollInterval;

  /// Délai minimal entre deux actualisations automatiques au retour sur
  /// l'onglet.
  final Duration minRefreshInterval;

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen>
    with ScreenVisibility<VideosScreen> {
  final _searchController = TextEditingController();
  VideoFilter _filter = VideoFilter.all;
  String _query = '';
  bool _pulling = false;
  DateTime _lastRefresh = DateTime.now();
  late final RefreshPoller _poller = RefreshPoller(
    interval: widget.pollInterval,
    onTick: _pollTick,
  );

  @override
  void initState() {
    super.initState();
    // Le sondage se règle sur les données (une vidéo en traitement ?) et sur
    // la visibilité de l'onglet.
    ref.listenManual<AsyncValue<List<VideoWithStats>>>(
      creatorVideosProvider,
      (_, _) => _syncPolling(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _poller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasTranscoding {
    final videos = ref.read(creatorVideosProvider).valueOrNull;
    return videos != null && videos.any((video) => video.isTranscoding);
  }

  void _syncPolling() => _poller.sync(isScreenVisible && _hasTranscoding);

  void _pollTick() {
    if (!mounted || ref.read(creatorVideosProvider).isLoading) return;
    _lastRefresh = DateTime.now();
    ref.invalidate(creatorVideosProvider);
  }

  @override
  void onScreenVisibilityChanged(bool visible) {
    _syncPolling();
    if (!visible) return;
    // Retour sur l'onglet (ex. après un envoi) : on recharge, mais pas à
    // chaque va-et-vient. Le notifier change pendant la construction de
    // l'arbre : les providers ne sont touchés qu'après le cadre.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final recent =
          DateTime.now().difference(_lastRefresh) < widget.minRefreshInterval;
      if (recent || ref.read(creatorVideosProvider).isLoading) return;
      _reload();
    });
  }

  Future<void> _reload() {
    _lastRefresh = DateTime.now();
    // L'erreur reste dans l'état du provider, où l'écran l'affiche.
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

  void _setFilter(VideoFilter filter) => setState(() => _filter = filter);

  void _setQuery(String value) => setState(() => _query = value);

  void _resetSearchAndFilter() {
    _searchController.clear();
    setState(() {
      _query = '';
      _filter = VideoFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creatorVideosProvider);
    final videos = state.valueOrNull;
    // Indicateur discret ; le RefreshIndicator a déjà le sien au tirage.
    final refreshing = videos != null && state.isLoading && !_pulling;

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
                    slivers: _slivers(state, videos),
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
    AsyncValue<List<VideoWithStats>> state,
    List<VideoWithStats>? videos,
  ) {
    const gutter = EdgeInsets.symmetric(horizontal: 20);

    if (videos == null) {
      // Une nouvelle tentative après une erreur repasse par le chargement.
      final loading = state.isLoading || !state.hasError;
      return [
        const SliverToBoxAdapter(child: _Header()),
        SliverFillRemaining(
          hasScrollBody: false,
          child: loading
              ? const GnLoadingView(message: 'Chargement…')
              : GnErrorView(
                  message: friendlyErrorMessage(state.error!),
                  onRetry: _reload,
                ),
        ),
      ];
    }

    if (videos.isEmpty) {
      return [
        const SliverToBoxAdapter(child: _Header()),
        if (state.hasError && !state.isLoading)
          SliverToBoxAdapter(child: _refreshBanner(state.error!)),
        SliverFillRemaining(
          hasScrollBody: false,
          child: GnEmptyView(
            title: 'Publiez votre première vidéo',
            message:
                'Vos vidéos apparaîtront ici, avec leurs vues et leurs '
                'revenus.',
            actionLabel: 'Publier une vidéo',
            onAction: () => context.go('/publish'),
          ),
        ),
      ];
    }

    final counts = VideoFilterCounts(videos);
    final filters = counts.visible(_filter);
    final shown = filterVideos(videos, filter: _filter, query: _query);
    final currency = ref.watch(userCurrencyProvider);
    final busyIds = ref.watch(videoMutationControllerProvider).busyVideoIds;

    return [
      const SliverToBoxAdapter(child: _Header()),
      if (state.hasError && !state.isLoading)
        SliverToBoxAdapter(child: _refreshBanner(state.error!)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        sliver: SliverToBoxAdapter(
          child: GnSearchField(
            controller: _searchController,
            hintText: 'Rechercher une vidéo',
            onChanged: _setQuery,
          ),
        ),
      ),
      if (filters.isNotEmpty)
        SliverToBoxAdapter(
          child: _FilterChips(
            filters: filters,
            selected: _filter,
            counts: counts,
            onSelected: _setFilter,
          ),
        ),
      SliverPadding(
        padding: gutter.copyWith(top: 12, bottom: 10),
        sliver: SliverToBoxAdapter(
          child: Text(
            shown.length > 1
                ? '${shown.length} vidéos'
                : '${shown.length} vidéo',
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
        ),
      ),
      if (shown.isEmpty)
        SliverFillRemaining(hasScrollBody: false, child: _noMatch())
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.separated(
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(height: 11),
            itemBuilder: (context, index) {
              final video = shown[index];
              return VideoCard(
                key: ValueKey(video.id),
                video: video,
                currency: currency,
                busy: busyIds.contains(video.id),
                // `push` : on garde la liste dessous et le retour y ramène.
                onOpen: () => context.push('/videos/${video.id}'),
                onTogglePublish: (value) =>
                    toggleVideoPublished(context, ref, video, value),
                onRetryProcessing: () =>
                    retryVideoProcessing(context, ref, video),
              );
            },
          ),
        ),
    ];
  }

  Widget _refreshBanner(Object error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: GnBanner(
        tone: GnBannerTone.danger,
        title: 'Actualisation impossible',
        message: friendlyErrorMessage(error),
        actionLabel: 'Réessayer',
        onAction: _reload,
      ),
    );
  }

  Widget _noMatch() {
    if (_query.trim().isNotEmpty) {
      return GnEmptyView(
        compact: true,
        icon: const GnLineIcon(GnLineIconData.search, size: 22),
        title: 'Aucun résultat',
        message: 'Aucune vidéo ne correspond à « ${_query.trim()} ».',
        actionLabel: 'Effacer la recherche',
        onAction: _resetSearchAndFilter,
      );
    }
    return GnEmptyView(
      compact: true,
      title: 'Aucune vidéo « ${_filter.label} »',
      message:
          'Aucune de vos vidéos n’est dans cette catégorie pour le moment.',
      actionLabel: 'Voir toutes les vidéos',
      onAction: () => _setFilter(VideoFilter.all),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Mon contenu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.text1,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const _NewVideoButton(),
        ],
      ),
    );
  }
}

/// Pastille « Nouvelle vidéo » : 34 px visibles, zone tactile de 44 px.
class _NewVideoButton extends StatelessWidget {
  const _NewVideoButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nouvelle vidéo',
      excludeSemantics: true,
      onTap: () => context.go('/publish'),
      child: InkResponse(
        onTap: () => context.go('/publish'),
        radius: 28,
        child: SizedBox(
          height: 44,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accentTint12,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: AppColors.accentBorder35),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GnLineIcon(
                      GnLineIconData.plus,
                      size: 14,
                      color: AppColors.accent500,
                      strokeWidth: 2.2,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Nouvelle vidéo',
                      style: AppTextStyles.bodyText(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: AppColors.accent500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filters,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final List<VideoFilter> filters;
  final VideoFilter selected;
  final VideoFilterCounts counts;
  final ValueChanged<VideoFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    // Les puces passent à la ligne plutôt que de défiler : aucune n'est
    // cachée hors de l'écran.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: GnChipGroup<VideoFilter>(
        options: [
          for (final filter in filters)
            GnChipOption(
              value: filter,
              label: '${filter.label} (${counts.of(filter)})',
            ),
        ],
        selected: selected,
        onSelected: onSelected,
      ),
    );
  }
}
