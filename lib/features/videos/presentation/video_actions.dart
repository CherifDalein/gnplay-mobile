import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/design_system/gn_design_system.dart';
import '../../creator/domain/video_with_stats.dart';
import '../../creator/presentation/providers/creator_content_provider.dart';
import '../../creator/presentation/widgets/creator_content_widgets.dart'
    show friendlyErrorMessage;

/// Publie ou masque [video] puis confirme (ou signale l'échec) par un toast.
/// Renvoie `true` si le serveur a accepté le changement.
Future<bool> toggleVideoPublished(
  BuildContext context,
  WidgetRef ref,
  VideoWithStats video,
  bool publish, {
  double toastOffset = 110,
}) async {
  final controller = ref.read(videoMutationControllerProvider.notifier);
  try {
    final done = await controller.setPublished(video, publish);
    if (done && context.mounted) {
      showGnToast(
        context,
        publish ? 'Vidéo publiée dans le catalogue.' : 'Vidéo masquée.',
        tone: GnToastTone.success,
        bottomOffset: toastOffset,
      );
    }
    return done;
  } catch (error) {
    if (context.mounted) {
      showGnToast(
        context,
        friendlyErrorMessage(error),
        tone: GnToastTone.error,
        bottomOffset: toastOffset,
      );
    }
    return false;
  }
}

/// Relance le traitement d'une vidéo en échec, avec un toast de résultat.
Future<bool> retryVideoProcessing(
  BuildContext context,
  WidgetRef ref,
  VideoWithStats video, {
  double toastOffset = 110,
}) async {
  final controller = ref.read(videoMutationControllerProvider.notifier);
  try {
    final done = await controller.retryTranscode(video.id);
    if (done && context.mounted) {
      showGnToast(
        context,
        'Traitement relancé. Cela peut prendre quelques minutes.',
        tone: GnToastTone.success,
        bottomOffset: toastOffset,
      );
    }
    return done;
  } catch (error) {
    if (context.mounted) {
      showGnToast(
        context,
        friendlyErrorMessage(error),
        tone: GnToastTone.error,
        bottomOffset: toastOffset,
      );
    }
    return false;
  }
}
