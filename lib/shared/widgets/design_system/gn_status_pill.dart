import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum GnStatusTone { success, warning, danger, info, neutral, brand }

class GnStatusPill extends StatelessWidget {
  const GnStatusPill({
    super.key,
    required this.label,
    this.tone = GnStatusTone.neutral,
  });

  final String label;
  final GnStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: colors.foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.micro.copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StatusColors _colorsFor(GnStatusTone tone) {
    return switch (tone) {
      GnStatusTone.success => const _StatusColors(
        background: AppColors.successBg,
        foreground: AppColors.success,
      ),
      GnStatusTone.warning => const _StatusColors(
        background: AppColors.warningBg,
        foreground: AppColors.warning,
      ),
      GnStatusTone.danger => const _StatusColors(
        background: AppColors.dangerBg,
        foreground: AppColors.danger,
      ),
      GnStatusTone.info => const _StatusColors(
        background: AppColors.infoBg,
        foreground: AppColors.info,
      ),
      GnStatusTone.neutral => const _StatusColors(
        background: AppColors.surfaceNeutral,
        foreground: AppColors.text2,
      ),
      GnStatusTone.brand => const _StatusColors(
        background: AppColors.brandTint22,
        foreground: AppColors.accent300,
      ),
    };
  }
}

class _StatusColors {
  const _StatusColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
