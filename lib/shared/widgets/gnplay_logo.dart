import 'package:flutter/material.dart';

class GnplayLogo extends StatelessWidget {
  const GnplayLogo({super.key, this.height = 100});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/LOGO_TRANSPARENT.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
