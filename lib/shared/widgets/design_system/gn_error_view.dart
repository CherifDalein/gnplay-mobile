import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_button.dart';
import 'gn_line_icon.dart';
import 'gn_state_layout.dart';

/// Vue d'erreur : icône, titre, message et bouton « Réessayer ».
///
/// Le bouton n'apparaît que si [onRetry] est fourni. Ne pas y passer
/// `error.toString()` brut : fournir un message lisible.
class GnErrorView extends StatelessWidget {
  const GnErrorView({
    super.key,
    this.title = 'Impossible de charger le contenu',
    this.message,
    this.onRetry,
    this.retryLabel = 'Réessayer',
    this.icon,
    this.compact = false,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  /// Icône personnalisée ; par défaut `wifiOff`.
  final Widget? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GnStateLayout(
      compact: compact,
      leading: GnStateIconTile(
        compact: compact,
        color: AppColors.danger,
        icon: icon ?? const GnLineIcon(GnLineIconData.wifiOff, size: 24),
      ),
      children: [
        const SizedBox(height: AppSpacing.x4),
        gnStateTitleAndMessage(title, message),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.x4),
          GnButton(
            label: retryLabel,
            onPressed: onRetry,
            variant: GnButtonVariant.ghost,
            size: GnButtonSize.sm,
            expand: false,
            icon: const GnLineIcon(
              GnLineIconData.refresh,
              size: 16,
              color: AppColors.text1,
            ),
          ),
        ],
      ],
    );
  }
}
