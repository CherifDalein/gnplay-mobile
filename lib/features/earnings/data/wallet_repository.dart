import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/utils/json_helpers.dart';
import '../../creator/domain/payout_balances.dart';
import '../../creator/domain/topup.dart';
import '../../creator/domain/wallet_ledger_entry.dart';

/// Portefeuille : soldes, historique des mouvements et recharge.
class WalletRepository {
  WalletRepository(this._api);

  final ApiClient _api;

  /// Solde du portefeuille et solde retirable (`GET /payouts/balance`, le
  /// second ne compte que les gains nets de ventes).
  Future<PayoutBalances> loadBalances() async {
    final json = (await _api.get('/api/v1/payouts/balance')).asObject;
    return PayoutBalances(
      walletBalance: jsonInt(json['wallet_balance']),
      withdrawableBalance: jsonInt(json['withdrawable_balance']),
    );
  }

  Future<List<WalletLedgerEntry>> loadLedger() async {
    final json = await _api.get('/api/v1/wallets/transactions');
    return json.asObjectList.map(WalletLedgerEntry.fromJson).toList();
  }

  /// Recharge : renvoie l'URL de paiement DexPay à ouvrir et la référence à
  /// suivre via [getTopupStatus] (le crédit arrive par webhook). `client:
  /// mobile` : après le paiement, DexPay affiche une page « revenez dans
  /// l'application » au lieu de rediriger vers le site web.
  Future<TopupCheckout> initiateTopup(int amount) async {
    final json = (await _api.post(
      '/api/v1/payments/topup/initiate',
      json: {'amount': amount, 'client': 'mobile'},
    )).asObject;
    final url = jsonNullableString(json['payment_url']);
    final reference = jsonNullableString(json['reference']);
    if (url == null || reference == null) {
      throw const ApiException(
        'Lien de paiement indisponible.',
        kind: ApiErrorKind.unexpected,
      );
    }
    return TopupCheckout(paymentUrl: url, reference: reference);
  }

  Future<TopupStatus> getTopupStatus(String reference) async {
    final json = await _api.get('/api/v1/payments/topup/status/$reference');
    return TopupStatus.parse(jsonNullableString(json.asObject['status']));
  }
}
