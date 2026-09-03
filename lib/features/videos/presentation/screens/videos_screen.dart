import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';

enum _VideoFilter { all, published, drafts, processing, failed }

class VideosScreen extends ConsumerStatefulWidget {
  const VideosScreen({super.key});

  @override
  ConsumerState<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends ConsumerState<VideosScreen> {
  final _searchController = TextEditingController();

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

    final videosState = ref.watch(creatorVideosProvider);
    final mutationState = ref.watch(videoMutationControllerProvider);

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
                if (_filtersOpen) ...[
                  const SizedBox(height: 14),
                  _FilterChips(
                    selected: _filter,
                    onChanged: (filter) => setState(() => _filter = filter),
                  ),
                ],
                switch (videosState) {
                  AsyncData(:final value) => _buildList(value, mutationState),
                  AsyncError(:final error) => GnAsyncError(
                    message: friendlyErrorMessage(error),
                    onRetry: () => ref.invalidate(creatorVideosProvider),
                  ),
                  _ => const GnLoadingState(),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<VideoWithStats> videos, AsyncValue<void> mutationState) {
    final filteredVideos = _filteredVideos(videos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          _EmptyState(
            title: videos.isEmpty ? 'Aucune vidéo publiée' : 'Aucun résultat',
            subtitle: videos.isEmpty
                ? 'Publiez votre première vidéo pour la retrouver ici.'
                : 'Essayez un autre filtre ou une autre recherche.',
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
      ],
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
      final future = ref.refresh(creatorVideosProvider.future);
      await future;
    } catch (_) {
      // L'erreur est déjà affichée via l'état AsyncError du provider.
    }
  }

  Future<void> _togglePublish(VideoWithStats video, bool value) async {
    await ref
        .read(videoMutationControllerProvider.notifier)
        .setPublished(video, value);
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
                            'Le transfert a échoué.',
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
