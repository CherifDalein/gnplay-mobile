import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/locale/countries.dart';

void main() {
  group('pays proposés', () {
    test('Guinée par défaut, Guinée et Sénégal uniquement', () {
      expect(defaultCountry.iso2, 'GN');
      expect(supportedCountries.map((c) => c.iso2), ['GN', 'SN']);
      expect(guinea.dialCode, '224');
      expect(guinea.currency, 'GNF');
      expect(senegal.dialCode, '221');
      expect(senegal.currency, 'XOF');
      expect(guinea.nationalLength, 9);
      expect(senegal.nationalLength, 9);
    });
  });

  group('normalizePhoneNumber', () {
    test('numéro national, avec espaces et séparateurs', () {
      expect(normalizePhoneNumber('621458807'), '+224621458807');
      expect(normalizePhoneNumber(' 621 45 88 07 '), '+224621458807');
      expect(normalizePhoneNumber('621-45-88-07'), '+224621458807');
      expect(normalizePhoneNumber('621.45.88.07'), '+224621458807');
      expect(normalizePhoneNumber('(621) 45 88 07'), '+224621458807');
    });

    test('indicatif déjà saisi : +, 00 ou sans préfixe', () {
      expect(normalizePhoneNumber('+224621458807'), '+224621458807');
      expect(normalizePhoneNumber('+224 621 45 88 07'), '+224621458807');
      expect(normalizePhoneNumber('00224621458807'), '+224621458807');
      expect(normalizePhoneNumber('00 224 621 45 88 07'), '+224621458807');
      expect(normalizePhoneNumber('224621458807'), '+224621458807');
      expect(normalizePhoneNumber('+224-621-45-88-07'), '+224621458807');
    });

    test('utilise l’indicatif du pays choisi', () {
      expect(
        normalizePhoneNumber('77 123 45 67', country: senegal),
        '+221771234567',
      );
      expect(
        normalizePhoneNumber('+221 77 123 45 67', country: senegal),
        '+221771234567',
      );
    });

    test('refuse les numéros invalides', () {
      expect(normalizePhoneNumber(''), isNull);
      expect(normalizePhoneNumber('   '), isNull);
      expect(normalizePhoneNumber('62145880'), isNull); // trop court
      expect(normalizePhoneNumber('6214588070'), isNull); // trop long
      expect(normalizePhoneNumber('62145880a'), isNull);
      expect(normalizePhoneNumber('+224 6214588'), isNull);
      // Indicatif d'un autre pays que celui sélectionné.
      expect(normalizePhoneNumber('+221771234567'), isNull);
      expect(normalizePhoneNumber('+33612345678'), isNull);
    });

    test('est idempotent sur un numéro déjà normalisé', () {
      final once = normalizePhoneNumber('621 45 88 07')!;
      expect(normalizePhoneNumber(once), once);
    });
  });

  group('affichage', () {
    test('formatPhoneNumber groupe le numéro', () {
      expect(formatPhoneNumber('+224621458807'), '+224 621 45 88 07');
      expect(formatPhoneNumber('+221771234567'), '+221 771 23 45 67');
      expect(formatPhoneNumber('abc'), 'abc');
    });

    test('countryOfE164 et préfixe international', () {
      expect(countryOfE164('+221771234567'), senegal);
      expect(countryOfE164('+33612345678'), isNull);
      expect(hasInternationalPrefix('+224 6'), isTrue);
      expect(hasInternationalPrefix('00224'), isTrue);
      expect(hasInternationalPrefix('621'), isFalse);
    });
  });
}
