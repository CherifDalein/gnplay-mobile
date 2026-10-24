import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../domain/top_video.dart';
import 'creator_content_widgets.dart';

/// Section « Vos vidéos les plus vues » : titre, lien « Tout voir » et une
/// ligne par vidéo. Sans vidéo, invite à publier la première.
class DashboardTopVideos extends StatelessWidget {
  const DashboardTopVideos({
    super.key,
    required this.videos,
    required this.currency,
    required this.onSeeAll,
    required this.onOpenVideo,
    required this.onPublish,
  });

  final List<TopVideo> videos;
  final String currency;
  final VoidCallback onSeeAll;
  final ValueChanged<TopVideo> onOpenVideo;
  final VoidCallback onPublish;

  /// Le top affiché ne dépasse jamais cinq vidéos.
  static const int maxVideos = 5;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return GnCard(
        radius: AppRadii.r14,
        child: GnEmptyView(
          compact: true,
          title: 'Publiez votre première vidéo',
          message:
              'Vos vidéos les plus vues et leurs revenus apparaîtront ici.',
          icon: const GnLineIcon(GnLineIconData.video, size: 20),
          actionLabel: 'Publier une vidéo',
          onAction: onPublish,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Vos vidéos les plus vues',
                  style: AppTextStyles.heading.copyWith(color: AppColors.text1),
                ),
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent500,
                textStyle: AppTextStyles.caption.copyWith(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 44),
              ),
              child: const Text('Tout voir'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final video in videos.take(maxVideos))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TopVideoTile(
              video: video,
              currency: currency,
              onTap: () => onOpenVideo(video),
            ),
          ),
      ],
    );
  }
}

class _TopVideoTile extends StatelessWidget {
  const _TopVideoTile({
    required this.video,
    required this.currency,
    required this.onTap,
  });

  final TopVideo video;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final views =
        '${formatGrouped(video.viewCount)} '
        '${video.viewCount > 1 ? 'vues' : 'vue'}';
    final revenue = formatMoney(video.revenue, currency: currency);

    return Semantics(
      button: true,
      label: '${video.title}, $views, $revenue',
      excludeSemantics: true,
      onTap: onTap,
      child: GnCard(
        padding: EdgeInsets.zero,
        radius: AppRadii.r14,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.r14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Repli rayé si la miniature manque ou ne se charge pas.
                  GnVideoThumbnail(
                    url: video.thumbnailUrl,
                    width: 74,
                    height: 48,
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.text3,
                              fontSize: 11,
                            ),
                            children: [
                              TextSpan(text: '$views · '),
                              TextSpan(
                                text: revenue,
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
                  const GnLineIcon(
                    GnLineIconData.chevronRight,
                    color: AppColors.text4,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
