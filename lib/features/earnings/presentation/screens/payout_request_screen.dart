import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/gn_formatters.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/creator_dashboard.dart';
import '../../../creator/domain/payout_provider.dart';
import '../../../creator/presentation/providers/creator_dashboard_provider.dart';
import '../../../creator/presentation/providers/payout_controller.dart';
import '../../../creator/presentation/providers/payout_providers.dart';

class PayoutRequestScreen extends ConsumerStatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  ConsumerState<PayoutRequestScreen> createState() =>
      _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends ConsumerState<PayoutRequestScreen> {
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedProviderShortName;
  bool _phonePrefilled = false;

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(creatorDashboardProvider);
    final dashboard = dashboardState.valueOrNull ?? CreatorDashboard.sample();
    final providersState = ref.watch(payoutProviderOptionsProvider);
    final providers = providersState.valueOrNull ?? const <PayoutProviderOption>[];
    final payoutState = ref.watch(payoutControllerProvider);
    final isLoading = payoutState.isLoading;

    if (!_phonePrefilled && dashboard.user.phoneNumber.isNotEmpty) {
      _phonePrefilled = true;
      _phoneController.text = dashboard.user.phoneNumber;
    }

    final selectedProvider = providers.where((p) => p.shortName == _selectedProviderShortName).firstOrNull ??
        (providers.isNotEmpty ? providers.first : null);
    if (_selectedProviderShortName == null && selectedProvider != null) {
      _selectedProviderShortName = selectedProvider.shortName;
    }

    final amount = int.tryParse(_amountController.text) ?? 0;
    final minAmount = selectedProvider?.minAmount ?? 0;
    final belowMin = minAmount > 0 && amount > 0 && amount < minAmount;
    final insufficient = amount > dashboard.withdrawableBalance;
    final canSubmit = amount > 0 &&
        !belowMin &&
        !insufficient &&
        selectedProvider != null &&
        !isLoading;

    final errorMessage = payoutState.whenOrNull(
      error: (error, _) {
        if (error is ApiException && error.statusCode == 429) {
          return 'Vous avez atteint la limite de demandes de retrait. Réessayez dans quelques minutes.';
        }
        return error is ApiException
            ? error.message
            : 'La demande de retrait a échoué.';
      },
    );

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            children: [
              _Header(onBack: () => _goBack(context)),
              const SizedBox(height: 18),
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
                      '${formatMoney(dashboard.withdrawableBalance, withCurrency: false)} GNF',
                      style: AppTextStyles.heading.copyWith(
                        color: AppColors.accent300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Montant',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.text2,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              GnCard(
                radius: 14,
                borderColor: belowMin || insufficient
                    ? AppColors.danger
                    : AppColors.border1,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => setState(() {}),
                        style: AppTextStyles.displayMd.copyWith(
                          color: AppColors.text1,
                          fontSize: 30,
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    insufficient
                        ? 'Solde insuffisant'
                        : 'Minimum : ${formatMoney(minAmount, withCurrency: false)} GNF',
                    style: AppTextStyles.micro.copyWith(
                      color: belowMin || insufficient
                          ? AppColors.danger
                          : AppColors.text3,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _amountController.text =
                          '${dashboard.withdrawableBalance}';
                    }),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text(
                      'Tout retirer',
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.accent500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Opérateur mobile money',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.text2,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 9),
              if (providersState.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent500),
                  ),
                )
              else if (providers.isEmpty)
                Text(
                  'Aucun opérateur disponible pour votre pays.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.text3),
                )
              else
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: providers.map((provider) {
                    final selected = provider.shortName == _selectedProviderShortName;
                    return _ProviderChip(
                      provider: provider,
                      selected: selected,
                      onTap: () =>
                          setState(() => _selectedProviderShortName = provider.shortName),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              GnTextField(
                controller: _phoneController,
                label: 'Numéro destinataire',
                keyboardType: TextInputType.phone,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                GnCard(
                  radius: 12,
                  backgroundColor: AppColors.warningBg,
                  borderColor: AppColors.warning.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  child: Text(
                    errorMessage,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GnButton(
                label: isLoading ? 'Envoi de la demande…' : 'Confirmer le retrait',
                isLoading: isLoading,
                onPressed: canSubmit ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text) ?? 0;
    final providerId = _selectedProviderShortName;
    if (amount <= 0 || providerId == null) {
      return;
    }

    final record = await ref
        .read(payoutControllerProvider.notifier)
        .requestPayout(
          amount: amount,
          operator: providerId,
          destinationPhone: _phoneController.text,
        );

    if (record != null && mounted) {
      context.pushReplacement('/payout/${record.id}');
    }
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
          'Retirer mes gains',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.text1,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final PayoutProviderOption provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand600.withValues(alpha: 0.22)
              : AppColors.surface1,
          border: Border.all(
            color: selected ? AppColors.brand500 : AppColors.border1,
          ),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Text(
          provider.name,
          style: AppTextStyles.label.copyWith(
            color: selected ? AppColors.text1 : AppColors.text2,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
