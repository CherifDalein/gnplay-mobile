import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/locale/currency_provider.dart';
import 'package:gnplay/features/profile/presentation/providers/current_user_provider.dart';
import 'package:gnplay/shared/utils/gn_formatters.dart';

import 'creator_dashboard_support.dart';

void main() {
  group('currencyOfPhoneNumber', () {
    test('Guinée → GNF, Sénégal → XOF', () {
      expect(currencyOfPhoneNumber('+224621458807'), 'GNF');
      expect(currencyOfPhoneNumber('+221771234567'), 'XOF');
    });

    test('numéro absent ou d\'un pays non géré → GNF par défaut', () {
      expect(currencyOfPhoneNumber(null), 'GNF');
      expect(currencyOfPhoneNumber(''), 'GNF');
      expect(currencyOfPhoneNumber('+33612345678'), 'GNF');
    });
  });

  group('userCurrencyProvider', () {
    Future<String> currencyFor(String phone) async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) async => testUser(phone: phone),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentUserProvider.future);
      return container.read(userCurrencyProvider);
    }

    test('suit le pays du numéro du compte', () async {
      expect(await currencyFor('+221771234567'), 'XOF');
      expect(await currencyFor('+224621458807'), 'GNF');
    });

    test('GNF tant que le compte n\'est pas chargé ou si déconnecté', () async {
      final loading = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => Future<Null>.delayed(const Duration(days: 1)),
          ),
        ],
      );
      addTearDown(loading.dispose);
      expect(loading.read(userCurrencyProvider), 'GNF');

      final signedOut = ProviderContainer(
        overrides: [currentUserProvider.overrideWith((ref) async => null)],
      );
      addTearDown(signedOut.dispose);
      await signedOut.read(currentUserProvider.future);
      expect(signedOut.read(userCurrencyProvider), 'GNF');
    });
  });

  group('formatMoney', () {
    test('sans devise précisée : GNF, comme avant', () {
      expect(formatMoney(1234567), '1 234 567 GNF');
      expect(formatMoney(0), '0 GNF');
      expect(formatMoney(1234567, withCurrency: false), '1 234 567');
    });

    test('avec une devise', () {
      expect(formatMoney(1234567, currency: 'XOF'), '1 234 567 XOF');
      expect(formatMoney(-500, currency: 'XOF'), '-500 XOF');
    });

    test('withCurrency false ignore la devise', () {
      expect(formatMoney(1500, withCurrency: false, currency: 'XOF'), '1 500');
    });
  });
}
