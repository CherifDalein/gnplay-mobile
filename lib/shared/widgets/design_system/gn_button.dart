import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum GnButtonVariant { primary, secondary, ghost, danger }

enum GnButtonSize { sm, md, lg }

class GnButton extends StatelessWidget {
  const GnButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GnButtonVariant.primary,
    this.size = GnButtonSize.md,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final GnButtonVariant variant;
  final GnButtonSize size;
  final bool isLoading;
  final Widget? icon;
  final bool expand;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final metrics = _metricsFor(size);
    final colors = _colorsFor(variant, _isDisabled);

    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: colors.foreground,
              ),
            )
          : Row(
              key: const ValueKey('content'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  IconTheme(
                    data: IconThemeData(color: colors.foreground, size: 18),
                    child: icon!,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: colors.foreground,
                      fontFamily: AppFonts.display,
                      fontSize: metrics.fontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
    );

    return SizedBox(
      height: metrics.height,
      width: expand ? double.infinity : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: colors.borderColor == null
              ? null
              : Border.all(color: colors.borderColor!),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.horizontal),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  _ButtonMetrics _metricsFor(GnButtonSize size) {
    return switch (size) {
      GnButtonSize.sm => const _ButtonMetrics(
        height: 40,
        fontSize: 12.5,
        horizontal: 14,
      ),
      GnButtonSize.md => const _ButtonMetrics(
        height: 52,
        fontSize: 15,
        horizontal: 18,
      ),
      GnButtonSize.lg => const _ButtonMetrics(
        height: 54,
        fontSize: 15,
        horizontal: 22,
      ),
    };
  }

  _ButtonColors _colorsFor(GnButtonVariant variant, bool disabled) {
    if (disabled) {
      return const _ButtonColors(
        background: AppColors.surface3,
        foreground: AppColors.text3,
      );
    }

    return switch (variant) {
      GnButtonVariant.primary => const _ButtonColors(
        background: AppColors.accent500,
        foreground: AppColors.textInverse,
      ),
      GnButtonVariant.secondary => const _ButtonColors(
        background: Colors.transparent,
        foreground: AppColors.text1,
        borderColor: AppColors.brand700,
      ),
      GnButtonVariant.ghost => const _ButtonColors(
        background: AppColors.surface1,
        foreground: AppColors.text1,
        borderColor: AppColors.border1,
      ),
      GnButtonVariant.danger => const _ButtonColors(
        background: Colors.transparent,
        foreground: AppColors.danger,
        borderColor: Color(0x59FF5A5F),
      ),
    };
  }
}

class _ButtonMetrics {
  const _ButtonMetrics({
    required this.height,
    required this.fontSize,
    required this.horizontal,
  });

  final double height;
  final double fontSize;
  final double horizontal;
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.borderColor,
  });

  final Color background;
  final Color foreground;
  final Color? borderColor;
}
