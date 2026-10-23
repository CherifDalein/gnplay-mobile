import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../../shared/widgets/gnplay_logo.dart';
import '../providers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // En cas de succès, le routeur quitte /login de lui-même (créateur →
    // tableau de bord, spectateur → « Devenir créateur »).
    await ref
        .read(loginControllerProvider.notifier)
        .login(
          phoneNumber: _phoneController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);
    final isLoading = loginState.isLoading;
    final errorMessage = loginState.whenOrNull(
      error: (error, _) => error is ApiException
          ? error.message
          : 'Une erreur inattendue est survenue.',
    );

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: GnAppBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 38, 26, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Center(child: GnplayLogo(height: 150)),
                            const SizedBox(height: 34),
                            Text(
                              'Content de vous revoir',
                              style: AppTextStyles.displayMd.copyWith(
                                color: AppColors.text1,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Connectez-vous à votre espace créateur.',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.text3,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 26),
                            _FieldLabel(
                              label: 'Numéro de téléphone',
                              child: GnTextField(
                                controller: _phoneController,
                                placeholder: '+224 621 45 88 07',
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().length < 9) {
                                    return 'Le numéro de téléphone est requis.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldLabel(
                              label: 'Mot de passe',
                              child: GnTextField(
                                controller: _passwordController,
                                placeholder: '••••••••',
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!isLoading) {
                                    _login();
                                  }
                                },
                                suffixIcon: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  child: Text(
                                    _obscurePassword ? 'Voir' : 'Masquer',
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.accent500,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Le mot de passe est requis.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (errorMessage != null) ...[
                              const SizedBox(height: 8),
                              _ErrorText(message: errorMessage),
                            ],
                            const SizedBox(height: 22),
                            GnButton(
                              label: 'Se connecter',
                              isLoading: isLoading,
                              onPressed: _login,
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.go('/forgot-password'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.text2,
                              ),
                              child: Text(
                                'Mot de passe oublié ?',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.text2,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            const _DividerWithText(label: 'ou'),
                            const SizedBox(height: 18),
                            GnButton(
                              label: 'Créer un compte',
                              variant: GnButtonVariant.secondary,
                              onPressed: isLoading
                                  ? null
                                  : () => context.go('/register'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.text2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _DividerWithText extends StatelessWidget {
  const _DividerWithText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.caption.copyWith(color: AppColors.danger),
    );
  }
}
