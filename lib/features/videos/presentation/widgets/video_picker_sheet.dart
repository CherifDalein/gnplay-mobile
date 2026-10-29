import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';
import '../video_display.dart';

/// Feuille « Choisir une vidéo » : renvoie l'identifiant de la vidéo choisie.
Future<String?> showVideoPickerSheet(
  BuildContext context, {
  required List<VideoWithStats> videos,
  required String selectedId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    elevation: 0,
    builder: (sheetContext) =>
        _VideoPickerSheet(videos: videos, selectedId: selectedId),
  );
}

class _VideoPickerSheet extends StatelessWidget {
  const _VideoPickerSheet({required this.videos, required this.selectedId});

  final List<VideoWithStats> videos;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface1,
          border: Border(top: BorderSide(color: AppColors.border1)),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border1,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choisir une vidéo',
                    style: AppTextStyles.sheetTitle.copyWith(
                      color: AppColors.text1,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  12 + media.padding.bottom,
                ),
                shrinkWrap: true,
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return _PickerRow(
                    video: video,
                    selected: video.id == selectedId,
                    onTap: () => Navigator.of(context).pop(video.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.video,
    required this.selected,
    required this.onTap,
  });

  final VideoWithStats video;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                GnVideoThumbnail(
                  url: video.thumbnailUrl,
                  width: 64,
                  height: 42,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      GnStatusPill(
                        label: video.statusLabel,
                        tone: videoStatusTone(video),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: GnLineIcon(
                      GnLineIconData.check,
                      size: 18,
                      color: AppColors.accent500,
                      strokeWidth: 2.2,
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
