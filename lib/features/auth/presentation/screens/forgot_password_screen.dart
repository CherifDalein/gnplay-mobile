import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../providers/forgot_password_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  int _step = 1;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final isLoading = state.isLoading;
    final errorMessage = state.whenOrNull(
      error: (error, _) => error is ApiException
          ? error.message
          : 'Une erreur inattendue est survenue.',
    );

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: GnAppBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back, color: AppColors.text2),
                    style: IconButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Mot de passe oublié',
                    style: AppTextStyles.displayMd.copyWith(
                      color: AppColors.text1,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _step == 1
                        ? 'Recevez un code de vérification par SMS.'
                        : 'Code envoyé au ${_phoneController.text.trim()}',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.text3,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (_step == 1) ...[
                    GnTextField(
                      controller: _phoneController,
                      placeholder: '+224 621 45 88 07',
                      keyboardType: TextInputType.phone,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    GnButton(
                      label: 'Envoyer le code',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _requestCode,
                    ),
                  ] else ...[
                    GnTextField(
                      controller: _codeController,
                      placeholder: 'Code à 6 chiffres',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    GnTextField(
                      controller: _passwordController,
                      placeholder: 'Nouveau mot de passe',
                      obscureText: true,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    GnButton(
                      label: 'Réinitialiser le mot de passe',
                      isLoading: isLoading,
                      onPressed: isLoading ? null : _confirm,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => setState(() => _step = 1),
                      child: Text(
                        'Changer de numéro',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.text2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 9) {
      return;
    }
    final ok = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .requestCode(phoneNumber: phone);
    if (ok && mounted) {
      setState(() => _step = 2);
    }
  }

  Future<void> _confirm() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    if (code.isEmpty || password.isEmpty) {
      return;
    }
    final ok = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .confirm(phoneNumber: phone, code: code, newPassword: password);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            'Mot de passe mis à jour. Connectez-vous.',
            style: AppTextStyles.caption.copyWith(color: AppColors.text1),
          ),
        ),
      );
      context.go('/login');
    }
  }
}
