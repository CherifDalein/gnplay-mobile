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

class GnBottomNav extends StatelessWidget {
  const GnBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<GnBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        border: Border(top: BorderSide(color: AppColors.surface1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 86,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = index == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
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
              );
            }),
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.cta,
            boxShadow: [
              BoxShadow(
                color: AppColors.brand500.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: IconTheme(
              data: const IconThemeData(color: AppColors.text1, size: 24),
              child: item.icon,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 20,
      height: 20,
      child: IconTheme(
        data: IconThemeData(
          color: isActive ? AppColors.accent500 : AppColors.text3,
          size: 20,
        ),
        child: isActive ? (item.activeIcon ?? item.icon) : item.icon,
      ),
    );
  }
}
