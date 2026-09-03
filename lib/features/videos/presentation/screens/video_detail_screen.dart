import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_analytics.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';
import 'full_video_player_screen.dart';

class VideoDetailScreen extends ConsumerWidget {
  const VideoDetailScreen({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(videoMutationControllerProvider, (
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
    final mutationState = ref.watch(videoMutationControllerProvider);
    final canWatchFull = !video.isProcessing && !video.isFailed;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _PreviewHero(video: video, onBack: () => _goBack(context)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    _TitleBlock(
                      video: video,
                      onEdit: () => _openEditSheet(context, video),
                    ),
                    const SizedBox(height: 18),
                    _MetricGrid(video: video, analytics: analytics),
                    const SizedBox(height: 14),
                    _CompletionCard(analytics: analytics),
                    const SizedBox(height: 14),
                    GnButton(
                      label: 'Voir la vidéo complète',
                      variant: GnButtonVariant.ghost,
                      icon: const GnLineIcon(
                        GnLineIconData.video,
                        color: AppColors.text1,
                        size: 17,
                      ),
                      onPressed: canWatchFull
                          ? () => _openFullPlayer(context, video)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    GnButton(
                      label: 'Voir les statistiques détaillées',
                      variant: GnButtonVariant.ghost,
                      icon: const GnLineIcon(
                        GnLineIconData.eye,
                        color: AppColors.text1,
                        size: 17,
                      ),
                      onPressed: () => context.go('/videos/${video.id}/stats'),
                    ),
                    const SizedBox(height: 20),
                    _PublishRow(
                      video: video,
                      isLoading: mutationState.isLoading,
                      onToggle: (value) {
                        ref
                            .read(videoMutationControllerProvider.notifier)
                            .setPublished(video, value);
                      },
                    ),
                    const SizedBox(height: 12),
                    GnButton(
                      label: 'Supprimer la vidéo',
                      variant: GnButtonVariant.danger,
                      onPressed: mutationState.isLoading
                          ? null
                          : () => _confirmDelete(context, ref, video),
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

  void _openEditSheet(BuildContext context, VideoWithStats video) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditVideoSheet(video: video),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    VideoWithStats video,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          title: Text(
            'Supprimer la vidéo',
            style: AppTextStyles.heading.copyWith(color: AppColors.text1),
          ),
          content: Text(
            video.title,
            style: AppTextStyles.body.copyWith(color: AppColors.text2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Supprimer',
                style: AppTextStyles.label.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(videoMutationControllerProvider.notifier)
        .deleteVideo(video.id);

    if (context.mounted &&
        !ref.read(videoMutationControllerProvider).hasError) {
      context.go('/videos');
    }
  }

  void _openFullPlayer(BuildContext context, VideoWithStats video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullVideoPlayerScreen(videoId: video.id, title: video.title),
        fullscreenDialog: true,
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

/// Lit `video.previewUrl` — l'aperçu de 15 s généré automatiquement après
/// transcodage, sur une URL publique (aucune session de lecture requise).
/// La vidéo complète (protégée) se regarde via [FullVideoPlayerScreen].
class _PreviewHero extends StatefulWidget {
  const _PreviewHero({required this.video, required this.onBack});

  final VideoWithStats video;
  final VoidCallback onBack;

  @override
  State<_PreviewHero> createState() => _PreviewHeroState();
}

class _PreviewHeroState extends State<_PreviewHero> {
  VideoPlayerController? _controller;
  bool _isInitializing = false;
  bool _isMuted = true;
  Object? _error;

  String? get _sourceUrl => widget.video.previewUrl;

  bool get _isReady {
    final controller = _controller;
    return controller != null && controller.value.isInitialized;
  }

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant _PreviewHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.previewUrl != widget.video.previewUrl) {
      _disposeController();
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    final sourceUrl = _sourceUrl;
    if (sourceUrl == null || sourceUrl.isEmpty) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _error = null;
    });

    final controller = VideoPlayerController.networkUrl(Uri.parse(sourceUrl));
    _controller = controller;
    controller.addListener(_onPlayerChanged);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0 : 1);
      await controller.play();
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _error = error;
        });
      }
    }
  }

  void _onPlayerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0 : 1);
    setState(() => _isMuted = nextMuted);
  }

  void _disposeController() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onPlayerChanged);
      controller.dispose();
    }
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isPlaying = controller?.value.isPlaying ?? false;
    final video = widget.video;
    final hasNoPreviewYet = (video.previewUrl ?? '').isEmpty;
    final hasError = _error != null && !_isReady;

    return SizedBox(
      height: 212,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isReady)
            Center(
              child: AspectRatio(
                aspectRatio: controller!.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          else
            GnVideoThumbnail(
              url: video.thumbnailUrl,
              label: hasError
                  ? 'aperçu indisponible'
                  : hasNoPreviewYet
                  ? (video.isProcessing
                        ? 'aperçu en cours de génération'
                        : 'aperçu indisponible')
                  : "lecture de l'aperçu 15 s",
            ),
          if (!_isReady)
            ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.38),
                ],
              ),
            ),
          ),
          Center(
            child: _PlayerCenterControl(
              isReady: _isReady,
              isInitializing: _isInitializing,
              hasError: hasError,
              isPlaying: isPlaying,
              onPressed: _togglePlayback,
              onRetry: () {
                _disposeController();
                _initializePlayer();
              },
            ),
          ),
          if (hasError)
            Positioned(
              left: 42,
              right: 42,
              bottom: 32,
              child: Text(
                'Impossible de lire l’aperçu de cette vidéo.',
                textAlign: TextAlign.center,
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.text2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Positioned(
            top: 12,
            left: 16,
            child: _RoundIconButton(
              icon: Icons.arrow_back,
              onPressed: widget.onBack,
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
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
                  'Aperçu 15 s',
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.text1,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ),
          ),
          if (_isReady)
            Positioned(
              bottom: 10,
              right: 12,
              child: _RoundIconButton(
                icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                onPressed: _toggleMute,
                size: 30,
              ),
            ),
          if (_isReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.accent500,
                  bufferedColor: AppColors.text3,
                  backgroundColor: AppColors.border1,
                ),
                padding: EdgeInsets.zero,
              ),
            )
          else
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GnProgressBar(value: 0, height: 3),
            ),
        ],
      ),
    );
  }
}

class _PlayerCenterControl extends StatelessWidget {
  const _PlayerCenterControl({
    required this.isReady,
    required this.isInitializing,
    required this.hasError,
    required this.isPlaying,
    required this.onPressed,
    required this.onRetry,
  });

  final bool isReady;
  final bool isInitializing;
  final bool hasError;
  final bool isPlaying;
  final VoidCallback onPressed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isInitializing) {
      return Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          shape: BoxShape.circle,
        ),
        child: const SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.accent500,
          ),
        ),
      );
    }

    if (hasError) {
      return TextButton.icon(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.text1,
          backgroundColor: Colors.black.withValues(alpha: 0.58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(
          'Réessayer',
          style: AppTextStyles.caption.copyWith(color: AppColors.text1),
        ),
      );
    }

    return GestureDetector(
      onTap: isReady ? onPressed : null,
      child: AnimatedOpacity(
        opacity: isPlaying ? 0 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.text1.withValues(alpha: 0.2)),
          ),
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow_rounded,
            color: AppColors.text1,
            size: 36,
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.video, required this.onEdit});

  final VideoWithStats video;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                style: AppTextStyles.title.copyWith(
                  color: AppColors.text1,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${video.statusLabel} · ${_priceLabel(video.price)} · publiée le ${_formatDate(video.createdAt)}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text3,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 38,
          child: GnButton(
            label: 'Modifier',
            variant: GnButtonVariant.ghost,
            size: GnButtonSize.sm,
            expand: false,
            onPressed: onEdit,
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.video, required this.analytics});

  final VideoWithStats video;
  final VideoAnalytics analytics;

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
        GnMetricTile(value: formatGrouped(analytics.views), label: 'Vues'),
        GnMetricTile(
          value: formatGrouped(analytics.uniqueViewers),
          label: 'Spectateurs',
        ),
        GnMetricTile(
          value: formatGrouped(analytics.purchasesCount),
          label: 'Achats',
        ),
        GnMetricTile(value: formatGrouped(video.likesCount), label: 'Likes'),
        GnMetricTile(
          value: formatMoney(analytics.revenue, withCurrency: false),
          label: 'Revenu GNF',
          valueColor: AppColors.accent300,
        ),
        GnMetricTile(
          value: formatDurationShort(video.duration),
          label: 'Durée',
        ),
      ],
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.analytics});

  final VideoAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final percent = analytics.completionPercent;

    return GnCard(
      radius: 13,
      padding: const EdgeInsets.all(13),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Taux de complétion moyen',
                  style: AppTextStyles.caption.copyWith(color: AppColors.text2),
                ),
              ),
              Text(
                '${percent.round()} %',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          GnProgressBar(value: percent / 100),
        ],
      ),
    );
  }
}

class _PublishRow extends StatelessWidget {
  const _PublishRow({
    required this.video,
    required this.isLoading,
    required this.onToggle,
  });

  final VideoWithStats video;
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
                  video.isPublished ? 'Vidéo publiée' : 'Publier cette vidéo',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.text1,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Visible dans le catalogue public',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text3,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GnContentSwitch(
            value: video.isPublished,
            isLoading: isLoading,
            onChanged: video.isProcessing || video.isFailed ? null : onToggle,
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 34,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.text1, size: size * 0.58),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.55),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _EditVideoSheet extends ConsumerStatefulWidget {
  const _EditVideoSheet({required this.video});

  final VideoWithStats video;

  @override
  ConsumerState<_EditVideoSheet> createState() => _EditVideoSheetState();
}

class _EditVideoSheetState extends ConsumerState<_EditVideoSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _thumbnailController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.video.title);
    _descriptionController = TextEditingController(
      text: widget.video.description ?? '',
    );
    _priceController = TextEditingController(text: '${widget.video.price}');
    _thumbnailController = TextEditingController(
      text: widget.video.thumbnailUrl ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoMutationControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: GnCard(
        backgroundColor: AppColors.surface2,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modifier la vidéo',
              style: AppTextStyles.heading.copyWith(color: AppColors.text1),
            ),
            const SizedBox(height: 14),
            GnTextField(controller: _titleController, label: 'Titre'),
            const SizedBox(height: 12),
            GnTextField(
              controller: _descriptionController,
              label: 'Description',
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            GnTextField(
              controller: _priceController,
              label: 'Prix GNF',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            GnTextField(
              controller: _thumbnailController,
              label: 'Miniature — URL',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            GnButton(
              label: 'Enregistrer',
              isLoading: state.isLoading,
              onPressed: state.isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      return;
    }

    await ref
        .read(videoMutationControllerProvider.notifier)
        .updateVideo(
          videoId: widget.video.id,
          title: title,
          description: _descriptionController.text.trim(),
          price: int.tryParse(_priceController.text) ?? 0,
          thumbnailUrl: _thumbnailController.text.trim(),
        );

    if (mounted && !ref.read(videoMutationControllerProvider).hasError) {
      Navigator.of(context).pop();
    }
  }
}

String _priceLabel(int price) {
  return price <= 0 ? 'Gratuite' : formatMoney(price);
}

String _formatDate(DateTime value) {
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  return '${value.day} ${months[value.month - 1]}';
}
