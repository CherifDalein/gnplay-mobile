import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Crée le contrôleur de lecture d'une URL (HLS pour la vidéo complète, MP4
/// pour l'aperçu).
typedef VideoControllerFactory =
    VideoPlayerController Function(Uri url, {VideoFormat? formatHint});

/// Fabrique des contrôleurs vidéo. Les écrans ne construisent jamais un
/// `VideoPlayerController` eux-mêmes : les tests remplacent cette fabrique par
/// un contrôleur factice, car la lecture réelle exige une plateforme native.
final videoControllerFactoryProvider = Provider<VideoControllerFactory>(
  (ref) =>
      (url, {formatHint}) =>
          VideoPlayerController.networkUrl(url, formatHint: formatHint),
);
