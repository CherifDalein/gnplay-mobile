import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// Décoration des champs d'authentification : celle de `GnTextField`, qui ne
/// permet ni `autofillHints` ni préfixe, tous deux nécessaires ici.
InputDecoration authInputDecoration({
  String? placeholder,
  Widget? prefix,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
    borderSide: BorderSide(color: color),
  );

  return InputDecoration(
    hintText: placeholder,
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minHeight: 48),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.surface1,
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.text3),
    errorStyle: AppTextStyles.caption.copyWith(color: AppColors.danger),
    errorMaxLines: 2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(AppColors.border1),
    enabledBorder: border(AppColors.border1),
    disabledBorder: border(AppColors.border2),
    focusedBorder: border(AppColors.brand700),
    errorBorder: border(AppColors.danger),
    focusedErrorBorder: border(AppColors.danger),
  );
}

/// Libellé au-dessus du champ (maquette : 11 px, `text2`).
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel({super.key, required this.label, required this.child});

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

/// Champ texte d'authentification (libellé au-dessus, indices de saisie
/// automatique).
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.placeholder,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return AuthFieldLabel(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        inputFormatters: inputFormatters,
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        cursorColor: AppColors.accent500,
        style: AppTextStyles.body.copyWith(color: AppColors.text1),
        decoration: authInputDecoration(
          placeholder: placeholder,
          suffix: suffix,
        ),
      ),
    );
  }
}

/// Champ mot de passe avec bascule « Afficher / Masquer » (zone tactile de
/// 48 px, annoncée aux lecteurs d'écran).
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label = 'Mot de passe',
    this.placeholder = '••••••••',
    this.textInputAction,
    this.autofillHints = const [AutofillHints.password],
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String placeholder;
  final TextInputAction? textInputAction;
  final Iterable<String> autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final action = _obscured ? 'Afficher' : 'Masquer';
    return AuthTextField(
      controller: widget.controller,
      label: widget.label,
      placeholder: widget.placeholder,
      obscureText: _obscured,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      suffix: Semantics(
        button: true,
        label: '$action le mot de passe',
        excludeSemantics: true,
        onTap: () => setState(() => _obscured = !_obscured),
        child: InkWell(
          onTap: () => setState(() => _obscured = !_obscured),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                action,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.accent500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
