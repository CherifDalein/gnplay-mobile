import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/creator_dashboard.dart';
import '../../../creator/domain/wallet_ledger_entry.dart';
import '../../../creator/presentation/providers/creator_dashboard_provider.dart';
import '../../../creator/presentation/providers/creator_wallet_provider.dart';
import '../../../creator/presentation/providers/payout_controller.dart';

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
                        onPressed: () => _openPayoutSheet(context, dashboard),
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
                ...entries.map((entry) => _LedgerTile(entry: entry)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPayoutSheet(BuildContext context, CreatorDashboard dashboard) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => _PayoutSheet(dashboard: dashboard),
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
  const _LedgerTile({required this.entry});

  final WalletLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(entry);

    return Container(
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

class _PayoutSheet extends ConsumerStatefulWidget {
  const _PayoutSheet({required this.dashboard});

  final CreatorDashboard dashboard;

  @override
  ConsumerState<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends ConsumerState<_PayoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _operatorController = TextEditingController(
    text: 'orange_money_gn_payout',
  );
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.dashboard.withdrawableBalance.toString();
    _phoneController.text = widget.dashboard.user.phoneNumber;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _operatorController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payoutState = ref.watch(payoutControllerProvider);
    final isLoading = payoutState.isLoading;
    final errorMessage = payoutState.whenOrNull(
      error: (error, _) => error is ApiException
          ? error.message
          : 'La demande de retrait a échoué.',
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Retirer mes gains',
                    style: AppTextStyles.heading.copyWith(
                      color: AppColors.text1,
                      fontSize: 17,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Fermer',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.text2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GnCard(
              radius: 14,
              child: Row(
                children: [
                  Text(
                    'Solde retirable',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.text3,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatMoney(widget.dashboard.withdrawableBalance),
                    style: AppTextStyles.heading.copyWith(
                      color: AppColors.accent300,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GnTextField(
              controller: _amountController,
              label: 'Montant',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            GnTextField(controller: _operatorController, label: 'Opérateur'),
            const SizedBox(height: 12),
            GnTextField(
              controller: _phoneController,
              label: 'Téléphone de destination',
              keyboardType: TextInputType.phone,
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 16),
            GnButton(
              label: 'Confirmer le retrait',
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = int.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un montant valide.')),
      );
      return;
    }
    final ok = await ref
        .read(payoutControllerProvider.notifier)
        .requestPayout(
          amount: amount,
          operator: _operatorController.text.trim(),
          destinationPhone: _phoneController.text,
        );
    if (!mounted || !ok) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demande de retrait envoyée.')),
    );
  }
}

class _LedgerColors {
  const _LedgerColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}
