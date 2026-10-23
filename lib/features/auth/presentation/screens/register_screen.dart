import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/countries.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../domain/auth_rules.dart';
import '../../domain/code_request_outcome.dart';
import '../providers/register_controller.dart';
import '../widgets/auth_error_text.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_code_section.dart';
import '../widgets/phone_field.dart';
import '../widgets/resend_countdown.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _accountFormKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _codeController = TextEditingController();
  final _countdown = ResendCountdown();

  AppCountry _country = defaultCountry;
  String? _codeError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _codeController.dispose();
    _countdown.dispose();
    super.dispose();
  }

  RegisterController get _controller =>
      ref.read(registerControllerProvider.notifier);

  /// Numéro saisi au format E.164 (null tant que le formulaire est invalide).
  String? get _phone =>
      normalizePhoneNumber(_phoneController.text, country: _country);

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_accountFormKey.currentState!.validate()) return;
    final phone = _phone!;
    final flow = ref.read(registerControllerProvider);

    // Retour pour corriger le nom ou le mot de passe : si le code vient d'être
    // envoyé à ce numéro (ou que le numéro est déjà vérifié), inutile d'en
    // redemander un, le serveur refuserait d'ailleurs avant une minute.
    final alreadyVerified = flow.verifiedPhone == phone;
    final recentlySent = flow.codeSentTo == phone && _countdown.isRunning;
    if (alreadyVerified || recentlySent) {
      _controller.showCodeStep(phone);
      return;
    }
    await _requestCode(phone);
  }

  Future<void> _requestCode(String phone, {String? channel}) async {
    FocusScope.of(context).unfocus();
    final outcome = await _controller.sendCode(phone, channel: channel);
    if (!mounted) return;
    if (outcome != CodeRequestOutcome.failed) _countdown.start();
    if (outcome == CodeRequestOutcome.sent) {
      _codeController.clear();
      setState(() => _codeError = null);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final flow = ref.read(registerControllerProvider);
    final phone = flow.codeSentTo!;
    final verified = flow.verifiedPhone == phone;
    final code = _codeController.text.trim();

    if (!verified && code.length != otpCodeLength) {
      setState(() => _codeError = 'Entrez le code à $otpCodeLength chiffres.');
      return;
    }

    final outcome = await _controller.submit(
      fullName: _fullNameController.text.trim(),
      country: _country,
      phone: phone,
      password: _passwordController.text,
      code: code,
    );
    if (!mounted) return;

    // Succès : le routeur redirige tout seul (nouveau compte spectateur →
    // « Devenir créateur »).
    if (outcome == RegisterOutcome.loginFailed) {
      showGnToast(
        context,
        'Compte créé. Connectez-vous avec votre numéro et votre mot de passe.',
        tone: GnToastTone.success,
      );
      context.go('/login');
    }
  }

  void _back() {
    final flow = ref.read(registerControllerProvider);
    if (flow.step == RegisterStep.code) {
      _controller.backToAccount();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(registerControllerProvider);
    final onCodeStep = flow.step == RegisterStep.code;

    return AuthScaffold(
      children: [
        Row(
          children: [
            GnBackButton(
              alignment: Alignment.centerLeft,
              // Pendant une requête : ne rien faire (null reviendrait à l'écran précédent).
              onPressed: flow.busy ? () {} : _back,
            ),
            const SizedBox(width: 12),
            Expanded(child: _ProgressBars(onCodeStep: onCodeStep)),
            const SizedBox(width: 44),
          ],
        ),
        const SizedBox(height: 20),
        if (onCodeStep) _buildCodeStep(flow) else _buildAccountStep(flow),
      ],
    );
  }

  Widget _buildAccountStep(RegisterFlowState flow) {
    final error = flow.error;

    return Form(
      key: _accountFormKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeading(
              title: 'Créer votre compte',
              subtitle: Text('Étape 1 sur 2 · vos informations'),
            ),
            const SizedBox(height: 24),
            AuthTextField(
              controller: _fullNameController,
              label: 'Nom complet',
              placeholder: 'Mariama Diallo',
              enabled: !flow.busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (value) {
                final length = value?.trim().length ?? 0;
                if (length == 0) return 'Le nom complet est requis.';
                if (length < minFullNameLength) {
                  return 'Le nom doit contenir au moins $minFullNameLength '
                      'caractères (prénom et nom).';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            CountrySelectField(
              country: _country,
              enabled: !flow.busy,
              onChanged: (value) => setState(() => _country = value),
            ),
            const SizedBox(height: 14),
            PhoneField(
              controller: _phoneController,
              country: _country,
              enabled: !flow.busy,
              allowCountryChange: false,
              onCountryChanged: (value) => setState(() => _country = value),
            ),
            const SizedBox(height: 14),
            AuthPasswordField(
              controller: _passwordController,
              label: 'Mot de passe',
              enabled: !flow.busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) =>
                  (value == null || value.length < minPasswordLength)
                  ? 'Le mot de passe doit contenir au moins '
                        '$minPasswordLength caractères.'
                  : null,
            ),
            const SizedBox(height: 14),
            AuthPasswordField(
              controller: _confirmController,
              label: 'Confirmer le mot de passe',
              enabled: !flow.busy,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) {
                if (!flow.busy) _continue();
              },
              validator: (value) => value != _passwordController.text
                  ? 'Les mots de passe ne correspondent pas.'
                  : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              _ErrorBanner(error: error),
            ],
            const SizedBox(height: 24),
            GnButton(
              label: 'Continuer',
              isLoading: flow.busy,
              onPressed: flow.busy ? null : _continue,
            ),
            const SizedBox(height: 6),
            AuthTextLink(
              label: 'Déjà un compte ? Se connecter',
              onPressed: flow.busy ? null : () => context.go('/login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeStep(RegisterFlowState flow) {
    final phone = flow.codeSentTo!;
    final verified = flow.verifiedPhone == phone;
    final error = flow.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthHeading(title: 'Vérification'),
        const SizedBox(height: 10),
        if (verified) ...[
          Text.rich(
            TextSpan(
              style: AppTextStyles.label.copyWith(
                color: AppColors.text3,
                fontWeight: FontWeight.w400,
              ),
              children: [
                const TextSpan(text: 'Numéro vérifié : '),
                TextSpan(
                  text: formatPhoneNumber(phone),
                  style: const TextStyle(
                    color: AppColors.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const GnBanner(
            tone: GnBannerTone.success,
            message:
                'Votre numéro est vérifié. Il ne reste qu’à créer le compte, '
                'sans nouveau code.',
          ),
        ] else
          OtpCodeSection(
            controller: _codeController,
            phone: phone,
            countdown: _countdown,
            busy: flow.busy,
            errorText: _codeError,
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
            },
            onSubmitted: (_) {
              if (!flow.busy) _submit();
            },
            onEditPhone: _controller.backToAccount,
            onResend: () => _requestCode(phone),
            onResendBySms: () => _requestCode(phone, channel: otpChannelSms),
          ),
        if (error != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(error: error),
        ],
        const SizedBox(height: 22),
        GnButton(
          label: verified ? 'Créer mon compte' : 'Vérifier',
          isLoading: flow.busy,
          onPressed: flow.busy ? null : _submit,
        ),
        if (verified)
          AuthTextLink(
            label: 'Modifier le numéro',
            onPressed: flow.busy ? null : _controller.backToAccount,
          ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
            children: const [
              TextSpan(text: 'Votre compte est créé en tant que '),
              TextSpan(
                text: 'spectateur',
                style: TextStyle(color: AppColors.text2),
              ),
              TextSpan(text: '. Vous pourrez passer créateur juste après.'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Erreur du serveur ; propose la connexion si le compte existe déjà, et de
/// renvoyer le code s'il a expiré.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    var message = authErrorMessage(error);
    final exists = isAccountExistsError(error);
    if (isExpiredCodeError(error)) {
      message = '$message Renvoyez un nouveau code pour continuer.';
    }
    return GnBanner(
      tone: GnBannerTone.danger,
      message: message,
      actionLabel: exists ? 'Se connecter' : null,
      onAction: exists ? () => context.go('/login') : null,
    );
  }
}

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.onCodeStep});

  final bool onCodeStep;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Étape ${onCodeStep ? 2 : 1} sur 2',
      excludeSemantics: true,
      child: Row(
        children: [
          const Expanded(child: _ProgressBar(isActive: true)),
          const SizedBox(width: 6),
          Expanded(child: _ProgressBar(isActive: onCodeStep)),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent500 : AppColors.border1,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
