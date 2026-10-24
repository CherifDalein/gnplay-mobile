import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/presentation/providers/current_user_provider.dart';
import 'countries.dart';

/// Devise du pays du numéro [e164] (`+221…` → XOF). Les montants du backend
/// sont des entiers dans la devise du pays du compte ; un numéro inconnu ou
/// absent retombe sur celle du pays par défaut (GNF).
String currencyOfPhoneNumber(String? e164) {
  final country = e164 == null ? null : countryOfE164(e164);
  return (country ?? defaultCountry).currency;
}

/// Devise d'affichage des montants du compte connecté. On la déduit de
/// l'indicatif du téléphone (le backend n'expose pas de champ devise) ; elle
/// reste stable pendant un rechargement du compte grâce au `select`.
final userCurrencyProvider = Provider<String>((ref) {
  final phone = ref.watch(
    currentUserProvider.select((user) => user.valueOrNull?.phoneNumber),
  );
  return currencyOfPhoneNumber(phone);
});
