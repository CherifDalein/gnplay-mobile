import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_card.dart';

class GnStatTile extends StatelessWidget {
  const GnStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.brandTint18,
                borderRadius: BorderRadius.circular(AppRadii.xs),
              ),
              child: Center(
                child: IconTheme(
                  data: const IconThemeData(
                    color: AppColors.accent500,
                    size: 16,
                  ),
                  child: icon!,
                ),
              ),
            ),
          if (icon != null) const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.displayMd.copyWith(
              color: AppColors.text1,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
        ],
      ),
    );
  }
}
