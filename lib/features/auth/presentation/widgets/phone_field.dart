import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/locale/countries.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import 'auth_text_field.dart';

/// Ouvre la feuille de choix du pays ; renvoie null si elle est fermée sans
/// choix.
Future<AppCountry?> showCountryPicker(
  BuildContext context, {
  required AppCountry selected,
}) {
  return showModalBottomSheet<AppCountry>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Choisir le pays',
                style: AppTextStyles.sheetTitle.copyWith(
                  color: AppColors.text1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final country in supportedCountries)
              _CountryRow(
                country: country,
                selected: country == selected,
                onTap: () => Navigator.of(sheetContext).pop(country),
              ),
          ],
        ),
      ),
    ),
  );
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  final AppCountry country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${country.name}, indicatif ${country.dialPrefix}',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  country.name,
                  style: AppTextStyles.body.copyWith(color: AppColors.text1),
                ),
              ),
              Text(
                '${country.dialPrefix} · ${country.currency}',
                style: AppTextStyles.caption.copyWith(color: AppColors.text3),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 20,
                child: selected
                    ? const GnLineIcon(
                        GnLineIconData.check,
                        size: 18,
                        color: AppColors.accent500,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de pays en lecture « Pays : Guinée (GNF) ⌄ » (inscription).
class CountrySelectField extends StatelessWidget {
  const CountrySelectField({
    super.key,
    required this.country,
    required this.onChanged,
    this.enabled = true,
  });

  final AppCountry country;
  final ValueChanged<AppCountry> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canChange = enabled && supportedCountries.length > 1;

    Future<void> open() async {
      final picked = await showCountryPicker(context, selected: country);
      if (picked != null) onChanged(picked);
    }

    return AuthFieldLabel(
      label: 'Pays',
      child: Semantics(
        button: true,
        label: 'Pays : ${country.name}. Changer de pays',
        excludeSemantics: true,
        onTap: canChange ? open : null,
        child: InkWell(
          onTap: canChange ? open : null,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${country.name} (${country.currency})',
                    style: AppTextStyles.body.copyWith(color: AppColors.text1),
                  ),
                ),
                if (canChange)
                  const GnLineIcon(
                    GnLineIconData.chevronDown,
                    size: 16,
                    color: AppColors.text3,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ « Numéro de téléphone » : indicatif du pays en préfixe (touchable
/// pour changer de pays si [allowCountryChange]) puis numéro national.
///
/// Accepte aussi un numéro collé avec indicatif (« +221 77 … ») : le pays
/// correspondant est alors sélectionné automatiquement. La valeur à envoyer
/// au serveur s'obtient avec [normalizePhoneNumber].
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.allowCountryChange = true,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final AppCountry country;
  final ValueChanged<AppCountry> onCountryChanged;
  final bool allowCountryChange;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  /// Message d'erreur local, ou null si le numéro est valide pour [country].
  static String? validate(String? value, AppCountry country) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Le numéro de téléphone est requis.';
    if (normalizePhoneNumber(text, country: country) == null) {
      return 'Numéro invalide : ${country.nationalLength} chiffres '
          'attendus pour ${country.name} (ex. ${country.exampleNumber}).';
    }
    return null;
  }

  void _handleChanged(String value) {
    if (hasInternationalPrefix(value)) {
      final digits = value.trim().replaceFirst(RegExp(r'^(\+|00)'), '');
      final digitsOnly = digits.replaceAll(RegExp(r'\D'), '');
      for (final candidate in supportedCountries) {
        if (candidate != country && digitsOnly.startsWith(candidate.dialCode)) {
          onCountryChanged(candidate);
          break;
        }
      }
    }
    onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final canChange =
        allowCountryChange && enabled && supportedCountries.length > 1;

    Future<void> open() async {
      final picked = await showCountryPicker(context, selected: country);
      if (picked != null) onCountryChanged(picked);
    }

    final prefix = Semantics(
      button: canChange,
      label:
          'Indicatif ${country.dialPrefix}, ${country.name}'
          '${canChange ? '. Changer de pays' : ''}',
      excludeSemantics: true,
      onTap: canChange ? open : null,
      child: InkWell(
        onTap: canChange ? open : null,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                country.dialPrefix,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.text2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (canChange) ...[
                const SizedBox(width: 4),
                const GnLineIcon(
                  GnLineIconData.chevronDown,
                  size: 14,
                  color: AppColors.text3,
                ),
              ],
              const SizedBox(width: 10),
              Container(width: 1, height: 18, color: AppColors.border1),
            ],
          ),
        ),
      ),
    );

    return AuthFieldLabel(
      label: 'Numéro de téléphone',
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.phone,
        textInputAction: textInputAction,
        autofillHints: const [AutofillHints.telephoneNumber],
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-.()]')),
        ],
        validator: (value) => validate(value, country),
        onFieldSubmitted: onFieldSubmitted,
        onChanged: _handleChanged,
        cursorColor: AppColors.accent500,
        style: AppTextStyles.body.copyWith(color: AppColors.text1),
        decoration: authInputDecoration(
          placeholder: country.exampleNumber,
          prefix: prefix,
        ),
      ),
    );
  }
}
