import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/payout_request.dart';
import '../../../creator/presentation/providers/payout_providers.dart';

class PayoutDetailScreen extends ConsumerStatefulWidget {
  const PayoutDetailScreen({super.key, required this.payoutId});

  final String payoutId;

  @override
  ConsumerState<PayoutDetailScreen> createState() => _PayoutDetailScreenState();
}

class _PayoutDetailScreenState extends ConsumerState<PayoutDetailScreen> {
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _schedulePollIfPending(PayoutRequestRecord record) {
    _pollTimer?.cancel();
    if (!record.status.isPending) {
      return;
    }
    _pollTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        ref.invalidate(payoutDetailProvider(widget.payoutId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final payoutState = ref.watch(payoutDetailProvider(widget.payoutId));

    payoutState.whenData(_schedulePollIfPending);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            children: [
              _Header(onBack: () => _goBack(context)),
              const SizedBox(height: 10),
              payoutState.when(
                data: (record) => _Content(record: record),
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent500),
                  ),
                ),
                error: (error, stackTrace) => Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.text2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/earnings');
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
          'Retrait',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.text1,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.record});

  final PayoutRequestRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(record.status);

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.bg, shape: BoxShape.circle),
          child: Icon(colors.icon, color: colors.fg, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          '${formatMoney(record.amount, withCurrency: false)} GNF',
          style: AppTextStyles.displayMd.copyWith(color: AppColors.text1),
        ),
        const SizedBox(height: 6),
        Text(
          record.status.label,
          style: AppTextStyles.label.copyWith(
            color: colors.fg,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (record.status.isPending) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.info,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Actualisation automatique',
                style: AppTextStyles.micro.copyWith(color: AppColors.text3),
              ),
            ],
          ),
        ],
        const SizedBox(height: 26),
        GnCard(
          radius: 16,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Row(label: 'Opérateur', value: record.operator),
              _Row(label: 'Numéro', value: record.destinationPhone),
              _Row(label: 'Référence', value: record.reference),
              _Row(label: 'Demandé le', value: _formatDate(record.createdAt)),
              _Row(
                label: 'Traité le',
                value: record.processedAt == null
                    ? '—'
                    : _formatDate(record.processedAt!),
              ),
              if (record.status == PayoutStatus.failed &&
                  (record.failureReason ?? '').isNotEmpty)
                _Row(label: 'Motif', value: record.failureReason!, last: true),
            ],
          ),
        ),
        if (record.status == PayoutStatus.failed) ...[
          const SizedBox(height: 12),
          Text(
            'Montant recrédité à votre portefeuille.',
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/${value.year}, $h:$min';
  }

  _StatusColors _colorsFor(PayoutStatus status) {
    return switch (status) {
      PayoutStatus.completed => const _StatusColors(
        bg: AppColors.successBg,
        fg: AppColors.success,
        icon: Icons.check,
      ),
      PayoutStatus.failed || PayoutStatus.cancelled => const _StatusColors(
        bg: AppColors.dangerBg,
        fg: AppColors.danger,
        icon: Icons.priority_high,
      ),
      PayoutStatus.pending || PayoutStatus.processing => const _StatusColors(
        bg: AppColors.infoBg,
        fg: AppColors.info,
        icon: Icons.refresh,
      ),
    };
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border2)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.text3,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: AppColors.text1,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusColors {
  const _StatusColors({required this.bg, required this.fg, required this.icon});

  final Color bg;
  final Color fg;
  final IconData icon;
}
