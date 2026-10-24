import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/become_creator_controller.dart';
import '../widgets/creator_content_widgets.dart' show friendlyErrorMessage;

class BecomeCreatorScreen extends ConsumerWidget {
  const BecomeCreatorScreen({super.key});

  Future<void> _confirmAndActivate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showGnConfirmSheet(
      context,
      title: 'Devenir créateur ?',
      message:
          'Cette action est définitive. Votre compte passera en mode créateur '
          ': vous pourrez publier des vidéos et retirer vos gains.',
      confirmLabel: 'Devenir créateur',
    );
    if (!confirmed || !context.mounted) return;

    final user = await ref
        .read(becomeCreatorControllerProvider.notifier)
        .becomeCreator();
    // Pas de navigation ici : le compte rechargé fait basculer le routeur
    // vers l'accueil. Le toast vit dans l'overlay racine et survit au
    // changement d'écran.
    if (user != null && context.mounted) {
      showGnToast(
        context,
        'Vous êtes créateur. Publiez votre première vidéo !',
        tone: GnToastTone.success,
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showGnConfirmSheet(
      context,
      title: 'Se déconnecter ?',
      message: 'Vous pourrez vous reconnecter à tout moment.',
      confirmLabel: 'Se déconnecter',
    );
    if (!confirmed) return;
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(becomeCreatorControllerProvider);
    final isLoading = state.isLoading;
    final errorMessage = state.whenOrNull(
      error: (error, _) => friendlyErrorMessage(error),
    );

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroPanel(onSettings: () => context.push('/settings')),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _CreatorBenefit(
                        number: '1',
                        title: 'Vendez vos vidéos',
                        subtitle: 'Fixez votre prix, ou publiez gratuitement.',
                      ),
                      const _CreatorBenefit(
                        number: '2',
                        title: 'Suivez vos statistiques',
                        subtitle: 'Vues, achats, taux de complétion par vidéo.',
                      ),
                      const _CreatorBenefit(
                        number: '3',
                        title: 'Retirez vos gains',
                        subtitle:
                            'Versement direct sur votre compte mobile money.',
                      ),
                      const SizedBox(height: 24),
                      if (errorMessage != null) ...[
                        GnBanner(
                          tone: GnBannerTone.danger,
                          title: 'Activation impossible',
                          message: errorMessage,
                        ),
                        const SizedBox(height: 14),
                      ],
                      GnButton(
                        label: errorMessage == null
                            ? 'Devenir créateur'
                            : 'Réessayer',
                        size: GnButtonSize.lg,
                        isLoading: isLoading,
                        onPressed: isLoading
                            ? null
                            : () => _confirmAndActivate(context, ref),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Cette action est définitive.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.text3,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Un spectateur n'a pas d'autre écran : il doit pouvoir
                      // quitter son compte d'ici.
                      Center(
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : () => _confirmLogout(context, ref),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.text2,
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            textStyle: AppTextStyles.label,
                          ),
                          child: const Text('Se déconnecter'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.brand),
        child: CustomPaint(
          painter: const _VerticalStripePainter(),
          child: Stack(
            children: [
              const Positioned(
                left: 26,
                top: 18,
                child: Row(
                  children: [
                    _StepBar(opacity: 0.85),
                    SizedBox(width: 5),
                    _StepBar(opacity: 0.55),
                    SizedBox(width: 5),
                    _StepBar(opacity: 0.3),
                  ],
                ),
              ),
              Positioned(
                right: 10,
                top: 4,
                child: Semantics(
                  button: true,
                  label: 'Réglages',
                  excludeSemantics: true,
                  onTap: onSettings,
                  child: InkResponse(
                    onTap: onSettings,
                    radius: 22,
                    child: const SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: GnLineIcon(
                          GnLineIconData.settings,
                          color: AppColors.text1,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 26,
                right: 26,
                bottom: 26,
                child: Text(
                  'Passez créateur\nsur GNPlay',
                  style: AppTextStyles.display(
                    color: AppColors.text1,
                    size: 32,
                    weight: FontWeight.w800,
                    height: 38 / 32,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.text1.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _CreatorBenefit extends StatelessWidget {
  const _CreatorBenefit({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surface1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent500.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: AppTextStyles.display(
                color: AppColors.accent500,
                size: 12,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text3,
                    fontSize: 12,
                    height: 17 / 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalStripePainter extends CustomPainter {
  const _VerticalStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.text1.withValues(alpha: 0.07);
    for (var x = 0.0; x < size.width; x += 16) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
