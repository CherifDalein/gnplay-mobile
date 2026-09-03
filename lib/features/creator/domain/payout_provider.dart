import '../../../shared/utils/json_helpers.dart';

class PayoutProviderOption {
  const PayoutProviderOption({
    required this.id,
    required this.name,
    required this.countryIso,
    required this.minAmount,
    required this.maxAmount,
  });

  final String id;
  final String name;
  final String countryIso;
  final int minAmount;
  final int maxAmount;

  factory PayoutProviderOption.fromJson(Map<String, dynamic> json) {
    return PayoutProviderOption(
      id: jsonString(json['id'], fallback: ''),
      name: jsonString(json['name'], fallback: ''),
      countryIso: jsonString(json['country_iso'], fallback: ''),
      minAmount: jsonInt(json['min_amount']),
      maxAmount: jsonInt(json['max_amount']),
    );
  }
}
