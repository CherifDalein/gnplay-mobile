import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_line_icon.dart';

/// Ton d'un [GnBanner].
enum GnBannerTone { info, warning, danger, success }

/// Bandeau d'information / avertissement / erreur / succès (rayon 12, fond et
/// bordure teintés), avec icône, titre et action optionnels.
///
/// ```dart
/// GnBanner(
///   tone: GnBannerTone.warning,
///   title: 'Limite atteinte',
///   message: 'Révoquez un appareil avant d'en connecter un nouveau.',
///   actionLabel: 'Gérer',
///   onAction: () {},
/// )
/// ```
class GnBanner extends StatelessWidget {
  const GnBanner({
    super.key,
    required this.message,
    this.tone = GnBannerTone.info,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final GnBannerTone tone;
  final String? title;

  /// Icône personnalisée ; par défaut une icône propre au ton.
  final Widget? icon;

  /// Libellé de l'action, affichée sous le texte. Ignorée sans [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(tone);
    final showAction = actionLabel != null && onAction != null;

    return Semantics(
      container: true,
      liveRegion: tone == GnBannerTone.danger,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: style.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child:
                    icon ??
                    GnLineIcon(style.icon, size: 16, color: style.foreground),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          title!,
                          style: AppTextStyles.bodyText(
                            size: 12,
                            weight: FontWeight.w700,
                            color: AppColors.text1,
                            height: 16 / 12,
                          ),
                        ),
                      ),
                    Text(
                      message,
                      style: AppTextStyles.bodyText(
                        size: 11.5,
                        color: style.messageColor,
                        height: 16 / 11.5,
                      ),
                    ),
                    if (showAction)
                      Semantics(
                        button: true,
                        label: actionLabel,
                        excludeSemantics: true,
                        onTap: onAction,
                        child: InkWell(
                          onTap: onAction,
                          borderRadius: BorderRadius.circular(AppRadii.xs),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: 1,
                              child: Text(
                                actionLabel!,
                                style: AppTextStyles.bodyText(
                                  size: 11.5,
                                  weight: FontWeight.w700,
                                  color: style.foreground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _BannerStyle _styleFor(GnBannerTone tone) {
    return switch (tone) {
      GnBannerTone.info => const _BannerStyle(
        background: AppColors.infoBannerBg,
        border: AppColors.infoBorder,
        foreground: AppColors.info,
        messageColor: AppColors.text2,
        icon: GnLineIconData.info,
      ),
      GnBannerTone.warning => const _BannerStyle(
        background: AppColors.warningBg,
        border: AppColors.warningBorder,
        foreground: AppColors.warning,
        messageColor: AppColors.warning,
        icon: GnLineIconData.alert,
      ),
      GnBannerTone.danger => const _BannerStyle(
        background: AppColors.dangerBg,
        border: AppColors.dangerBorder,
        foreground: AppColors.danger,
        messageColor: AppColors.danger,
        icon: GnLineIconData.error,
      ),
      GnBannerTone.success => const _BannerStyle(
        background: AppColors.successBg,
        border: AppColors.successBorder,
        foreground: AppColors.success,
        messageColor: AppColors.text2,
        icon: GnLineIconData.checkCircle,
      ),
    };
  }
}

class _BannerStyle {
  const _BannerStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.messageColor,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color messageColor;
  final GnLineIconData icon;
}
