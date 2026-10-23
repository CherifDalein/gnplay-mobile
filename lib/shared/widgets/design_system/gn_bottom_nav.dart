import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class GnBottomNavItem {
  const GnBottomNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.isFab = false,
  });

  final String label;
  final Widget icon;
  final Widget? activeIcon;
  final bool isFab;
}

/// Barre de navigation basse (maquette `BottomNav.jsx`).
///
/// Hauteur 86 (la zone de l'indicateur système est comprise dans ces 86 ;
/// elle ne s'y ajoute que si elle est plus grande que ce qui reste sous les
/// libellés), fond translucide avec flou 14, icônes 22 px, libellés 9.5.
/// Les icônes fournies sont redimensionnées à 22 px quelle que soit leur taille.
class GnBottomNav extends StatelessWidget {
  const GnBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  /// Hauteur de la barre sans zone système.
  static const double height = 86;

  /// Hauteur minimale nécessaire au contenu (marge haute + icône + libellé).
  static const double _contentHeight = 62;

  final List<GnBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final totalHeight = math.max(height, _contentHeight + inset);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.navBg,
            border: Border(top: BorderSide(color: AppColors.navBorder)),
          ),
          child: SizedBox(
            height: totalHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isActive = index == currentIndex;

                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: isActive,
                      label: item.label,
                      excludeSemantics: true,
                      onTap: () => onTap(index),
                      child: InkWell(
                        onTap: () => onTap(index),
                        // Pas d'effet d'ondulation dans la maquette.
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 11),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _BottomNavIcon(item: item, isActive: isActive),
                              const SizedBox(height: 6),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.micro.copyWith(
                                  color: isActive
                                      ? AppColors.accent500
                                      : AppColors.text3,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavIcon extends StatelessWidget {
  const _BottomNavIcon({required this.item, required this.isActive});

  final GnBottomNavItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (item.isFab) {
      return Transform.translate(
        offset: const Offset(0, -16),
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.ctaFab,
            boxShadow: AppShadows.fab,
          ),
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: FittedBox(
                child: IconTheme(
                  data: const IconThemeData(color: AppColors.text1, size: 22),
                  child: item.icon,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox.square(
      dimension: 22,
      child: FittedBox(
        child: IconTheme(
          data: IconThemeData(
            color: isActive ? AppColors.accent500 : AppColors.text3,
            size: 22,
          ),
          child: isActive ? (item.activeIcon ?? item.icon) : item.icon,
        ),
      ),
    );
  }
}
