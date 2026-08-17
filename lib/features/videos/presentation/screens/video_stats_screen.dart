import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_analytics.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';

class VideoStatsScreen extends ConsumerWidget {
  const VideoStatsScreen({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos =
        ref.watch(creatorVideosProvider).valueOrNull ??
        VideoWithStats.samples();
    final video = videos.firstWhere(
      (item) => item.id == videoId,
      orElse: () => VideoWithStats.sample(id: videoId),
    );
    final analytics =
        ref.watch(videoAnalyticsProvider(videoId)).valueOrNull ??
        VideoAnalytics.sample(videoId: videoId);
    final completion = analytics.completionPercent;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
            children: [
              _Header(onBack: () => _goBack(context)),
              const SizedBox(height: 16),
              _VideoPickerTile(video: video),
              const SizedBox(height: 28),
              Center(child: GnCompletionRing(percent: completion)),
              const SizedBox(height: 26),
              _MetricsTable(analytics: analytics),
              const SizedBox(height: 12),
              Text(
                'Le revenu affiché est déjà net de la commission de la plateforme.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text3,
                  fontSize: 11,
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
      context.go('/videos/$videoId');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.text2, size: 20),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Statistiques',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.text1,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _VideoPickerTile extends StatelessWidget {
  const _VideoPickerTile({required this.video});

  final VideoWithStats video;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(color: AppColors.text1),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Changer',
            style: AppTextStyles.micro.copyWith(
              color: AppColors.accent500,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, color: AppColors.accent500),
        ],
      ),
    );
  }
}

class _MetricsTable extends StatelessWidget {
  const _MetricsTable({required this.analytics});

  final VideoAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _MetricRow('Vues', formatGrouped(analytics.views)),
      _MetricRow('Spectateurs uniques', formatGrouped(analytics.uniqueViewers)),
      _MetricRow('Vues complètes', formatGrouped(analytics.completedViews)),
      _MetricRow('Likes', formatGrouped(analytics.likesCount)),
      _MetricRow('Achats', formatGrouped(analytics.purchasesCount)),
      _MetricRow('Revenu', formatMoney(analytics.revenue), AppColors.accent300),
    ];

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
            for (var i = 0; i < rows.length; i++)
              _TableLine(row: rows[i], showDivider: i < rows.length - 1),
          ],
        ),
      ),
    );
  }
}

class _TableLine extends StatelessWidget {
  const _TableLine({required this.row, required this.showDivider});

  final _MetricRow row;
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
            Text(
              row.value,
              style: AppTextStyles.label.copyWith(
                color: row.color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow {
  const _MetricRow(this.label, this.value, [this.color = AppColors.text1]);

  final String label;
  final String value;
  final Color color;
}
