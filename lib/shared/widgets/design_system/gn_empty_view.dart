import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_button.dart';
import 'gn_line_icon.dart';
import 'gn_state_layout.dart';

/// Vue vide : icône, titre, texte et action optionnelle.
class GnEmptyView extends StatelessWidget {
  const GnEmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? message;

  /// Icône dans une tuile teintée (ex. `GnLineIcon(GnLineIconData.video)`).
  final Widget? icon;

  /// Libellé de l'action ; ignoré sans [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GnStateLayout(
      compact: compact,
      leading: GnStateIconTile(
        compact: compact,
        icon: icon ?? const GnLineIcon(GnLineIconData.video, size: 24),
      ),
      children: [
        const SizedBox(height: AppSpacing.x4),
        gnStateTitleAndMessage(title, message),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppSpacing.x4),
          GnButton(
            label: actionLabel!,
            onPressed: onAction,
            size: GnButtonSize.sm,
            expand: false,
          ),
        ],
      ],
    );
  }
}
