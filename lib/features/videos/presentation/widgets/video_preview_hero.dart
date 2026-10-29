import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';
import '../providers/video_player_factory_provider.dart';

/// Avancement de la création de l'aperçu à la demande.
enum PreviewGenerationPhase {
  /// Rien en cours.
  idle,

  /// Demande envoyée au serveur.
  requesting,

  /// Génération lancée côté serveur : on relit la vidéo jusqu'à l'aperçu.
  waiting,

  /// Le serveur n'a pas produit d'aperçu dans le délai imparti.
  timedOut,
}

/// Zone d'aperçu en haut du détail d'une vidéo.
///
/// - avec un aperçu (`preview_url`) : lecture muette en boucle, bouton son,
///   erreurs de lecture gérées ;
/// - sans aperçu : miniature (ou repli) et « Aperçu pas encore disponible »,
///   sans bouton de lecture. Pour une vidéo prête, un bouton propose de le
///   générer ([onGenerate]).
class VideoPreviewHero extends ConsumerStatefulWidget {
  const VideoPreviewHero({
    super.key,
    required this.video,
    required this.onBack,
    this.generation = PreviewGenerationPhase.idle,
    this.generationMessage,
    this.onGenerate,
    this.height = 212,
  });

  final VideoWithStats video;
  final VoidCallback onBack;
  final PreviewGenerationPhase generation;

  /// Message d'erreur du serveur à afficher sous le libellé (ex. 409).
  final String? generationMessage;

  /// Lance la génération de l'aperçu ; `null` masque le bouton.
  final VoidCallback? onGenerate;
  final double height;

  @override
  ConsumerState<VideoPreviewHero> createState() => _VideoPreviewHeroState();
}

class _VideoPreviewHeroState extends ConsumerState<VideoPreviewHero> {
  VideoPlayerController? _controller;
  bool _started = false;
  bool _initializing = false;
  bool _failed = false;
  bool _muted = true;
  bool _userPaused = false;
  bool _screenVisible = true;
  ValueListenable<bool>? _visibility;
  // Invalide les `await` d'un contrôleur abandonné (nouvelle URL, relance).
  int _generation = 0;

  bool get _hasPreview => widget.video.hasPreview;

  @override
  void initState() {
    super.initState();
    if (_hasPreview) _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quand un écran (lecteur complet) recouvre le détail, l'aperçu se met
    // en pause ; il reprend au retour.
    final notifier = TickerMode.getNotifier(context);
    if (!identical(notifier, _visibility)) {
      _visibility?.removeListener(_onVisibilityChanged);
      _visibility = notifier..addListener(_onVisibilityChanged);
      _screenVisible = notifier.value;
    }
  }

  @override
  void didUpdateWidget(covariant VideoPreviewHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.previewUrl != widget.video.previewUrl) {
      _stop();
      if (_hasPreview) _start();
    }
  }

  @override
  void dispose() {
    _visibility?.removeListener(_onVisibilityChanged);
    _stop(notify: false);
    super.dispose();
  }

  void _onVisibilityChanged() {
    final visible = _visibility?.value ?? true;
    if (visible == _screenVisible) return;
    _screenVisible = visible;
    final controller = _controller;
    if (controller == null || !_started) return;
    if (!visible) {
      controller.pause();
    } else if (!_userPaused) {
      controller.play();
    }
  }

  void _stop({bool notify = true}) {
    _generation++;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onPlayerChanged);
      controller.dispose();
    }
    _started = false;
    _initializing = false;
    _failed = false;
    _userPaused = false;
    if (notify && mounted) setState(() {});
  }

  Future<void> _start() async {
    final generation = ++_generation;
    final url = widget.video.previewUrl!;
    final controller = ref.read(videoControllerFactoryProvider)(Uri.parse(url));
    _controller = controller;
    controller.addListener(_onPlayerChanged);
    setState(() {
      _initializing = true;
      _failed = false;
    });

    try {
      await controller.initialize();
      if (!mounted || generation != _generation) return;
      // Mémorisé localement : sous Linux, media_kit peut remonter une erreur
      // non fatale qui remet `controller.value` à zéro alors que la vidéo
      // continue de jouer ; on ne s'appuie donc pas sur `isInitialized`.
      _started = true;
      await controller.setLooping(true);
      if (!mounted || generation != _generation) return;
      await controller.setVolume(_muted ? 0 : 1);
      if (!mounted || generation != _generation) return;
      if (_screenVisible) await controller.play();
      if (!mounted || generation != _generation) return;
      setState(() => _initializing = false);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _initializing = false;
        _failed = true;
      });
    }
  }

  void _onPlayerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !_started) return;
    try {
      if (controller.value.isPlaying) {
        _userPaused = true;
        await controller.pause();
      } else {
        _userPaused = false;
        await controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null || !_started) return;
    final nextMuted = !_muted;
    try {
      await controller.setVolume(nextMuted ? 0 : 1);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _muted = nextMuted);
  }

  void _retry() {
    _stop(notify: false);
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final controller = _controller;
    final playing = _started && (controller?.value.isPlaying ?? false);
    final buffering =
        _started && !_failed && (controller?.value.isBuffering ?? false);
    final showPlayer = _hasPreview && _started && !_failed;

    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showPlayer)
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _aspectRatio(controller!),
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else
            GnVideoThumbnail(url: video.thumbnailUrl, label: ''),
          if (!showPlayer)
            ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
          if (showPlayer)
            // Toucher l'aperçu le met en pause ou le relance.
            Positioned.fill(
              child: Semantics(
                button: true,
                label: playing ? 'Mettre l’aperçu en pause' : 'Lire l’aperçu',
                child: GestureDetector(
                  key: const Key('preview-toggle'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _togglePlayback,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: playing || buffering ? 0 : 1,
                      duration: const Duration(milliseconds: 160),
                      child: const _CircleBadge(
                        size: 56,
                        child: GnLineIcon(
                          GnLineIconData.play,
                          size: 26,
                          color: AppColors.text1,
                          filled: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_hasPreview && _initializing)
            const Center(child: _Spinner())
          else if (buffering)
            const Center(child: _Spinner()),
          if (_hasPreview && _failed) _PreviewError(onRetry: _retry),
          if (!_hasPreview)
            _NoPreview(
              video: video,
              phase: widget.generation,
              message: widget.generationMessage,
              onGenerate: video.isReady ? widget.onGenerate : null,
            ),
          Positioned(
            top: 6,
            left: 8,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.overlay55,
                shape: BoxShape.circle,
              ),
              child: GnBackButton(
                color: AppColors.text1,
                onPressed: widget.onBack,
              ),
            ),
          ),
          if (_hasPreview)
            Positioned(
              top: 14,
              right: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.overlay60,
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
                    'Aperçu 15 s',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.text1,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
            ),
          if (showPlayer)
            Positioned(
              bottom: 6,
              right: 6,
              child: Semantics(
                button: true,
                label: _muted ? 'Activer le son' : 'Couper le son',
                excludeSemantics: true,
                onTap: _toggleMute,
                child: InkResponse(
                  key: const Key('preview-mute'),
                  onTap: _toggleMute,
                  radius: 24,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: _CircleBadge(
                        size: 30,
                        child: GnLineIcon(
                          _muted
                              ? GnLineIconData.volumeOff
                              : GnLineIconData.volume,
                          size: 16,
                          color: AppColors.text1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (showPlayer)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _PreviewProgress(controller: controller!),
            ),
        ],
      ),
    );
  }

  double _aspectRatio(VideoPlayerController controller) {
    final ratio = controller.value.aspectRatio;
    return ratio > 0 ? ratio : 16 / 9;
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const _CircleBadge(
      size: 48,
      child: SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: AppColors.accent500,
        ),
      ),
    );
  }
}

class _CircleBadge extends StatelessWidget {
  const _CircleBadge({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.overlay60,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// Fine barre de progression de l'aperçu (3 px, or).
class _PreviewProgress extends StatelessWidget {
  const _PreviewProgress({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final total = value.duration.inMilliseconds;
    final progress = total <= 0
        ? 0.0
        : (value.position.inMilliseconds / total).clamp(0.0, 1.0);
    return LinearProgressIndicator(
      value: progress,
      minHeight: 3,
      color: AppColors.accent500,
      backgroundColor: AppColors.border1,
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Impossible de lire l’aperçu.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.text1),
            ),
            const SizedBox(height: 8),
            GnButton(
              label: 'Réessayer',
              size: GnButtonSize.sm,
              expand: false,
              variant: GnButtonVariant.ghost,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Zone sans aperçu : libellé clair, jamais de bouton de lecture.
class _NoPreview extends StatelessWidget {
  const _NoPreview({
    required this.video,
    required this.phase,
    required this.message,
    required this.onGenerate,
  });

  final VideoWithStats video;
  final PreviewGenerationPhase phase;
  final String? message;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    final generating =
        phase == PreviewGenerationPhase.requesting ||
        phase == PreviewGenerationPhase.waiting;
    final timedOut = phase == PreviewGenerationPhase.timedOut;

    final title = generating
        ? 'Génération de l’aperçu…'
        : 'Aperçu pas encore disponible';
    final String? detail = generating
        ? 'Cela prend en général quelques dizaines de secondes.'
        : timedOut
        ? 'L’aperçu n’a pas pu être créé. Réessayez plus tard.'
        : message ?? _defaultDetail();

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (generating)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.accent500,
                  ),
                ),
              ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(color: AppColors.text1),
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: message != null && !generating && !timedOut
                      ? AppColors.danger
                      : AppColors.text2,
                  fontSize: 11.5,
                ),
              ),
            ],
            if (onGenerate != null && !generating) ...[
              const SizedBox(height: 10),
              GnButton(
                label: timedOut || message != null
                    ? 'Réessayer'
                    : 'Générer l’aperçu',
                size: GnButtonSize.sm,
                expand: false,
                variant: GnButtonVariant.ghost,
                onPressed: onGenerate,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _defaultDetail() {
    return switch (video.lifecycle) {
      VideoLifecycle.processing =>
        'Il sera créé une fois le traitement terminé.',
      VideoLifecycle.failed => 'Relancez le traitement pour le créer.',
      VideoLifecycle.uploading => 'Terminez d’abord l’envoi de la vidéo.',
      _ => null,
    };
  }
}
