/// Pays proposés à l'inscription : ceux présents en base ET couverts par
/// l'envoi des codes de vérification.
class AppCountry {
  const AppCountry({
    required this.iso2,
    required this.name,
    required this.dialCode,
    required this.currency,
    required this.nationalLength,
    required this.exampleNumber,
  });

  /// Code ISO 3166-1 alpha-2, envoyé tel quel au backend (`country_iso2`).
  final String iso2;
  final String name;

  /// Indicatif sans « + » (ex. `224`).
  final String dialCode;
  final String currency;

  /// Nombre de chiffres du numéro national (sans indicatif).
  final int nationalLength;

  /// Numéro national d'exemple, pour l'indication de saisie.
  final String exampleNumber;

  String get dialPrefix => '+$dialCode';

  @override
  bool operator ==(Object other) => other is AppCountry && other.iso2 == iso2;

  @override
  int get hashCode => iso2.hashCode;
}

const guinea = AppCountry(
  iso2: 'GN',
  name: 'Guinée',
  dialCode: '224',
  currency: 'GNF',
  nationalLength: 9,
  exampleNumber: '621 45 88 07',
);

const senegal = AppCountry(
  iso2: 'SN',
  name: 'Sénégal',
  dialCode: '221',
  currency: 'XOF',
  nationalLength: 9,
  exampleNumber: '77 123 45 67',
);

const supportedCountries = <AppCountry>[guinea, senegal];

const defaultCountry = guinea;

/// Pays dont l'indicatif commence [e164] (`+224…`), ou null.
AppCountry? countryOfE164(String e164) {
  for (final country in supportedCountries) {
    if (e164.startsWith(country.dialPrefix)) return country;
  }
  return null;
}

/// Vrai si la saisie commence par `+` ou `00` (indicatif saisi à la main).
bool hasInternationalPrefix(String input) {
  final trimmed = input.trim();
  return trimmed.startsWith('+') || trimmed.startsWith('00');
}

/// Normalise un numéro saisi vers le format E.164 attendu par le backend
/// (`+224621458807`, sans espace). Le backend compare la chaîne exacte à la
/// connexion : tout compte existant est enregistré sous cette forme.
///
/// Accepte espaces, tirets, points, parenthèses, le préfixe `00` et un
/// indicatif déjà saisi (avec ou sans `+`). Renvoie null si le numéro n'a pas
/// la longueur attendue pour [country], ou si l'indicatif saisi est celui d'un
/// autre pays.
String? normalizePhoneNumber(
  String input, {
  AppCountry country = defaultCountry,
}) {
  var text = input.trim();
  if (text.isEmpty) return null;

  var international = false;
  if (text.startsWith('+')) {
    international = true;
    text = text.substring(1);
  } else if (text.startsWith('00')) {
    international = true;
    text = text.substring(2);
  }

  // Séparateurs usuels uniquement : toute autre lettre rend le numéro invalide.
  if (RegExp(r'[^0-9\s\-.()]').hasMatch(text)) return null;
  var digits = text.replaceAll(RegExp(r'[^0-9]'), '');

  if (international) {
    if (!digits.startsWith(country.dialCode)) return null;
    digits = digits.substring(country.dialCode.length);
  } else if (digits.length ==
          country.dialCode.length + country.nationalLength &&
      digits.startsWith(country.dialCode)) {
    // « 224621458807 » : indicatif saisi sans « + ».
    digits = digits.substring(country.dialCode.length);
  }

  if (digits.length != country.nationalLength) return null;
  return '${country.dialPrefix}$digits';
}

/// `+224621458807` → `+224 621 45 88 07` (affichage). Une chaîne qui n'est pas
/// un numéro d'un pays géré est renvoyée telle quelle.
String formatPhoneNumber(String e164) {
  final country = countryOfE164(e164);
  if (country == null) return e164;
  final national = e164.substring(country.dialPrefix.length);
  if (national.length != 9) return e164;
  return '${country.dialPrefix} ${national.substring(0, 3)} '
      '${national.substring(3, 5)} ${national.substring(5, 7)} '
      '${national.substring(7)}';
}
