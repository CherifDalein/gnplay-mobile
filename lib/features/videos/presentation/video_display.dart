import '../../../shared/utils/gn_formatters.dart';
import '../../../shared/widgets/design_system/gn_design_system.dart';
import '../../creator/domain/video_with_stats.dart';

/// Couleur de la pastille de statut d'une vidéo.
GnStatusTone videoStatusTone(VideoWithStats video) {
  return switch (video.lifecycle) {
    VideoLifecycle.online => GnStatusTone.success,
    VideoLifecycle.hidden => GnStatusTone.neutral,
    VideoLifecycle.processing ||
    VideoLifecycle.uploading => GnStatusTone.warning,
    VideoLifecycle.failed ||
    VideoLifecycle.blocked ||
    VideoLifecycle.deleted => GnStatusTone.danger,
  };
}

/// « Gratuite » ou le prix dans la devise du compte.
String videoPriceLabel(int price, String currency) {
  return price <= 0 ? 'Gratuite' : formatMoney(price, currency: currency);
}
