import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../domain/creator_analytics.dart';

/// Grille 2×2 des chiffres clés du créateur.
///
/// Les tuiles ont la hauteur de leur contenu (pas de ratio fixe) : avec une
/// police agrandie ou un libellé qui passe sur deux lignes, rien ne déborde.
class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({super.key, required this.analytics});

  final CreatorAnalytics analytics;

  static const double _gap = 11;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(
          _StatCard(
            icon: GnLineIconData.video,
            // `total_videos` compte toutes les vidéos du créateur (brouillons,
            // en traitement, échecs…), pas seulement les publiées.
            label: 'Vidéos',
            value: formatGrouped(analytics.totalVideos),
          ),
          _StatCard(
            icon: GnLineIconData.eye,
            label: 'Vues totales',
            value: formatGrouped(analytics.totalViews),
          ),
        ),
        const SizedBox(height: _gap),
        _row(
          _StatCard(
            icon: GnLineIconData.group,
            label: 'Abonnés',
            value: formatGrouped(analytics.totalFollowers),
          ),
          _StatCard(
            icon: GnLineIconData.coins,
            label: 'Revenu du mois',
            value: formatCompact(analytics.revenueThisMonth),
          ),
        ),
      ],
    );
  }

  Widget _row(Widget left, Widget right) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: _gap),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final GnLineIconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label : $value',
      excludeSemantics: true,
      child: GnCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.brandTint18,
                borderRadius: BorderRadius.circular(AppRadii.xs),
              ),
              child: Center(
                child: GnLineIcon(icon, color: AppColors.accent500, size: 15),
              ),
            ),
            const SizedBox(height: 10),
            // Un grand nombre rétrécit au lieu d'être coupé.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppTextStyles.displayMd.copyWith(
                  color: AppColors.text1,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}
