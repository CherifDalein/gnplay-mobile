import '../../../core/network/api_client.dart';
import '../../creator/domain/payout_provider.dart';
import '../../creator/domain/payout_request.dart';

/// Retraits des gains vers un compte mobile money (réservé aux créateurs).
class PayoutRepository {
  PayoutRepository(this._api);

  final ApiClient _api;

  Future<List<PayoutProviderOption>> listProviders() async {
    final json = await _api.get('/api/v1/payouts/providers');
    return json.asObjectList.map(PayoutProviderOption.fromJson).toList();
  }

  Future<PayoutRequestRecord> request({
    required int amount,
    required String operator,
    String? destinationPhone,
  }) async {
    final json = await _api.post(
      '/api/v1/payouts/request',
      json: {
        'amount': amount,
        'operator': operator,
        if (destinationPhone != null && destinationPhone.trim().isNotEmpty)
          'destination_phone': destinationPhone.trim(),
      },
    );
    return PayoutRequestRecord.fromJson(json.asObject);
  }

  Future<List<PayoutRequestRecord>> list() async {
    final json = await _api.get('/api/v1/payouts');
    return json.asObjectList.map(PayoutRequestRecord.fromJson).toList();
  }

  /// Détail d'un retrait. C'est aussi le seul moyen de rafraîchir son statut :
  /// le backend interroge DexPay à chaque appel.
  Future<PayoutRequestRecord> get(String payoutId) async {
    final json = await _api.get('/api/v1/payouts/$payoutId');
    return PayoutRequestRecord.fromJson(json.asObject);
  }
}
