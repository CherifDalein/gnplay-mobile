import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class GnTextField extends StatelessWidget {
  const GnTextField({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      minLines: obscureText ? 1 : minLines,
      maxLines: obscureText ? 1 : maxLines,
      enabled: enabled,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      inputFormatters: inputFormatters,
      cursorColor: AppColors.accent500,
      style: AppTextStyles.body.copyWith(color: AppColors.text1),
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        errorText: errorText,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface1,
        floatingLabelBehavior: label == null
            ? FloatingLabelBehavior.never
            : FloatingLabelBehavior.always,
        labelStyle: AppTextStyles.micro.copyWith(color: AppColors.text3),
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.text3),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        border: _border(AppColors.border1),
        enabledBorder: _border(AppColors.border1),
        disabledBorder: _border(AppColors.border2),
        focusedBorder: _border(AppColors.brand700),
        errorBorder: _border(AppColors.danger),
        focusedErrorBorder: _border(AppColors.danger),
      ),
    );
  }

  OutlineInputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: BorderSide(color: color),
    );
  }
}
