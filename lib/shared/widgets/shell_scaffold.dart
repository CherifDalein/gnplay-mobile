import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'design_system/gn_design_system.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    GnBottomNavItem(
      icon: GnLineIcon(GnLineIconData.home),
      activeIcon: GnLineIcon(GnLineIconData.home, color: AppColors.accent500),
      label: 'Accueil',
    ),
    GnBottomNavItem(
      icon: GnLineIcon(GnLineIconData.video),
      activeIcon: GnLineIcon(GnLineIconData.video, color: AppColors.accent500),
      label: 'Vidéos',
    ),
    GnBottomNavItem(
      icon: GnLineIcon(GnLineIconData.plus, color: AppColors.text1, size: 24),
      label: 'Publier',
      isFab: true,
    ),
    GnBottomNavItem(
      icon: GnLineIcon(GnLineIconData.wallet),
      activeIcon: GnLineIcon(GnLineIconData.wallet, color: AppColors.accent500),
      label: 'Gains',
    ),
    GnBottomNavItem(
      icon: GnLineIcon(GnLineIconData.user),
      activeIcon: GnLineIcon(GnLineIconData.user, color: AppColors.accent500),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: navigationShell,
      bottomNavigationBar: GnBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: _tabs,
      ),
    );
  }
}
