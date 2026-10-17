import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/presentation/providers/topup_controller.dart';

Future<void> showTopupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _TopupSheet(),
  );
}

class _TopupSheet extends ConsumerStatefulWidget {
  const _TopupSheet();

  @override
  ConsumerState<_TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends ConsumerState<_TopupSheet>
    with WidgetsBindingObserver {
  static const _quickAmounts = [10000, 25000, 50000, 100000];

  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// De retour du navigateur de paiement : vérifie sans attendre le prochain
  /// passage du sondage périodique.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(topupControllerProvider.notifier).checkNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(topupControllerProvider);
    final amount = int.tryParse(_controller.text) ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recharger mon portefeuille',
            style: AppTextStyles.heading.copyWith(color: AppColors.text1),
          ),
          const SizedBox(height: 14),
          switch (state.phase) {
            TopupPhase.awaitingPayment => _Status(
              icon: const CircularProgressIndicator(color: AppColors.accent500),
              title: 'En attente du paiement…',
              body:
                  'Terminez le paiement dans votre navigateur, puis revenez ici. Le solde se met à jour automatiquement.',
            ),
            TopupPhase.completed => _Status(
              icon: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 40,
              ),
              title: 'Recharge confirmée',
              body: 'Votre portefeuille a été crédité.',
              actionLabel: 'Terminer',
              onAction: () => Navigator.of(context).pop(),
            ),
            TopupPhase.failed => _Status(
              icon: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.danger,
                size: 40,
              ),
              title: 'Recharge non aboutie',
              body: state.message ?? 'Une erreur est survenue.',
              actionLabel: 'Réessayer',
              onAction: () =>
                  ref.read(topupControllerProvider.notifier).reset(),
            ),
            _ => _AmountForm(
              controller: _controller,
              amount: amount,
              quickAmounts: _quickAmounts,
              isLoading: state.phase == TopupPhase.starting,
              onChanged: () => setState(() {}),
              onSubmit: () =>
                  ref.read(topupControllerProvider.notifier).start(amount),
            ),
          },
        ],
      ),
    );
  }
}

class _AmountForm extends StatelessWidget {
  const _AmountForm({
    required this.controller,
    required this.amount,
    required this.quickAmounts,
    required this.isLoading,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final int amount;
  final List<int> quickAmounts;
  final bool isLoading;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GnCard(
          radius: 14,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => onChanged(),
                  style: AppTextStyles.displayMd.copyWith(
                    color: AppColors.text1,
                    fontSize: 28,
                  ),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '0',
                  ),
                ),
              ),
              Text(
                'GNF',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.text3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in quickAmounts)
              ActionChip(
                label: Text(formatMoney(value, withCurrency: false)),
                onPressed: () {
                  controller.text = '$value';
                  onChanged();
                },
                backgroundColor: AppColors.surface2,
                side: const BorderSide(color: AppColors.border1),
                labelStyle: AppTextStyles.caption.copyWith(
                  color: AppColors.text2,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GnButton(
          label: 'Payer avec mobile money',
          isLoading: isLoading,
          onPressed: amount > 0 && !isLoading ? onSubmit : null,
        ),
        const SizedBox(height: 8),
        Text(
          'Vous serez redirigé vers la page de paiement sécurisée DexPay.',
          textAlign: TextAlign.center,
          style: AppTextStyles.micro.copyWith(color: AppColors.text3),
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final Widget icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(width: 40, height: 40, child: Center(child: icon)),
        const SizedBox(height: 14),
        Text(
          title,
          style: AppTextStyles.label.copyWith(color: AppColors.text1),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(color: AppColors.text3),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: GnButton(label: actionLabel!, onPressed: onAction),
          ),
        ],
      ],
    );
  }
}
