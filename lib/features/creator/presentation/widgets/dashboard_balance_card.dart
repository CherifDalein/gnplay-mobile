import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';

/// Carte « Solde retirable » du tableau de bord : montant retirable, solde du
/// portefeuille, revenu du mois et accès à la demande de retrait.
class DashboardBalanceCard extends StatelessWidget {
  const DashboardBalanceCard({
    super.key,
    required this.withdrawableBalance,
    required this.walletBalance,
    required this.revenueThisMonth,
    required this.currency,
    required this.onWithdraw,
  });

  final int withdrawableBalance;
  final int walletBalance;
  final int revenueThisMonth;
  final String currency;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(AppRadii.r18),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -30,
            top: -30,
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: 150,
                child: CustomPaint(painter: _DashedCirclePainter()),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SOLDE RETIRABLE',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text1.withValues(alpha: 0.7),
                  letterSpacing: 0.46,
                ),
              ),
              const SizedBox(height: 6),
              // Un gros montant rétrécit plutôt que de passer à la ligne.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatMoney(withdrawableBalance, withCurrency: false),
                      style: AppTextStyles.displayLg.copyWith(
                        color: AppColors.accent300,
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currency,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.accent300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text1.withValues(alpha: 0.6),
                  ),
                  children: [
                    TextSpan(
                      text:
                          'Solde du portefeuille : '
                          '${formatMoney(walletBalance, currency: currency)} · ',
                    ),
                    TextSpan(
                      text:
                          '+${formatMoney(revenueThisMonth, currency: currency)}'
                          ' ce mois-ci',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _WithdrawButton(onPressed: onWithdraw),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithdrawButton extends StatelessWidget {
  const _WithdrawButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.r10);
    return Semantics(
      button: true,
      label: 'Retirer mes gains',
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: AppColors.text1.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: AppColors.text1.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: ConstrainedBox(
            // 44 px : cible tactile minimale (la maquette dessine 40).
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Retirer mes gains',
                      style: AppTextStyles.display(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: AppColors.text1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.text1.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Offset.zero & size;
    const dashCount = 42;
    const gap = 0.08;
    for (var i = 0; i < dashCount; i++) {
      final start = i * 2 * math.pi / dashCount;
      canvas.drawArc(
        rect,
        start,
        (2 * math.pi / dashCount) - gap,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
