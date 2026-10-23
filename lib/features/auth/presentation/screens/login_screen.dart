import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/countries.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../../shared/widgets/gnplay_logo.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_error_text.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/phone_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  AppCountry _country = defaultCountry;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    // En cas de succès, le routeur quitte /login de lui-même (créateur →
    // tableau de bord, spectateur → « Devenir créateur »). Les champs ne sont
    // pas vidés en cas d'échec : l'utilisateur corrige sans tout retaper.
    await ref
        .read(loginControllerProvider.notifier)
        .login(
          phoneNumber: normalizePhoneNumber(
            _phoneController.text,
            country: _country,
          )!,
          password: _passwordController.text,
        );
  }

  /// Un 401 à la connexion veut dire « identifiants incorrects » (le message
  /// générique du socle parlerait de session expirée).
  String _messageFor(Object error) {
    if (error is ApiException && error.statusCode == 401) {
      return 'Numéro de téléphone ou mot de passe incorrect.';
    }
    return authErrorMessage(error);
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);
    final isLoading = loginState.isLoading;
    final error = loginState.error;
    final compact = MediaQuery.sizeOf(context).height < 700;

    return AuthScaffold(
      centered: true,
      topPadding: compact ? 16 : 38,
      children: [
        Center(child: GnplayLogo(height: compact ? 96 : 150)),
        SizedBox(height: compact ? 18 : 34),
        const AuthHeading(
          title: 'Content de vous revoir',
          subtitle: Text('Connectez-vous à votre espace créateur.'),
        ),
        const SizedBox(height: 26),
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PhoneField(
                  controller: _phoneController,
                  country: _country,
                  enabled: !isLoading,
                  onCountryChanged: (value) => setState(() => _country = value),
                ),
                const SizedBox(height: 14),
                AuthPasswordField(
                  controller: _passwordController,
                  enabled: !isLoading,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!isLoading) _login();
                  },
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Le mot de passe est requis.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          GnBanner(tone: GnBannerTone.danger, message: _messageFor(error)),
        ],
        const SizedBox(height: 22),
        GnButton(
          label: 'Se connecter',
          isLoading: isLoading,
          onPressed: isLoading ? null : _login,
        ),
        const SizedBox(height: 4),
        AuthTextLink(
          label: 'Mot de passe oublié ?',
          onPressed: isLoading ? null : () => context.push('/forgot-password'),
        ),
        const SizedBox(height: 14),
        const _DividerWithText(label: 'ou'),
        const SizedBox(height: 18),
        GnButton(
          label: 'Créer un compte',
          variant: GnButtonVariant.secondary,
          onPressed: isLoading ? null : () => context.push('/register'),
        ),
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
