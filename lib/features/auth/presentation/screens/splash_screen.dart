import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/gnplay_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GnplayLogo(height: 96),
            SizedBox(height: 28),
            CircularProgressIndicator(color: AppColors.accent500),
          ],
        ),
      ),
    );
  }
}
