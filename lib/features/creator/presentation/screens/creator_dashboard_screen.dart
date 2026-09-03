import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../domain/creator_dashboard.dart';
import '../../domain/top_video.dart';
import '../providers/creator_dashboard_provider.dart';

class CreatorDashboardScreen extends ConsumerWidget {
  const CreatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(creatorDashboardProvider);
    final dashboard = dashboardState.valueOrNull ?? CreatorDashboard.sample();

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: RefreshIndicator(
            color: AppColors.accent500,
            backgroundColor: AppColors.surface1,
            onRefresh: () => ref.refresh(creatorDashboardProvider.future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _CreatorHeader(dashboard: dashboard),
                      const SizedBox(height: 20),
                      _BalanceCard(dashboard: dashboard),
                      const SizedBox(height: 14),
                      _StatsGrid(dashboard: dashboard),
                      const SizedBox(height: 24),
                      _TopVideosHeader(onTap: () => context.go('/videos')),
                      const SizedBox(height: 12),
                      ...dashboard.topVideos
                          .take(5)
                          .map(
                            (video) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TopVideoTile(video: video),
                            ),
                          ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreatorHeader extends StatelessWidget {
  const _CreatorHeader({required this.dashboard});

  final CreatorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final user = dashboard.user;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand800, AppColors.brand500],
            ),
          ),
          child: Text(
            user.initials,
            style: AppTextStyles.heading.copyWith(
              color: AppColors.text1,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.text1,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const GnStatusPill(label: 'CRÉATEUR', tone: GnStatusTone.brand),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            GnCard(
              padding: EdgeInsets.zero,
              radius: AppRadii.pill,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: GnLineIcon(
                    GnLineIconData.bell,
                    color: AppColors.text2,
                    size: 17,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.accent500,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgApp, width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.dashboard});

  final CreatorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -50,
            top: -50,
            child: SizedBox.square(
              dimension: 150,
              child: CustomPaint(painter: _DashedCirclePainter()),
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
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatMoney(
                        dashboard.withdrawableBalance,
                        withCurrency: false,
                      ),
                      style: AppTextStyles.displayLg.copyWith(
                        color: AppColors.accent300,
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GNF',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.accent300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text1.withValues(alpha: 0.6),
                  ),
                  children: [
                    TextSpan(
                      text:
                          'Solde du portefeuille : ${formatMoney(dashboard.walletBalance)} · ',
                    ),
                    TextSpan(
                      text:
                          '+${formatMoney(dashboard.analytics.revenueThisMonth, withCurrency: false)} ce mois-ci',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: () => context.go('/earnings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text1,
                    backgroundColor: AppColors.text1.withValues(alpha: 0.14),
                    side: BorderSide(
                      color: AppColors.text1.withValues(alpha: 0.25),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: Text(
                    'Retirer mes gains',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.text1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.dashboard});

  final CreatorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 11,
      crossAxisSpacing: 11,
      childAspectRatio: 1.55,
      children: [
        GnStatTile(
          icon: const GnLineIcon(
            GnLineIconData.video,
            color: AppColors.brand500,
            size: 15,
          ),
          value: '${dashboard.analytics.totalVideos}',
          label: 'Vidéos publiées',
        ),
        GnStatTile(
          icon: const GnLineIcon(
            GnLineIconData.eye,
            color: AppColors.brand500,
            size: 15,
          ),
          value: formatGrouped(dashboard.analytics.totalViews),
          label: 'Vues totales',
        ),
        GnStatTile(
          icon: const GnLineIcon(
            GnLineIconData.group,
            color: AppColors.brand500,
            size: 15,
          ),
          value: formatGrouped(dashboard.analytics.totalFollowers),
          label: 'Abonnés',
        ),
        GnStatTile(
          icon: const GnLineIcon(
            GnLineIconData.wallet,
            color: AppColors.brand500,
            size: 15,
          ),
          value: formatCompact(dashboard.analytics.revenueThisMonth),
          label: 'Revenu du mois',
        ),
      ],
    );
  }
}

class _TopVideosHeader extends StatelessWidget {
  const _TopVideosHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Vos vidéos les plus vues',
            style: AppTextStyles.heading.copyWith(color: AppColors.text1),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent500,
            textStyle: AppTextStyles.caption.copyWith(fontSize: 12),
            padding: EdgeInsets.zero,
          ),
          child: const Text('Tout voir'),
        ),
      ],
    );
  }
}

class _TopVideoTile extends StatelessWidget {
  const _TopVideoTile({required this.video});

  final TopVideo video;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      padding: EdgeInsets.zero,
      radius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/videos/${video.videoId}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: SizedBox(
                    width: 74,
                    height: 48,
                    child:
                        video.thumbnailUrl == null ||
                            video.thumbnailUrl!.isEmpty
                        ? const _ThumbnailPlaceholder()
                        : Image.network(video.thumbnailUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.text1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.text3,
                            fontSize: 11,
                          ),
                          children: [
                            TextSpan(
                              text: '${formatGrouped(video.viewCount)} vues · ',
                            ),
                            TextSpan(
                              text: formatMoney(video.revenue),
                              style: const TextStyle(color: AppColors.accent300),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const GnLineIcon(
                  GnLineIconData.chevronRight,
                  color: AppColors.text4,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: AppColors.brand950),
      child: CustomPaint(
        painter: _StripePainter(),
        child: Center(
          child: Text(
            'miniature',
            style: TextStyle(
              color: AppColors.text3,
              fontSize: 7.5,
              fontFamily: AppFonts.mono,
              letterSpacing: 0,
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

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = const Color(0xFF1A0C12);
    for (var x = -size.height; x < size.width; x += 12) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + 6, size.height)
        ..lineTo(x + size.height + 6, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, dark);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
