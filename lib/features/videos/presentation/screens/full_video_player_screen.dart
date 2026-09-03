import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../creator/domain/video_playback_access.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';

/// Lecture de la vidéo complète et protégée (session HLS avec filigrane),
/// ouverte à la demande depuis le détail vidéo — jamais chargée
/// automatiquement, contrairement à l'aperçu 15 s de [VideoDetailScreen].
class FullVideoPlayerScreen extends ConsumerWidget {
  const FullVideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
  });

  final String videoId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(videoPlaybackAccessProvider(videoId));

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: access.when(
          data: (value) => _Player(access: value, title: title),
          loading: () => const _CenteredState(
            child: CircularProgressIndicator(color: AppColors.accent500),
          ),
          error: (error, stackTrace) => _CenteredState(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Impossible d’obtenir le lien de lecture sécurisé.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.text2),
                ),
                const SizedBox(height: 6),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: AppColors.text3),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(videoPlaybackAccessProvider(videoId)),
                  child: Text(
                    'Réessayer',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.accent500,
                    ),
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

class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
        Positioned(
          top: 8,
          left: 8,
          child: _CloseButton(onPressed: () => Navigator.of(context).pop()),
        ),
      ],
    );
  }
}

class _Player extends StatefulWidget {
  const _Player({required this.access, required this.title});

  final VideoPlaybackAccess access;
  final String title;

  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  static const _watermarkPositions = [
    Alignment(-0.75, -0.7),
    Alignment(0.75, -0.7),
    Alignment(-0.75, 0.7),
    Alignment(0.75, 0.7),
  ];

  VideoPlayerController? _controller;
  Timer? _watermarkTimer;
  int _watermarkIndex = 0;
  bool _isInitializing = true;
  Object? _error;

  String get _watermark => widget.access.watermark?.trim() ?? '';

  bool get _isReady {
    final controller = _controller;
    return controller != null && controller.value.isInitialized;
  }

  @override
  void initState() {
    super.initState();
    _syncWatermarkTimer();
    _initializePlayer();
  }

  @override
  void dispose() {
    _watermarkTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    // Le token de session est déjà encodé dans l'URL (?token=...) et propagé
    // à chaque sous-ressource par le backend : aucun en-tête requis.
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.access.url),
      formatHint: VideoFormat.hls,
    );
    _controller = controller;
    controller.addListener(_onChanged);

    try {
      await controller.initialize();
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

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _syncWatermarkTimer() {
    if (_watermark.isEmpty) {
      return;
    }
    _watermarkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _watermarkIndex = (_watermarkIndex + 1) % _watermarkPositions.length;
      });
    });
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

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isPlaying = controller?.value.isPlaying ?? false;
    final hasError = _error != null && !_isReady;

    return Stack(
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
        else if (_isInitializing)
          const Center(
            child: CircularProgressIndicator(color: AppColors.accent500),
          )
        else if (hasError)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'La lecture a échoué.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.text2),
              ),
            ),
          ),
        if (_isReady && _watermark.isNotEmpty)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AnimatedAlign(
                alignment: _watermarkPositions[_watermarkIndex],
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  child: Text(
                    _watermark,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.text1.withValues(alpha: 0.2),
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_isReady)
          Center(
            child: AnimatedOpacity(
              opacity: isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: GestureDetector(
                onTap: _togglePlayback,
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                    color: AppColors.text1,
                    size: 36,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: _CloseButton(onPressed: () => Navigator.of(context).pop()),
        ),
        Positioned(
          top: 12,
          left: 56,
          right: 16,
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.copyWith(color: AppColors.text1),
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
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.close, color: AppColors.text1),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
