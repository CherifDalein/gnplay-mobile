import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';
import '../video_display.dart';
import '../video_formatters.dart';

/// Carte d'une vidéo dans « Mon contenu ».
///
/// Le corps de la carte ouvre le détail ; le pied (interrupteur de
/// publication, relance du traitement ou état en cours) est un bloc à part,
/// pour qu'un toucher sur l'interrupteur n'ouvre jamais le détail.
class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.currency,
    required this.busy,
    required this.onOpen,
    required this.onTogglePublish,
    required this.onRetryProcessing,
  });

  final VideoWithStats video;

  /// Devise du compte (XOF, GNF…).
  final String currency;

  /// Une action (publication, relance) est en cours sur cette vidéo.
  final bool busy;

  final VoidCallback onOpen;
  final ValueChanged<bool> onTogglePublish;
  final VoidCallback onRetryProcessing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadii.r13),
        border: Border.all(color: AppColors.border1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.r13),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: _CardBody(video: video, currency: currency),
              ),
            ),
          ),
          _CardFooter(
            video: video,
            busy: busy,
            onTogglePublish: onTogglePublish,
            onRetryProcessing: onRetryProcessing,
          ),
        ],
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.video, required this.currency});

  final VideoWithStats video;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final duration = formatVideoDuration(video.duration) == null
        ? null
        : formatPlayerTime(Duration(seconds: video.duration));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GnVideoThumbnail(
          url: video.thumbnailUrl,
          width: 104,
          height: 66,
          durationLabel: duration,
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
                style: AppTextStyles.body.copyWith(
                  color: AppColors.text1,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 18 / 13.5,
                ),
              ),
              const SizedBox(height: 5),
              GnStatusPill(
                label: video.statusLabel,
                tone: videoStatusTone(video),
              ),
              const SizedBox(height: 6),
              Text(
                _metaLine(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text3,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// « 15 000 GNF · 1 240 vues · 8 500 GNF » : prix puis, pour une vidéo
  /// qui a pu être vue, vues et revenu.
  String _metaLine() {
    final parts = [videoPriceLabel(video.price, currency)];
    if (video.isReady || video.isBlocked) {
      parts.add(
        '${formatGrouped(video.viewCount)} '
        '${video.viewCount > 1 ? 'vues' : 'vue'}',
      );
      parts.add(formatMoney(video.revenue, currency: currency));
    }
    return parts.join(' · ');
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.video,
    required this.busy,
    required this.onTogglePublish,
    required this.onRetryProcessing,
  });

  final VideoWithStats video;
  final bool busy;
  final ValueChanged<bool> onTogglePublish;
  final VoidCallback onRetryProcessing;

  @override
  Widget build(BuildContext context) {
    if (video.canTogglePublish) {
      return _FooterFrame(
        child: Row(
          children: [
            Expanded(
              child: Text(
                video.isPublished
                    ? 'Visible dans le catalogue'
                    : 'Masquée du catalogue',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text2,
                  fontSize: 12,
                ),
              ),
            ),
            GnSwitch(
              compact: true,
              value: video.isPublished,
              loading: busy,
              onChanged: onTogglePublish,
              semanticLabel: 'Publier « ${video.title} » dans le catalogue',
            ),
          ],
        ),
      );
    }

    if (video.isFailed) {
      return _FooterFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GnBanner(
              tone: GnBannerTone.danger,
              message: 'Le traitement de la vidéo a échoué.',
            ),
            const SizedBox(height: 9),
            GnButton(
              label: 'Relancer le traitement',
              size: GnButtonSize.sm,
              isLoading: busy,
              onPressed: busy ? null : onRetryProcessing,
            ),
          ],
        ),
      );
    }

    final (icon, text, color) = switch (video.lifecycle) {
      VideoLifecycle.processing => (
        GnLineIconData.clock,
        'Traitement en cours. La liste se met à jour toute seule.',
        AppColors.warning,
      ),
      VideoLifecycle.blocked => (
        GnLineIconData.shield,
        'Cette vidéo est bloquée par la modération.',
        AppColors.danger,
      ),
      _ => (
        GnLineIconData.upload,
        'L’envoi de cette vidéo n’est pas terminé.',
        AppColors.text2,
      ),
    };
    return _FooterFrame(
      child: Row(
        children: [
          GnLineIcon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: color,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterFrame extends StatelessWidget {
  const _FooterFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ),
    );
  }
}
