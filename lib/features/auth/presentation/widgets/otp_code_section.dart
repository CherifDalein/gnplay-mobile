import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/locale/countries.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/auth_rules.dart';
import 'auth_scaffold.dart';
import 'resend_countdown.dart';

/// Bloc « code reçu » commun à l'inscription et au mot de passe oublié :
/// numéro destinataire (modifiable), saisie du code à 6 chiffres, validité et
/// renvoi (par le canal par défaut ou par SMS) avec compte à rebours.
class OtpCodeSection extends StatelessWidget {
  const OtpCodeSection({
    super.key,
    required this.controller,
    required this.phone,
    required this.countdown,
    required this.onResend,
    required this.onResendBySms,
    required this.onEditPhone,
    this.busy = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// Numéro (E.164) auquel le code a été envoyé.
  final String phone;
  final ResendCountdown countdown;
  final VoidCallback onResend;
  final VoidCallback onResendBySms;
  final VoidCallback onEditPhone;
  final bool busy;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.text3,
                    fontWeight: FontWeight.w400,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Code à $otpCodeLength chiffres envoyé au ',
                    ),
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
            ),
            AuthTextLink(
              label: 'Modifier',
              color: AppColors.accent500,
              onPressed: busy ? null : onEditPhone,
            ),
          ],
        ),
        const SizedBox(height: 16),
        OtpCodeInput(
          controller: controller,
          enabled: !busy,
          errorText: errorText,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 6),
        Text(
          'Le code est valable $otpValidityMinutes minutes.',
          style: AppTextStyles.caption.copyWith(color: AppColors.text3),
        ),
        const SizedBox(height: 4),
        ListenableBuilder(
          listenable: countdown,
          builder: (context, _) {
            final waiting = countdown.isRunning;
            final locked = waiting || busy;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (waiting)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        liveRegion: false,
                        child: Text.rich(
                          TextSpan(
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.text3,
                            ),
                            children: [
                              const TextSpan(text: 'Renvoyer le code dans '),
                              TextSpan(
                                text: ResendCountdown.format(
                                  countdown.remaining,
                                ),
                                style: const TextStyle(
                                  color: AppColors.accent500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  AuthTextLink(
                    label: 'Renvoyer le code',
                    color: AppColors.accent500,
                    alignment: Alignment.centerLeft,
                    onPressed: locked ? null : onResend,
                  ),
                AuthTextLink(
                  label: 'Recevoir le code par SMS',
                  alignment: Alignment.centerLeft,
                  onPressed: locked ? null : onResendBySms,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Saisie du code à 6 chiffres : six cases dessinées sous un vrai champ de
/// texte transparent, qui garde collage, saisie automatique du SMS
/// (`oneTimeCode`) et annonce par les lecteurs d'écran.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.controller,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 56,
          child: Stack(
            children: [
              ExcludeSemantics(
                child: ListenableBuilder(
                  listenable: Listenable.merge([widget.controller, _focusNode]),
                  builder: (context, _) {
                    final code = widget.controller.text;
                    return Row(
                      children: [
                        for (var i = 0; i < otpCodeLength; i++) ...[
                          if (i > 0) const SizedBox(width: 9),
                          Expanded(
                            child: _CodeBox(
                              digit: i < code.length ? code[i] : '',
                              active:
                                  _focusNode.hasFocus &&
                                  i == code.length.clamp(0, otpCodeLength - 1),
                              error: hasError,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: Semantics(
                  label: 'Code de vérification à $otpCodeLength chiffres',
                  child: TextField(
                    key: const ValueKey('otp-code-field'),
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: true,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    maxLength: otpCodeLength,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    // Texte et curseur invisibles : les cases affichent le code.
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            widget.errorText!,
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.digit,
    required this.active,
    required this.error,
  });

  final String digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: error
              ? AppColors.danger
              : active
              ? AppColors.accent500
              : AppColors.border1,
        ),
      ),
      child: Text(
        digit,
        style: AppTextStyles.title.copyWith(
          color: AppColors.text1,
          fontSize: 20,
        ),
      ),
    );
  }
}
