import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class GnAppBackground extends StatelessWidget {
  const GnAppBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.appBackground),
      child: Padding(padding: padding, child: child),
    );
  }
}
