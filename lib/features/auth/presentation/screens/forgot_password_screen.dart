import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/countries.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../domain/auth_rules.dart';
import '../../domain/code_request_outcome.dart';
import '../providers/auth_controller.dart';
import '../providers/forgot_password_controller.dart';
import '../widgets/auth_error_text.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/otp_code_section.dart';
import '../widgets/phone_field.dart';
import '../widgets/resend_countdown.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _countdown = ResendCountdown();

  AppCountry _country = defaultCountry;
  String? _codeError;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _countdown.dispose();
    super.dispose();
  }

  ForgotPasswordController get _controller =>
      ref.read(forgotPasswordControllerProvider.notifier);

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    if (!_phoneFormKey.currentState!.validate()) return;
    final phone = normalizePhoneNumber(
      _phoneController.text,
      country: _country,
    )!;

    // Retour pour corriger autre chose alors que le code vient d'être envoyé
    // à ce numéro : inutile (et refusé par le serveur) d'en redemander un.
    final flow = ref.read(forgotPasswordControllerProvider);
    if (flow.codeSentTo == phone && _countdown.isRunning) {
      _controller.showResetStep();
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

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    final code = _codeController.text.trim();
    final codeValid = code.length == otpCodeLength;
    setState(
      () => _codeError = codeValid
          ? null
          : 'Entrez le code à $otpCodeLength chiffres.',
    );
    if (!_resetFormKey.currentState!.validate() || !codeValid) return;

    final ok = await _controller.confirm(
      phone: ref.read(forgotPasswordControllerProvider).codeSentTo!,
      code: code,
      newPassword: _passwordController.text,
    );
    if (!ok || !mounted) return;

    showGnToast(context, 'Mot de passe modifié', tone: GnToastTone.success);
    context.go('/login');
  }

  /// Écran ouvert depuis la connexion (pile) ou depuis les Réglages : le
  /// retour ne doit jamais renvoyer un utilisateur connecté vers /login.
  void _back() {
    final flow = ref.read(forgotPasswordControllerProvider);
    if (flow.step == ForgotPasswordStep.reset) {
      _controller.backToPhone();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (ref.read(authControllerProvider).valueOrNull != null) {
      context.go('/settings');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(forgotPasswordControllerProvider);
    final onReset = flow.step == ForgotPasswordStep.reset;

    return AuthScaffold(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GnBackButton(
            alignment: Alignment.centerLeft,
            // Pendant une requête : ne rien faire (null reviendrait en arrière).
            onPressed: flow.busy ? () {} : _back,
          ),
        ),
        const SizedBox(height: 14),
        if (onReset) _buildResetStep(flow) else _buildPhoneStep(flow),
      ],
    );
  }

  Widget _buildPhoneStep(ForgotPasswordState flow) {
    final error = flow.error;
    final unknownAccount = error is ApiException && error.statusCode == 404;

    return Form(
      key: _phoneFormKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeading(
              title: 'Mot de passe oublié',
              subtitle: Text(
                'Recevez un code de vérification par WhatsApp ou SMS.',
              ),
            ),
            const SizedBox(height: 26),
            PhoneField(
              controller: _phoneController,
              country: _country,
              enabled: !flow.busy,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!flow.busy) _continue();
              },
              onCountryChanged: (value) => setState(() => _country = value),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              GnBanner(
                tone: GnBannerTone.danger,
                message: authErrorMessage(
                  error,
                  notFound: 'Aucun compte n’est associé à ce numéro.',
                ),
                actionLabel: unknownAccount ? 'Créer un compte' : null,
                onAction: unknownAccount
                    ? () => context.push('/register')
                    : null,
              ),
            ],
            const SizedBox(height: 22),
            GnButton(
              label: 'Envoyer le code',
              isLoading: flow.busy,
              onPressed: flow.busy ? null : _continue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetStep(ForgotPasswordState flow) {
    final phone = flow.codeSentTo!;
    final error = flow.error;

    return Form(
      key: _resetFormKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeading(title: 'Nouveau mot de passe'),
            const SizedBox(height: 10),
            OtpCodeSection(
              controller: _codeController,
              phone: phone,
              countdown: _countdown,
              busy: flow.busy,
              errorText: _codeError,
              onChanged: (_) {
                if (_codeError != null) setState(() => _codeError = null);
              },
              onEditPhone: _controller.backToPhone,
              onResend: () => _requestCode(phone),
              onResendBySms: () => _requestCode(phone, channel: otpChannelSms),
            ),
            const SizedBox(height: 18),
            AuthPasswordField(
              controller: _passwordController,
              label: 'Nouveau mot de passe',
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
                if (!flow.busy) _confirm();
              },
              validator: (value) => value != _passwordController.text
                  ? 'Les mots de passe ne correspondent pas.'
                  : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              GnBanner(
                tone: GnBannerTone.danger,
                message: isExpiredCodeError(error)
                    ? '${authErrorMessage(error)} Renvoyez un nouveau code '
                          'pour continuer.'
                    : authErrorMessage(error),
              ),
            ],
            const SizedBox(height: 22),
            GnButton(
              label: 'Modifier le mot de passe',
              isLoading: flow.busy,
              onPressed: flow.busy ? null : _confirm,
            ),
          ],
        ),
      ),
    );
  }
}
