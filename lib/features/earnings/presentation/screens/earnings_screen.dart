import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/creator_dashboard.dart';
import '../../../creator/domain/wallet_ledger_entry.dart';
import '../../../creator/presentation/providers/creator_dashboard_provider.dart';
import '../../../creator/presentation/providers/creator_wallet_provider.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  bool _showTip = false;

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(creatorDashboardProvider);
    final ledgerState = ref.watch(creatorWalletLedgerProvider);
    final dashboard = dashboardState.valueOrNull ?? CreatorDashboard.sample();
    final ledger = ledgerState.valueOrNull;
    final entries = ledger == null || ledger.isEmpty
        ? WalletLedgerEntry.sample()
        : ledger;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: RefreshIndicator(
            color: AppColors.accent500,
            backgroundColor: AppColors.surface1,
            onRefresh: () async {
              ref.invalidate(creatorDashboardProvider);
              ref.invalidate(creatorWalletLedgerProvider);
              await Future.wait([
                ref.read(creatorDashboardProvider.future).catchError((_) {
                  return dashboard;
                }),
                ref.read(creatorWalletLedgerProvider.future).catchError((_) {
                  return entries;
                }),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
              children: [
                Text(
                  'Portefeuille',
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.text1,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 16),
                _BalanceCards(
                  dashboard: dashboard,
                  onInfoTap: () {
                    setState(() {
                      _showTip = !_showTip;
                    });
                  },
                ),
                if (_showTip) ...[
                  const SizedBox(height: 10),
                  GnCard(
                    radius: AppRadii.md,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    child: Text(
                      'Le solde retirable ne compte que vos gains de ventes. '
                      'Il peut être inférieur au portefeuille si vous avez '
                      'rechargé votre compte pour acheter des vidéos.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.text2,
                        height: 16 / 11,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GnButton(
                        label: 'Retirer mes gains',
                        onPressed: () => context.push('/payout'),
                      ),
                    ),
                    const SizedBox(width: 11),
                    GnButton(
                      label: 'Recharger',
                      variant: GnButtonVariant.ghost,
                      expand: false,
                      onPressed: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Historique',
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.text1,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                ...entries.map(
                  (entry) => _LedgerTile(
                    entry: entry,
                    onTap: entry.payoutId == null
                        ? null
                        : () => context.push('/payout/${entry.payoutId}'),
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

class _BalanceCards extends StatelessWidget {
  const _BalanceCards({required this.dashboard, required this.onInfoTap});

  final CreatorDashboard dashboard;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GnCard(
            child: _BalanceCardContent(
              label: 'PORTEFEUILLE',
              value: formatMoney(dashboard.walletBalance, withCurrency: false),
              caption: 'GNF · tout confondu',
              valueColor: AppColors.text1,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppGradients.brandSoft,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.brand500),
            ),
            child: _BalanceCardContent(
              label: 'RETIRABLE',
              value: formatMoney(
                dashboard.withdrawableBalance,
                withCurrency: false,
              ),
              caption: 'GNF · gains nets',
              valueColor: AppColors.accent300,
              trailing: InkWell(
                onTap: onInfoTap,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: GnLineIcon(
                    GnLineIconData.info,
                    color: AppColors.text2,
                    size: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCardContent extends StatelessWidget {
  const _BalanceCardContent({
    required this.label,
    required this.value,
    required this.caption,
    required this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final String caption;
  final Color valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.text3,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTextStyles.displayMd.copyWith(
              color: valueColor,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.micro.copyWith(
            color: AppColors.text3,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry, this.onTap});

  final WalletLedgerEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(entry);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surface1)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(11),
              ),
              child: GnLineIcon(
                entry.amount >= 0
                    ? GnLineIconData.arrowDown
                    : GnLineIconData.arrowUp,
                color: colors.foreground,
                size: 16,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.text1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.text3,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${entry.amount >= 0 ? '+' : '-'}${formatMoney(entry.amount.abs())}',
              style: AppTextStyles.label.copyWith(
                color: colors.foreground,
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _LedgerColors _colorsFor(WalletLedgerEntry entry) {
    return switch (entry.kind) {
      WalletLedgerKind.sale => const _LedgerColors(
        background: AppColors.successBg,
        foreground: AppColors.success,
      ),
      WalletLedgerKind.payout => const _LedgerColors(
        background: AppColors.dangerBg,
        foreground: AppColors.danger,
      ),
      WalletLedgerKind.topup => const _LedgerColors(
        background: AppColors.infoBg,
        foreground: AppColors.info,
      ),
      WalletLedgerKind.purchase => const _LedgerColors(
        background: AppColors.warningBg,
        foreground: AppColors.warning,
      ),
      WalletLedgerKind.neutral => const _LedgerColors(
        background: Color(0xFF22222A),
        foreground: AppColors.text2,
      ),
    };
  }
}

class _LedgerColors {
  const _LedgerColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
