import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/creator_series.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';

enum _ContentTab { videos, series }

enum _VideoFilter { all, published, drafts, processing, failed }

class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  final _searchController = TextEditingController();

  _ContentTab _tab = _ContentTab.videos;
  _VideoFilter _filter = _VideoFilter.all;
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(videoMutationControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(error: (error, stackTrace) => _showError(error));
    });
    ref.listen<AsyncValue<void>>(seriesMutationControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(error: (error, stackTrace) => _showError(error));
    });

    final videosState = ref.watch(creatorVideosProvider);
    final seriesState = ref.watch(creatorSeriesProvider);
    final mutationState = ref.watch(videoMutationControllerProvider);
    final videos = videosState.valueOrNull ?? VideoWithStats.samples();
    final series = seriesState.valueOrNull ?? CreatorSeries.samples();
    final filteredVideos = _filteredVideos(videos);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: RefreshIndicator(
            color: AppColors.accent500,
            backgroundColor: AppColors.surface1,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
              children: [
                _Header(onPublish: () => context.go('/publish')),
                const SizedBox(height: 16),
                _SearchAndFilter(
                  controller: _searchController,
                  filtersOpen: _filtersOpen,
                  filterActive: _filter != _VideoFilter.all,
                  onToggleFilters: () {
                    setState(() => _filtersOpen = !_filtersOpen);
                  },
                ),
                const SizedBox(height: 12),
                _ContentTabs(
                  tab: _tab,
                  videoCount: videos.length,
                  seriesCount: series.length,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
                if (_tab == _ContentTab.videos) ...[
                  if (_filtersOpen) ...[
                    const SizedBox(height: 14),
                    _FilterChips(
                      selected: _filter,
                      onChanged: (filter) => setState(() => _filter = filter),
                    ),
                  ],
                  if (_filter != _VideoFilter.all) ...[
                    const SizedBox(height: 14),
                    _ActiveFilter(
                      filter: _filter,
                      resultCount: filteredVideos.length,
                      onClear: () {
                        setState(() => _filter = _VideoFilter.all);
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (filteredVideos.isEmpty)
                    const _EmptyState(
                      title: 'Aucune vidéo',
                      subtitle:
                          'Essayez un autre filtre ou publiez un contenu.',
                    )
                  else
                    ...filteredVideos.map(
                      (video) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _VideoCard(
                          video: video,
                          isLoading: mutationState.isLoading,
                          onOpen: () => context.go('/videos/${video.id}'),
                          onRetry: () => context.go('/publish'),
                          onToggle: (value) => _togglePublish(video, value),
                        ),
                      ),
                    ),
                ] else ...[
                  const SizedBox(height: 16),
                  Text(
                    'Regroupez vos vidéos en mini-séries : les spectateurs suivent l’ordre des épisodes et peuvent acheter la saison entière.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.text3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (series.isEmpty)
                    const _EmptyState(
                      title: 'Aucune série',
                      subtitle: 'Créez une série pour organiser vos épisodes.',
                    )
                  else
                    ...series.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SeriesCard(
                          series: item,
                          onOpen: () => context.go('/videos/series/${item.id}'),
                        ),
                      ),
                    ),
                  _CreateSeriesButton(onTap: _openCreateSeriesSheet),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<VideoWithStats> _filteredVideos(List<VideoWithStats> videos) {
    final query = _searchController.text.trim().toLowerCase();

    return videos.where((video) {
      final matchesQuery =
          query.isEmpty ||
          video.title.toLowerCase().contains(query) ||
          (video.description ?? '').toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _VideoFilter.all => true,
        _VideoFilter.published => video.isPublished,
        _VideoFilter.drafts => video.isDraft,
        _VideoFilter.processing => video.isProcessing,
        _VideoFilter.failed => video.isFailed,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  Future<void> _refresh() async {
    try {
      if (_tab == _ContentTab.videos) {
        final future = ref.refresh(creatorVideosProvider.future);
        await future;
      } else {
        final future = ref.refresh(creatorSeriesProvider.future);
        await future;
      }
    } catch (_) {
      // The screen already keeps a local preview dataset for offline tests.
    }
  }

  Future<void> _togglePublish(VideoWithStats video, bool value) async {
    await ref
        .read(videoMutationControllerProvider.notifier)
        .setPublished(video, value);
  }

  void _openCreateSeriesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateSeriesSheet(),
    );
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(
          '$error',
          style: AppTextStyles.caption.copyWith(color: AppColors.text1),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onPublish});

  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Mon contenu',
            style: AppTextStyles.title.copyWith(
              color: AppColors.text1,
              fontSize: 22,
            ),
          ),
        ),
        SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            onPressed: onPublish,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent500,
              backgroundColor: AppColors.accent500.withValues(alpha: 0.12),
              side: BorderSide(
                color: AppColors.accent500.withValues(alpha: 0.35),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const GnLineIcon(
              GnLineIconData.plus,
              color: AppColors.accent500,
              size: 14,
            ),
            label: Text(
              'Publier',
              style: AppTextStyles.micro.copyWith(
                color: AppColors.accent500,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchAndFilter extends StatelessWidget {
  const _SearchAndFilter({
    required this.controller,
    required this.filtersOpen,
    required this.filterActive,
    required this.onToggleFilters,
  });

  final TextEditingController controller;
  final bool filtersOpen;
  final bool filterActive;
  final VoidCallback onToggleFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: controller,
              cursorColor: AppColors.accent500,
              style: AppTextStyles.body.copyWith(color: AppColors.text1),
              decoration: InputDecoration(
                hintText: 'Rechercher une vidéo',
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.text3,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.text3,
                  size: 18,
                ),
                filled: true,
                fillColor: AppColors.surface1,
                contentPadding: EdgeInsets.zero,
                border: _fieldBorder(AppColors.border1),
                enabledBorder: _fieldBorder(AppColors.border1),
                focusedBorder: _fieldBorder(AppColors.brand700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: OutlinedButton(
                onPressed: onToggleFilters,
                style: OutlinedButton.styleFrom(
                  backgroundColor: filtersOpen
                      ? AppColors.brand950
                      : AppColors.surface1,
                  side: BorderSide(
                    color: filtersOpen ? AppColors.brand700 : AppColors.border1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Icon(
                  Icons.tune,
                  color: filtersOpen ? AppColors.accent500 : AppColors.text3,
                  size: 18,
                ),
              ),
            ),
            if (filterActive)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.accent500,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgApp, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  OutlineInputBorder _fieldBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color),
    );
  }
}

class _ContentTabs extends StatelessWidget {
  const _ContentTabs({
    required this.tab,
    required this.videoCount,
    required this.seriesCount,
    required this.onChanged,
  });

  final _ContentTab tab;
  final int videoCount;
  final int seriesCount;
  final ValueChanged<_ContentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border1),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _TabButton(
              label: 'Vidéos',
              count: videoCount,
              selected: tab == _ContentTab.videos,
              onTap: () => onChanged(_ContentTab.videos),
            ),
            _TabButton(
              label: 'Séries',
              count: seriesCount,
              selected: tab == _ContentTab.series,
              onTap: () => onChanged(_ContentTab.series),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 36,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: selected ? AppColors.text1 : AppColors.text3,
            backgroundColor: selected ? AppColors.brand800 : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: selected ? AppColors.text1 : AppColors.text3,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent500.withValues(alpha: 0.18)
                      : AppColors.surface3,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  child: Text(
                    '$count',
                    style: AppTextStyles.micro.copyWith(
                      color: selected ? AppColors.accent300 : AppColors.text3,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final _VideoFilter selected;
  final ValueChanged<_VideoFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      backgroundColor: AppColors.surface2,
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _VideoFilter.values.map((filter) {
          final active = selected == filter;
          return ChoiceChip(
            selected: active,
            onSelected: (_) => onChanged(filter),
            label: Text(_filterLabel(filter)),
            labelStyle: AppTextStyles.caption.copyWith(
              color: active ? AppColors.text1 : AppColors.text2,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: AppColors.surface1,
            selectedColor: AppColors.brand800,
            side: BorderSide(
              color: active ? AppColors.brand500 : AppColors.border1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActiveFilter extends StatelessWidget {
  const _ActiveFilter({
    required this.filter,
    required this.resultCount,
    required this.onClear,
  });

  final _VideoFilter filter;
  final int resultCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Filtre :',
          style: AppTextStyles.micro.copyWith(color: AppColors.text3),
        ),
        const SizedBox(width: 8),
        ActionChip(
          onPressed: onClear,
          backgroundColor: AppColors.brand600.withValues(alpha: 0.2),
          side: const BorderSide(color: AppColors.brand500),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _filterLabel(filter),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 7),
              const Icon(Icons.close, color: AppColors.text1, size: 11),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$resultCount résultat${resultCount > 1 ? 's' : ''}',
          style: AppTextStyles.micro.copyWith(color: AppColors.text3),
        ),
      ],
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.isLoading,
    required this.onOpen,
    required this.onRetry,
    required this.onToggle,
  });

  final VideoWithStats video;
  final bool isLoading;
  final VoidCallback onOpen;
  final VoidCallback onRetry;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          border: Border.all(color: AppColors.border1),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GnVideoThumbnail(
                        url: video.thumbnailUrl,
                        width: 104,
                        height: 66,
                        durationLabel: formatDurationShort(video.duration),
                        label: 'miniature 16:9',
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.text1,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 7),
                            GnStatusPill(
                              label: video.statusLabel,
                              tone: _statusTone(video),
                            ),
                            const SizedBox(height: 7),
                            RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.text3,
                                  fontSize: 11,
                                ),
                                children: [
                                  TextSpan(text: _priceLabel(video.price)),
                                  TextSpan(
                                    text:
                                        ' · ${formatGrouped(video.viewCount)} vues · ',
                                  ),
                                  TextSpan(
                                    text: formatMoney(video.revenue),
                                    style: const TextStyle(
                                      color: AppColors.accent300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: GnLineIcon(
                          GnLineIconData.chevronRight,
                          color: AppColors.text4,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (video.isFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Le transfert a échoué à 62 %.',
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: onRetry,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.text1,
                            backgroundColor: AppColors.danger,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 30),
                          ),
                          child: Text(
                            'Réessayer',
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.text1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border2)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        video.isPublished
                            ? 'Vidéo publiée'
                            : 'Publier dans le catalogue',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.text2,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    GnContentSwitch(
                      value: video.isPublished,
                      isLoading: isLoading,
                      onChanged: video.isProcessing || video.isFailed
                          ? null
                          : onToggle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.series, required this.onOpen});

  final CreatorSeries series;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final episodeCount = series.episodeCount;
    final progress = (episodeCount / 4).clamp(0, 1).toDouble();
    final mode = series.isPublic ? 'Pack saison actif' : 'Préparation privée';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: GnCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SeriesStack(episodeCount: episodeCount),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.text1,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 7),
                        GnStatusPill(
                          label: series.isPublic ? 'Publique' : 'Privée',
                          tone: series.isPublic
                              ? GnStatusTone.success
                              : GnStatusTone.neutral,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${formatGrouped(episodeCount)} épisode${episodeCount > 1 ? 's' : ''} · ${formatDurationShort(series.totalDuration)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.text3,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mode,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent300,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GnProgressBar(value: progress),
              const SizedBox(height: 6),
              Text(
                '$episodeCount épisode${episodeCount > 1 ? 's' : ''} organisé${episodeCount > 1 ? 's' : ''}',
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.text3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesStack extends StatelessWidget {
  const _SeriesStack({required this.episodeCount});

  final int episodeCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 70,
      child: Stack(
        children: [
          Positioned(
            left: 9,
            right: 0,
            top: 0,
            height: 60,
            child: _stackLayer(AppColors.brand950),
          ),
          Positioned(
            left: 4.5,
            right: 4.5,
            top: 5,
            height: 60,
            child: _stackLayer(AppColors.brand900),
          ),
          Positioned(
            left: 0,
            right: 9,
            top: 10,
            height: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.brand900,
                border: Border.all(color: AppColors.border1),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Center(
                child: Text(
                  '$episodeCount',
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.text1,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stackLayer(Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.border1),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    );
  }
}

class _CreateSeriesButton extends StatelessWidget {
  const _CreateSeriesButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border1, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              children: [
                const GnLineIcon(
                  GnLineIconData.plus,
                  color: AppColors.accent500,
                  size: 22,
                ),
                const SizedBox(height: 8),
                Text(
                  'Créer une série',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.text1,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Titre, ordre des épisodes, prix du pack',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.text3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateSeriesSheet extends ConsumerStatefulWidget {
  const _CreateSeriesSheet();

  @override
  ConsumerState<_CreateSeriesSheet> createState() => _CreateSeriesSheetState();
}

class _CreateSeriesSheetState extends ConsumerState<_CreateSeriesSheet> {
  final _nameController = TextEditingController(text: 'Nouvelle mini-série');
  final _descriptionController = TextEditingController();
  bool _isPublic = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(seriesMutationControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: GnCard(
        backgroundColor: AppColors.surface2,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Créer une série',
              style: AppTextStyles.heading.copyWith(color: AppColors.text1),
            ),
            const SizedBox(height: 14),
            GnTextField(controller: _nameController, label: 'Titre'),
            const SizedBox(height: 12),
            GnTextField(
              controller: _descriptionController,
              label: 'Description',
              minLines: 2,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rendre publique',
                    style: AppTextStyles.label.copyWith(color: AppColors.text1),
                  ),
                ),
                GnContentSwitch(
                  value: _isPublic,
                  onChanged: (value) => setState(() => _isPublic = value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GnButton(
              label: 'Créer',
              isLoading: state.isLoading,
              onPressed: state.isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    await ref
        .read(seriesMutationControllerProvider.notifier)
        .createSeries(
          name: name,
          description: _descriptionController.text,
          isPublic: _isPublic,
        );

    if (mounted && !ref.read(seriesMutationControllerProvider).hasError) {
      Navigator.of(context).pop();
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      backgroundColor: AppColors.surface2,
      child: Column(
        children: [
          const SizedBox(height: 10),
          const GnLineIcon(
            GnLineIconData.video,
            color: AppColors.text4,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTextStyles.label.copyWith(color: AppColors.text1),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

String _filterLabel(_VideoFilter filter) {
  return switch (filter) {
    _VideoFilter.all => 'Toutes',
    _VideoFilter.published => 'Publiées',
    _VideoFilter.drafts => 'Brouillons',
    _VideoFilter.processing => 'Traitement',
    _VideoFilter.failed => 'Échec',
  };
}

String _priceLabel(int price) {
  return price <= 0 ? 'Gratuite' : formatMoney(price);
}

GnStatusTone _statusTone(VideoWithStats video) {
  if (video.isFailed) {
    return GnStatusTone.danger;
  }
  if (video.isProcessing) {
    return GnStatusTone.warning;
  }
  if (video.isPublished) {
    return GnStatusTone.success;
  }
  return GnStatusTone.neutral;
}
