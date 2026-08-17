import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/creator_series.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';

class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(seriesMutationControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        error: (error, stackTrace) =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.danger,
                content: Text(
                  '$error',
                  style: AppTextStyles.caption.copyWith(color: AppColors.text1),
                ),
              ),
            ),
      );
    });

    final series =
        ref.watch(creatorSeriesDetailProvider(seriesId)).valueOrNull ??
        CreatorSeries.sample(id: seriesId);
    final mutationState = ref.watch(seriesMutationControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _SeriesHero(
                  series: series,
                  onBack: () => _goBack(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    _SaleModeCard(series: series),
                    const SizedBox(height: 24),
                    _EpisodesHeader(count: series.episodeCount),
                    const SizedBox(height: 11),
                    if (series.items.isEmpty)
                      const _NoEpisodes()
                    else
                      ...series.items.map(
                        (episode) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: _EpisodeTile(episode: episode),
                        ),
                      ),
                    const SizedBox(height: 2),
                    _AddEpisodeButton(onTap: () => context.go('/publish')),
                    const SizedBox(height: 20),
                    _SeriesStats(series: series),
                    const SizedBox(height: 14),
                    _PublicSwitch(
                      series: series,
                      isLoading: mutationState.isLoading,
                      onToggle: (value) {
                        ref
                            .read(seriesMutationControllerProvider.notifier)
                            .setPublic(series, value);
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/videos');
    }
  }
}

class _SeriesHero extends StatelessWidget {
  const _SeriesHero({required this.series, required this.onBack});

  final CreatorSeries series;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand900, AppColors.brand700],
        ),
        border: Border(bottom: BorderSide(color: AppColors.border1)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: _RoundHeroButton(icon: Icons.arrow_back, onPressed: onBack),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: AppColors.text1.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  'Série · ${series.episodeCount} épisodes',
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.text1,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.displayMd.copyWith(
                    color: AppColors.text1,
                    fontSize: 23,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${formatDurationShort(series.totalDuration)} au total · ${series.isPublic ? 'publique' : 'privée'}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text1.withValues(alpha: 0.75),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleModeCard extends StatelessWidget {
  const _SaleModeCard({required this.series});

  final CreatorSeries series;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mode de vente',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.text2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: const [
            Expanded(
              child: _ModeTile(
                title: 'Épisode',
                subtitle: 'Achat unitaire',
                selected: false,
              ),
            ),
            SizedBox(width: 9),
            Expanded(
              child: _ModeTile(
                title: 'Pack série',
                subtitle: 'Saison complète',
                selected: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        GnCard(
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Prix estimé du pack',
                  style: AppTextStyles.caption.copyWith(color: AppColors.text2),
                ),
              ),
              Text(
                formatMoney(
                  series.items.fold<int>(
                    0,
                    (total, item) => total + item.price,
                  ),
                ),
                style: AppTextStyles.label.copyWith(
                  color: AppColors.accent300,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Text(
          'Le pack économise 10 % au spectateur, argument affiché sur la fiche.',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.success,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  final String title;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      radius: 13,
      backgroundColor: selected ? AppColors.brand950 : AppColors.surface1,
      borderColor: selected ? AppColors.brand700 : AppColors.border1,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.label.copyWith(
              color: selected ? AppColors.accent300 : AppColors.text1,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.text3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodesHeader extends StatelessWidget {
  const _EpisodesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Épisodes',
            style: AppTextStyles.heading.copyWith(color: AppColors.text1),
          ),
        ),
        Text(
          count == 0 ? 'aucun épisode' : 'glisser pour réordonner',
          style: AppTextStyles.micro.copyWith(
            color: AppColors.text3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode});

  final CreatorSeriesEpisode episode;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      radius: 14,
      padding: const EdgeInsets.all(11),
      borderColor: episode.isPublished ? AppColors.border1 : AppColors.brand800,
      child: Row(
        children: [
          const Icon(Icons.drag_indicator, color: AppColors.text4, size: 18),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand600.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${episode.position}',
              style: AppTextStyles.micro.copyWith(
                color: AppColors.accent300,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 11),
          GnVideoThumbnail(
            url: episode.thumbnailUrl,
            width: 62,
            height: 40,
            label: '',
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.text1,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${episode.statusLabel} · ${formatDurationShort(episode.duration)}',
                  style: AppTextStyles.micro.copyWith(
                    color: episode.isPublished
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.close, color: AppColors.text4, size: 15),
        ],
      ),
    );
  }
}

class _AddEpisodeButton extends StatelessWidget {
  const _AddEpisodeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text1,
          backgroundColor: AppColors.surface2,
          side: const BorderSide(color: AppColors.border1, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
        icon: const GnLineIcon(
          GnLineIconData.plus,
          color: AppColors.accent500,
          size: 16,
        ),
        label: Text(
          'Ajouter un épisode',
          style: AppTextStyles.label.copyWith(
            color: AppColors.text1,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _SeriesStats extends StatelessWidget {
  const _SeriesStats({required this.series});

  final CreatorSeries series;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 9,
      mainAxisSpacing: 9,
      childAspectRatio: 1.1,
      children: [
        GnMetricTile(value: formatGrouped(series.totalViews), label: 'Vues'),
        GnMetricTile(value: '${series.episodeCount}', label: 'Épisodes'),
        GnMetricTile(
          value: formatCompact(series.totalRevenue),
          label: 'Revenu',
          valueColor: AppColors.accent300,
        ),
      ],
    );
  }
}

class _PublicSwitch extends StatelessWidget {
  const _PublicSwitch({
    required this.series,
    required this.isLoading,
    required this.onToggle,
  });

  final CreatorSeries series;
  final bool isLoading;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      radius: 13,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.isPublic ? 'Série publique' : 'Publier la série',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.text1,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  series.isPublic
                      ? 'Visible par les spectateurs'
                      : 'Gardée en préparation',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text3,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GnContentSwitch(
            value: series.isPublic,
            isLoading: isLoading,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _NoEpisodes extends StatelessWidget {
  const _NoEpisodes();

  @override
  Widget build(BuildContext context) {
    return GnCard(
      backgroundColor: AppColors.surface2,
      child: Text(
        'Ajoutez une vidéo depuis le flux de publication pour composer cette série.',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption.copyWith(color: AppColors.text3),
      ),
    );
  }
}

class _RoundHeroButton extends StatelessWidget {
  const _RoundHeroButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.text1, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.55),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
