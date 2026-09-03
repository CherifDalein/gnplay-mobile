import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final bool _dark = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
            children: [
              _Header(onBack: () => _goBack(context)),
              const SizedBox(height: 22),
              _SectionLabel('SÉCURITÉ'),
              const SizedBox(height: 9),
              GnCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Row(
                      label: 'Changer le mot de passe',
                      onTap: isBusy
                          ? null
                          : () => context.go('/forgot-password'),
                    ),
                    const Divider(height: 1, color: AppColors.border2),
                    _Row(
                      label: 'Se déconnecter de cet appareil',
                      onTap: isBusy ? null : () => _logoutThisDevice(context),
                    ),
                    const Divider(height: 1, color: AppColors.border2),
                    _Row(
                      label: 'Se déconnecter de tous les appareils',
                      labelColor: AppColors.danger,
                      onTap: isBusy ? null : () => _confirmLogoutAll(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel('PRÉFÉRENCES'),
              const SizedBox(height: 9),
              GnCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode sombre',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.text1,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Recommandé pour la vidéo',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.text3,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GnContentSwitch(
                      value: _dark,
                      onChanged: (_) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surface3,
                            content: Text(
                              'Le mode clair arrive dans une prochaine version.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.text1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel('À PROPOS'),
              const SizedBox(height: 9),
              GnCard(
                child: Text(
                  'GNPlay Créateur · version 1.0.0\nConditions générales · Mentions légales',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text3,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logoutThisDevice(BuildContext context) async {
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) {
      context.go('/login');
    }
  }

  Future<void> _confirmLogoutAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        title: Text(
          'Déconnexion de tous les appareils',
          style: AppTextStyles.heading.copyWith(color: AppColors.text1),
        ),
        content: Text(
          'Toutes vos sessions actives seront révoquées, y compris celle-ci.',
          style: AppTextStyles.body.copyWith(color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Déconnecter',
              style: AppTextStyles.label.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(authControllerProvider.notifier).logoutAllDevices();
    if (context.mounted) {
      context.go('/login');
    }
  }

  void _goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/profile');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.text2, size: 20),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Réglages & sécurité',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.text1,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.micro.copyWith(
        color: AppColors.text3,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.onTap, this.labelColor});

  final String label;
  final VoidCallback? onTap;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: labelColor ?? AppColors.text1,
                  fontSize: 13.5,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.text4, size: 18),
          ],
        ),
      ),
    );
  }
}
