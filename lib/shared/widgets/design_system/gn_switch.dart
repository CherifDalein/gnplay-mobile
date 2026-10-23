import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Interrupteur de la maquette (`ToggleSwitch.jsx`) : piste `brand600` quand
/// il est actif, `border1` sinon, pastille blanche, transition de 180 ms.
///
/// - Taille normale 46x26 (bouton 20) ; [compact] : 44x25 (bouton 19), pour
///   les cartes de liste.
/// - Zone tactile d'au moins 44 px de haut.
/// - [onChanged] `null` ou [loading] : désactivé.
class GnSwitch extends StatelessWidget {
  const GnSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.loading = false,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool compact;

  /// Affiche une petite roue de chargement dans la pastille et bloque le toucher.
  final bool loading;

  /// Libellé lu par les lecteurs d'écran (ex. « Publiée »).
  final String? semanticLabel;

  bool get _enabled => onChanged != null && !loading;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 44.0 : 46.0;
    final height = compact ? 25.0 : 26.0;
    final knob = compact ? 19.0 : 20.0;
    const inset = 3.0;

    final trackColor = loading
        ? AppColors.surface3
        : (value ? AppColors.brand600 : AppColors.border1);

    return Semantics(
      toggled: value,
      enabled: _enabled,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: _enabled ? () => onChanged!(!value) : null,
      child: Opacity(
        opacity: onChanged == null ? 0.5 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? () => onChanged!(!value) : null,
          child: SizedBox(
            width: width,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 180),
                      top: (height - knob) / 2,
                      left: value ? width - knob - inset : inset,
                      child: Container(
                        width: knob,
                        height: knob,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: loading
                            ? const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.6,
                                  color: AppColors.brand600,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
