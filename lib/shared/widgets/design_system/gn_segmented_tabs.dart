import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Un onglet de [GnSegmentedTabs] : valeur, libellé et compteur optionnel.
class GnSegmentedTab<T> {
  const GnSegmentedTab({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// Petit compteur affiché à droite du libellé (ex. nombre de vidéos).
  final int? count;
}

/// Onglets segmentés de la maquette (« Vidéos / Séries ») : conteneur
/// `surface2` bordé, rayon 12, segment actif `brand600`.
///
/// ```dart
/// GnSegmentedTabs<String>(
///   tabs: const [
///     GnSegmentedTab(value: 'videos', label: 'Vidéos', count: 12),
///     GnSegmentedTab(value: 'series', label: 'Séries', count: 3),
///   ],
///   value: tab,
///   onChanged: (v) => setState(() => tab = v),
/// )
/// ```
class GnSegmentedTabs<T> extends StatelessWidget {
  const GnSegmentedTabs({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
  });

  final List<GnSegmentedTab<T>> tabs;

  /// Valeur de l'onglet sélectionné.
  final T value;

  /// Appelé avec la valeur de l'onglet touché (pas si c'est déjà l'onglet actif).
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border1),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _Segment<T>(
                tab: tabs[i],
                selected: tabs[i].value == value,
                onTap: () {
                  if (tabs[i].value != value) onChanged(tabs[i].value);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final GnSegmentedTab<T> tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.text1 : AppColors.fgMuted;

    // Zone tactile de 44 px ; le segment visible en fait 36 (marge de 4 px).
    return Semantics(
      button: true,
      selected: selected,
      label: tab.count == null ? tab.label : '${tab.label}, ${tab.count}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: selected ? AppColors.brand600 : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyText(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (tab.count != null) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0x40000000)
                            : AppColors.surfaceNeutral,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        '${tab.count}',
                        style: AppTextStyles.bodyText(
                          size: 10.5,
                          weight: FontWeight.w500,
                          color: selected ? AppColors.text1 : AppColors.text3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
