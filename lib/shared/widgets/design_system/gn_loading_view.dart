import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_state_layout.dart';

/// Vue de chargement : roue `accent500` et message optionnel.
///
/// Plein écran par défaut ; [compact] pour l'insérer dans une section.
class GnLoadingView extends StatelessWidget {
  const GnLoadingView({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spinnerSize = compact ? 22.0 : 30.0;
    return Semantics(
      container: true,
      liveRegion: true,
      label: message ?? 'Chargement',
      excludeSemantics: true,
      child: GnStateLayout(
        compact: compact,
        leading: SizedBox.square(
          dimension: spinnerSize,
          child: const CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.accent500,
          ),
        ),
        children: [
          if (message != null) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.text3),
            ),
          ],
        ],
      ),
    );
  }
}
