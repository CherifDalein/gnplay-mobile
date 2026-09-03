import '../../../shared/utils/json_helpers.dart';

/// Un opérateur de versement mobile money, tel que renvoyé par
/// `GET /payouts/providers` — passthrough direct de la réponse DexPay
/// `GET /payouts-providers` (voir skills/dexpay/references/api-reference.md,
/// section "Payout Providers"), donc les noms de champs sont ceux de DexPay,
/// pas une convention interne à GNPlay.
class PayoutProviderOption {
  const PayoutProviderOption({
    required this.shortName,
    required this.name,
    required this.country,
    required this.currency,
    required this.minAmount,
    required this.maxAmount,
  });

  /// Valeur à envoyer telle quelle dans `operator` de `POST /payouts/request`
  /// (ex. `wave_sn_payout`, `om_sn_payout`, `mtn_ci_payout`).
  final String shortName;
  final String name;
  final String country;
  final String currency;
  final int minAmount;
  final int maxAmount;

  factory PayoutProviderOption.fromJson(Map<String, dynamic> json) {
    return PayoutProviderOption(
      shortName: jsonString(json['provider_short_name'], fallback: ''),
      name: jsonString(json['provider_name'], fallback: ''),
      country: jsonString(json['provider_country'], fallback: ''),
      currency: jsonString(json['provider_currency'], fallback: ''),
      minAmount: jsonInt(json['min_amount']),
      maxAmount: jsonInt(json['max_amount']),
    );
  }
}
