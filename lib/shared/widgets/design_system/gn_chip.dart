import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_line_icon.dart';

/// Pastille de filtre (pill 12/600).
///
/// - Normale : fond `surface1`, bordure `border1`, texte `text2`.
/// - [selected] : fond `brand600`, bordure `brand500`, texte blanc.
/// - Avec [onDeleted] : chip « filtre actif » à fermer (fond teinté, croix).
///
/// Hauteur 36 px.
class GnChip extends StatelessWidget {
  const GnChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onDeleted,
    this.deleteSemanticLabel = 'Retirer le filtre',
  });

  final String label;
  final bool selected;

  /// Toucher la pastille ; `null` la désactive.
  final VoidCallback? onTap;

  /// Si fourni, affiche une croix et le style « filtre actif » ; la pastille
  /// entière appelle alors [onDeleted] (sauf si [onTap] est aussi fourni).
  final VoidCallback? onDeleted;

  final String deleteSemanticLabel;

  bool get _removable => onDeleted != null;

  @override
  Widget build(BuildContext context) {
    final active = selected || _removable;
    final enabled = (onTap ?? onDeleted) != null;

    final Color background;
    final Color border;
    final Color foreground;
    if (_removable) {
      background = AppColors.brandTint20;
      border = AppColors.brand500;
      foreground = AppColors.text1;
    } else if (selected) {
      background = AppColors.brand600;
      border = AppColors.brand500;
      foreground = AppColors.text1;
    } else {
      background = AppColors.surface1;
      border = AppColors.border1;
      foreground = AppColors.text2;
    }

    final callback = onTap ?? onDeleted;

    return Opacity(
      opacity: enabled || active ? 1 : 0.5,
      child: Semantics(
        button: true,
        selected: active,
        enabled: enabled,
        label: _removable ? '$label, $deleteSemanticLabel' : label,
        excludeSemantics: true,
        onTap: callback,
        child: Material(
          color: background,
          shape: StadiumBorder(side: BorderSide(color: border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: callback,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: EdgeInsets.only(left: 13, right: _removable ? 11 : 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyText(
                          size: 12,
                          weight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                    if (_removable) ...[
                      const SizedBox(width: 7),
                      GnLineIcon(
                        GnLineIconData.close,
                        size: 11,
                        color: AppColors.text1,
                        strokeWidth: 2.2,
                      ),
                    ],
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

/// Option d'un [GnChipGroup].
class GnChipOption<T> {
  const GnChipOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Groupe de [GnChip] à sélection unique, qui passe à la ligne si besoin.
///
/// ```dart
/// GnChipGroup<String>(
///   options: const [
///     GnChipOption(value: 'all', label: 'Toutes'),
///     GnChipOption(value: 'published', label: 'Publiées'),
///   ],
///   selected: filter,
///   onSelected: (v) => setState(() => filter = v),
/// )
/// ```
class GnChipGroup<T> extends StatelessWidget {
  const GnChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.spacing = AppSpacing.x2,
    this.runSpacing = AppSpacing.x2,
  });

  final List<GnChipOption<T>> options;

  /// Valeur sélectionnée (`null` : aucune).
  final T? selected;

  /// Appelé avec la valeur de la pastille touchée.
  final ValueChanged<T> onSelected;

  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final option in options)
          GnChip(
            label: option.label,
            selected: option.value == selected,
            onTap: () => onSelected(option.value),
          ),
      ],
    );
  }
}
