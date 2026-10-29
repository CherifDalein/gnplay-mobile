import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_playback_access.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart'
    show friendlyErrorMessage;
import '../providers/video_player_factory_provider.dart';
import '../video_formatters.dart';

/// Lecture de la vidéo complète et protégée (session HLS avec filigrane),
/// ouverte à la demande depuis le détail vidéo.
///
/// - la session de lecture (`playback-session`) est créée à l'ouverture et
///   RECRÉÉE avant son expiration (2 h) ou sur « Réessayer » : la lecture
///   reprend alors à la position où elle s'était arrêtée ;
/// - `watch-progress` n'est jamais appelé : la lecture du créateur ne doit
///   pas gonfler ses propres vues ;
/// - l'orientation n'est pas verrouillée : la mise en page suit l'écran.
class FullVideoPlayerScreen extends ConsumerStatefulWidget {
  const FullVideoPlayerScreen({
    super.key,
    required this.videoId,
    required this.title,
    this.controlsHideDelay = const Duration(seconds: 3),
    this.renewMargin = const Duration(minutes: 1),
  });

  final String videoId;
  final String title;

  /// Délai avant que les contrôles se masquent pendant la lecture.
  final Duration controlsHideDelay;

  /// Avance sur l'expiration à laquelle la session est renouvelée.
  final Duration renewMargin;

  @override
  ConsumerState<FullVideoPlayerScreen> createState() =>
      _FullVideoPlayerScreenState();
}

class _FullVideoPlayerScreenState extends ConsumerState<FullVideoPlayerScreen> {
  VideoPlaybackAccess? _access;
  Object? _error;
  bool _loading = true;
  // Position et état à retrouver après un renouvellement de session.
  Duration? _resumeAt;
  bool _resumePlaying = true;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  /// Crée une session de lecture neuve. [keepPlayer] garde le lecteur affiché
  /// (en pause, avec un voile) pendant le renouvellement.
  Future<void> _loadSession({bool keepPlayer = false}) async {
    final id = ++_loadId;
    setState(() {
      _loading = true;
      _error = null;
      if (!keepPlayer) _access = null;
    });
    try {
      // `refresh` : une session déjà créée peut être périmée.
      final access = await ref.refresh(
        videoPlaybackAccessProvider(widget.videoId).future,
      );
      if (!mounted || id != _loadId) return;
      setState(() {
        _access = access;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || id != _loadId) return;
      setState(() {
        _access = null;
        _error = error;
        _loading = false;
      });
    }
  }

  void _renew(Duration position, bool wasPlaying) {
    if (_loading) return;
    _resumeAt = position;
    _resumePlaying = wasPlaying;
    _loadSession(keepPlayer: true);
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final access = _access;
    final Widget child;
    if (_error != null) {
      child = _MessageView(
        title: 'Lecture impossible',
        message: friendlyErrorMessage(_error!),
        onRetry: () => _loadSession(),
        onClose: _close,
      );
    } else if (access == null) {
      child = _MessageView(
        loadingLabel: 'Préparation de la lecture…',
        onClose: _close,
      );
    } else {
      child = _PlayerView(
        // Une nouvelle session (autre jeton) remplace entièrement le lecteur.
        key: ValueKey(access.url),
        access: access,
        title: widget.title,
        startAt: _resumeAt,
        startPlaying: _resumePlaying,
        renewing: _loading,
        hideDelay: widget.controlsHideDelay,
        renewMargin: widget.renewMargin,
        onRenew: _renew,
        onClose: _close,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: child),
    );
  }
}

/// Chargement de la session ou erreur, avec fermeture toujours possible.
class _MessageView extends StatelessWidget {
  const _MessageView({
    this.title,
    this.message,
    this.loadingLabel,
    this.onRetry,
    required this.onClose,
  });

  final String? title;
  final String? message;
  final String? loadingLabel;
  final VoidCallback? onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: loadingLabel != null
              ? GnLoadingView(message: loadingLabel)
              : GnErrorView(title: title!, message: message, onRetry: onRetry),
        ),
        Positioned(
          top: 4,
          left: 4,
          child: _RoundButton(
            label: 'Fermer',
            icon: GnLineIconData.close,
            onTap: onClose,
          ),
        ),
      ],
    );
  }
}

class _PlayerView extends ConsumerStatefulWidget {
  const _PlayerView({
    super.key,
    required this.access,
    required this.title,
    required this.startAt,
    required this.startPlaying,
    required this.renewing,
    required this.hideDelay,
    required this.renewMargin,
    required this.onRenew,
    required this.onClose,
  });

  final VideoPlaybackAccess access;
  final String title;
  final Duration? startAt;
  final bool startPlaying;
  final bool renewing;
  final Duration hideDelay;
  final Duration renewMargin;
  final void Function(Duration position, bool wasPlaying) onRenew;
  final VoidCallback onClose;

  @override
  ConsumerState<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<_PlayerView> {
  static const _watermarkPositions = [
    Alignment(-0.75, -0.7),
    Alignment(0.75, -0.7),
    Alignment(-0.75, 0.7),
    Alignment(0.75, 0.7),
  ];

  VideoPlayerController? _controller;
  // Mémorisé localement : sous Linux, media_kit peut remonter une erreur
  // non fatale (ex. échec du décodage matériel puis repli logiciel) que
  // video_player traduit par une remise à zéro de `controller.value`
  // (isInitialized=false, taille 0). La vidéo continue pourtant de jouer, donc
  // on ne s'appuie pas sur `value` pour savoir si le lecteur est prêt.
  bool _started = false;
  bool _initializing = true;
  bool _failed = false;
  bool _controlsVisible = true;
  bool _wasPlaying = false;
  Duration _lastPosition = Duration.zero;
  double? _dragMs;
  double _aspectRatio = 16 / 9;
  int _watermarkIndex = 0;
  Timer? _hideTimer;
  Timer? _renewTimer;
  Timer? _errorTimer;
  Timer? _watermarkTimer;

  String get _watermark => widget.access.watermark?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _scheduleRenewal();
    if (_watermark.isNotEmpty) {
      _watermarkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        setState(() {
          _watermarkIndex = (_watermarkIndex + 1) % _watermarkPositions.length;
        });
      });
    }
    _initializePlayer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _renewTimer?.cancel();
    _errorTimer?.cancel();
    _watermarkTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onChanged);
      controller.dispose();
    }
    super.dispose();
  }

  /// Renouvelle la session un peu avant son expiration : au-delà, chaque
  /// segment HLS serait refusé.
  void _scheduleRenewal() {
    final expiresAt = widget.access.expiresAt;
    if (expiresAt == null) return;
    var delay = expiresAt.difference(DateTime.now()) - widget.renewMargin;
    if (delay < const Duration(seconds: 5)) delay = const Duration(seconds: 5);
    _renewTimer = Timer(delay, _renewNow);
  }

  void _renewNow() {
    if (!mounted || widget.renewing) return;
    final controller = _controller;
    final playing = _started && (controller?.value.isPlaying ?? false);
    controller?.pause();
    widget.onRenew(_lastPosition, playing || _wasPlaying);
  }

  Future<void> _initializePlayer() async {
    // Le jeton de session est déjà encodé dans l'URL (?token=...) et propagé
    // à chaque sous-ressource par le backend : aucun en-tête requis.
    final controller = ref.read(videoControllerFactoryProvider)(
      Uri.parse(widget.access.url),
      formatHint: VideoFormat.hls,
    );
    _controller = controller;
    controller.addListener(_onChanged);

    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      final ratio = controller.value.aspectRatio;
      _aspectRatio = ratio > 0 ? ratio : 16 / 9;
      _started = true;
      final startAt = widget.startAt;
      if (startAt != null && startAt > Duration.zero) {
        _lastPosition = startAt;
        await controller.seekTo(startAt);
        if (!mounted || _controller != controller) return;
      }
      if (widget.startPlaying) {
        await controller.play();
        if (!mounted || _controller != controller) return;
      }
      setState(() => _initializing = false);
      _showControls();
    } catch (_) {
      if (!mounted || _controller != controller) return;
      setState(() {
        _initializing = false;
        _failed = true;
      });
    }
  }

  void _onChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;

    if (_started && !value.hasError && value.position > Duration.zero) {
      _lastPosition = value.position;
    }

    // Une erreur de lecture n'est retenue que si la vidéo ne repart pas :
    // certaines erreurs non fatales (media_kit sous Linux) sont suivies d'une
    // reprise immédiate.
    if (_started && value.hasError && !value.isPlaying) {
      _errorTimer ??= Timer(const Duration(seconds: 2), () {
        _errorTimer = null;
        final current = _controller?.value;
        if (mounted &&
            current != null &&
            current.hasError &&
            !current.isPlaying) {
          setState(() => _failed = true);
        }
      });
    } else {
      _errorTimer?.cancel();
      _errorTimer = null;
    }

    if (value.isPlaying != _wasPlaying) {
      _wasPlaying = value.isPlaying;
      if (_wasPlaying) {
        _scheduleHide();
      } else {
        _hideTimer?.cancel();
      }
    }
    setState(() {});
  }

  // --- Contrôles ---

  bool get _isEnded {
    final value = _controller?.value;
    return value != null &&
        _started &&
        value.duration > Duration.zero &&
        value.position >= value.duration;
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    final playing = _controller?.value.isPlaying ?? false;
    if (!playing) return;
    _hideTimer = Timer(widget.hideDelay, () {
      if (!mounted || _dragMs != null) return;
      if (_controller?.value.isPlaying ?? false) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      // On ne masque les contrôles que pendant la lecture.
      if (_controller?.value.isPlaying ?? false) {
        setState(() => _controlsVisible = false);
      } else {
        _scheduleHide();
      }
    } else {
      _showControls();
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !_started) return;
    try {
      if (_isEnded) {
        await controller.seekTo(Duration.zero);
        await controller.play();
      } else if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) _showControls();
  }

  Future<void> _seekTo(double milliseconds) async {
    final controller = _controller;
    if (controller == null || !_started) return;
    final target = Duration(milliseconds: milliseconds.round());
    try {
      await controller.seekTo(target);
    } catch (_) {
      // Sans effet : la barre reprend la position réelle.
    }
    if (!mounted) return;
    setState(() {
      _lastPosition = target;
      _dragMs = null;
    });
    _scheduleHide();
  }

  void _retry() {
    // Après une erreur, on reprend à la dernière position connue.
    widget.onRenew(_lastPosition, true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;
    final playing = _started && (value?.isPlaying ?? false);
    final buffering = _started && !_failed && (value?.isBuffering ?? false);
    final ended = _isEnded;
    // Les contrôles restent affichés tant que rien ne joue.
    final controlsOn =
        _controlsVisible || !playing || _failed || ended || _dragMs != null;
    final ready = _started && !_failed;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          Center(
            child: AspectRatio(
              aspectRatio: _aspectRatio,
              child: VideoPlayer(controller!),
            ),
          ),
        if (ready)
          Positioned.fill(
            child: GestureDetector(
              key: const Key('player-surface'),
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
            ),
          ),
        if (ready && _watermark.isNotEmpty)
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
                    key: const Key('player-watermark'),
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
        if (_initializing)
          const GnLoadingView(message: 'Chargement de la vidéo…'),
        if (buffering)
          const IgnorePointer(
            child: Center(
              child: SizedBox.square(
                dimension: 44,
                child: CircularProgressIndicator(
                  key: Key('player-buffering'),
                  strokeWidth: 3,
                  color: AppColors.accent500,
                ),
              ),
            ),
          ),
        if (ready)
          _Controls(
            visible: controlsOn,
            title: widget.title,
            playing: playing,
            ended: ended,
            position: Duration(
              milliseconds: (_dragMs ?? value!.position.inMilliseconds).round(),
            ),
            duration: value!.duration,
            bufferedEnd: value.buffered.isEmpty
                ? Duration.zero
                : value.buffered.last.end,
            onTogglePlayback: _togglePlayback,
            onClose: widget.onClose,
            onSeekStart: () => _hideTimer?.cancel(),
            onSeekUpdate: (ms) => setState(() => _dragMs = ms),
            onSeekEnd: _seekTo,
          )
        else
          Positioned(
            top: 4,
            left: 4,
            child: _RoundButton(
              label: 'Fermer',
              icon: GnLineIconData.close,
              onTap: widget.onClose,
            ),
          ),
        if (_failed)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.7),
              child: GnErrorView(
                title: 'La lecture a échoué',
                message:
                    'La vidéo n’a pas pu être lue (connexion perdue ou '
                    'session expirée).',
                onRetry: _retry,
              ),
            ),
          ),
        if (widget.renewing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.6),
              child: const GnLoadingView(message: 'Reprise de la lecture…'),
            ),
          ),
      ],
    );
  }
}

/// Contrôles superposés : fermeture et titre, lecture/pause, barre de
/// progression déplaçable avec temps écoulé et total.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.visible,
    required this.title,
    required this.playing,
    required this.ended,
    required this.position,
    required this.duration,
    required this.bufferedEnd,
    required this.onTogglePlayback,
    required this.onClose,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
  });

  final bool visible;
  final String title;
  final bool playing;
  final bool ended;
  final Duration position;
  final Duration duration;
  final Duration bufferedEnd;
  final VoidCallback onTogglePlayback;
  final VoidCallback onClose;
  final VoidCallback onSeekStart;
  final ValueChanged<double> onSeekUpdate;
  final ValueChanged<double> onSeekEnd;

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds.toDouble();
    final positionMs = position.inMilliseconds.toDouble().clamp(
      0,
      totalMs > 0 ? totalMs : 0,
    );
    final bufferedMs = bufferedEnd.inMilliseconds.toDouble().clamp(
      0,
      totalMs > 0 ? totalMs : 0,
    );

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          key: const Key('player-controls'),
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Voile décoratif : il ne doit pas intercepter les toucher, qui
              // servent à masquer les contrôles.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0, 0.25, 0.65, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                    child: Row(
                      children: [
                        _RoundButton(
                          label: 'Fermer',
                          icon: GnLineIconData.close,
                          onTap: onClose,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.text1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: ended
                            ? 'Revoir la vidéo'
                            : playing
                            ? 'Pause'
                            : 'Lecture',
                        excludeSemantics: true,
                        onTap: onTogglePlayback,
                        child: GestureDetector(
                          key: const Key('player-play-pause'),
                          onTap: onTogglePlayback,
                          child: Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.58),
                              shape: BoxShape.circle,
                            ),
                            child: GnLineIcon(
                              ended
                                  ? GnLineIconData.refresh
                                  : playing
                                  ? GnLineIconData.pause
                                  : GnLineIconData.play,
                              size: 30,
                              color: AppColors.text1,
                              filled: !ended,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(
                      children: [
                        Text(
                          formatPlayerTime(position),
                          key: const Key('player-elapsed'),
                          style: _timeStyle,
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              activeTrackColor: AppColors.accent500,
                              inactiveTrackColor: AppColors.border1,
                              secondaryActiveTrackColor: AppColors.text3,
                              thumbColor: AppColors.accent500,
                              overlayColor: AppColors.accent500.withValues(
                                alpha: 0.2,
                              ),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                            ),
                            child: Slider(
                              key: const Key('player-seek'),
                              value: positionMs.toDouble(),
                              secondaryTrackValue: bufferedMs.toDouble(),
                              min: 0,
                              max: totalMs > 0 ? totalMs : 1,
                              onChangeStart: totalMs > 0
                                  ? (_) => onSeekStart()
                                  : null,
                              onChanged: totalMs > 0 ? onSeekUpdate : null,
                              onChangeEnd: totalMs > 0 ? onSeekEnd : null,
                            ),
                          ),
                        ),
                        Text(
                          formatPlayerTime(duration),
                          key: const Key('player-total'),
                          style: _timeStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static final _timeStyle = AppTextStyles.caption.copyWith(
    color: AppColors.text1,
    fontSize: 12,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Bouton rond translucide de 44 px (zone tactile conforme).
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final GnLineIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.overlay55,
                shape: BoxShape.circle,
              ),
              child: GnLineIcon(
                icon,
                size: 18,
                color: AppColors.text1,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
