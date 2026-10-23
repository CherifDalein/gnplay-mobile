import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Ton d'un [GnToast] : détermine la couleur du point.
enum GnToastTone { info, success, error }

/// Toast de la maquette : surface `surface3`, bordure `border1`, rayon 14,
/// point de 8 px, ombre « card ».
///
/// C'est la partie visuelle ; pour l'afficher au-dessus de l'écran courant,
/// utiliser [showGnToast].
class GnToast extends StatelessWidget {
  const GnToast({
    super.key,
    required this.message,
    this.tone = GnToastTone.info,
  });

  final String message;
  final GnToastTone tone;

  static Color dotColorFor(GnToastTone tone) {
    return switch (tone) {
      GnToastTone.info => AppColors.info,
      GnToastTone.success => AppColors.success,
      GnToastTone.error => AppColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(AppRadii.r14),
          border: Border.all(color: AppColors.border1),
          boxShadow: AppShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColorFor(tone),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyText(
                    size: 12.5,
                    color: AppColors.text1,
                    height: 17 / 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

OverlayEntry? _currentToast;

/// Ferme immédiatement le toast affiché, s'il y en a un.
void hideGnToast() {
  final entry = _currentToast;
  _currentToast = null;
  if (entry != null && entry.mounted) entry.remove();
}

/// Affiche un [GnToast] au-dessus de l'écran courant (et de la barre
/// d'onglets), puis le masque après [duration].
///
/// Un seul toast à la fois : un nouvel appel remplace le précédent. Le toast
/// vit dans l'`Overlay` racine, il survit donc à la fermeture de l'écran qui
/// l'a émis. [bottomOffset] est la distance au bord bas de l'écran (110 px,
/// au-dessus de la barre de 86 px) ; elle augmente automatiquement quand la
/// zone système basse est plus grande que celle prévue dans la barre.
void showGnToast(
  BuildContext context,
  String message, {
  GnToastTone tone = GnToastTone.info,
  Duration duration = const Duration(milliseconds: 2600),
  double bottomOffset = 110,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  hideGnToast();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) {
      final inset = MediaQuery.paddingOf(overlayContext).bottom;
      return Positioned(
        left: AppSpacing.x5,
        right: AppSpacing.x5,
        bottom: math.max(bottomOffset, bottomOffset - 24 + inset),
        child: _ToastTransition(
          duration: duration,
          onDismissed: () {
            if (identical(_currentToast, entry)) _currentToast = null;
            if (entry.mounted) entry.remove();
          },
          child: IgnorePointer(
            child: GnToast(message: message, tone: tone),
          ),
        ),
      );
    },
  );
  _currentToast = entry;
  overlay.insert(entry);
}

/// Apparition (fondu + léger glissement vers le haut), maintien, disparition.
class _ToastTransition extends StatefulWidget {
  const _ToastTransition({
    required this.child,
    required this.duration,
    required this.onDismissed,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_ToastTransition> createState() => _ToastTransitionState();
}

class _ToastTransitionState extends State<_ToastTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
