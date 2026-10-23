import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Éléments internes partagés par [GnLoadingView], [GnErrorView] et
/// [GnEmptyView] (non exportés par `gn_design_system.dart`).
///
/// Disposition commune aux vues d'état : plein écran (centrée, avec marges
/// généreuses) ou [compact] (à l'intérieur d'une section, sans centrage
/// vertical ni expansion).
class GnStateLayout extends StatelessWidget {
  const GnStateLayout({
    super.key,
    required this.compact,
    required this.leading,
    required this.children,
  });

  final bool compact;
  final Widget leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.x4 : AppSpacing.x7,
        vertical: compact ? AppSpacing.x6 : AppSpacing.x7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [leading, ...children],
      ),
    );
    if (compact) return Center(child: content);
    return SizedBox.expand(
      child: Center(child: SingleChildScrollView(child: content)),
    );
  }
}

class GnStateIconTile extends StatelessWidget {
  const GnStateIconTile({
    super.key,
    required this.icon,
    required this.compact,
    this.color = AppColors.brand500,
  });

  final Widget icon;
  final bool compact;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 56.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brandTint18,
        borderRadius: BorderRadius.circular(
          compact ? AppRadii.md : AppRadii.lg,
        ),
      ),
      child: Center(
        child: IconTheme(
          data: IconThemeData(color: color, size: compact ? 20 : 24),
          child: icon,
        ),
      ),
    );
  }
}

Widget gnStateTitleAndMessage(String title, String? message) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: AppTextStyles.heading.copyWith(color: AppColors.text1),
      ),
      if (message != null && message.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.text3),
        ),
      ],
    ],
  );
}
