import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';

/// Cloche de notifications avec le nombre de non lues.
///
/// Zone tactile de 44 px (le rond dessiné en fait 40, comme la maquette) ;
/// le lecteur d'écran annonce « Notifications, N non lues » plutôt que le
/// chiffre seul du badge.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  /// Taille de la zone tactile.
  static const double hitSize = 44;

  /// Au-delà, le badge affiche « 99+ » pour rester dans son cercle.
  static const int _badgeMax = 99;

  final int unreadCount;
  final VoidCallback onPressed;

  String get _semanticLabel {
    if (unreadCount <= 0) return 'Notifications';
    final unread = unreadCount == 1 ? 'non lue' : 'non lues';
    return 'Notifications, $unreadCount $unread';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _semanticLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: hitSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Material(
                color: AppColors.surface1,
                shape: const CircleBorder(
                  side: BorderSide(color: AppColors.border1),
                ),
                child: InkResponse(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  radius: hitSize / 2,
                  child: const SizedBox.square(
                    dimension: 40,
                    child: Center(
                      child: GnLineIcon(
                        GnLineIconData.bell,
                        color: AppColors.text2,
                        size: 17,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: IgnorePointer(child: _Badge(count: unreadCount)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > NotificationBell._badgeMax
        ? '${NotificationBell._badgeMax}+'
        : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent500,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.bgApp, width: 2),
      ),
      child: Text(
        label,
        style: AppTextStyles.micro.copyWith(
          color: AppColors.textInverse,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}
