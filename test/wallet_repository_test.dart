import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/network/api_exception.dart';
import 'package:gnplay/features/creator/domain/topup.dart';
import 'package:gnplay/features/earnings/data/payout_repository.dart';
import 'package:gnplay/features/earnings/data/wallet_repository.dart';

import 'support/api_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(seedSession);

  test('soldes lus depuis /payouts/balance', () async {
    final repository = WalletRepository(
      testApi(
        (_) async => jsonResponse({
          'withdrawable_balance': 4000,
          'wallet_balance': 6000,
          'total_earnings': 5000,
          'total_withdrawn': 1000,
          'total_refunded': 0,
        }),
      ),
    );
    final balances = await repository.loadBalances();
    expect(balances.walletBalance, 6000);
    expect(balances.withdrawableBalance, 4000);
  });

  test('recharge : URL de paiement, référence et statut', () async {
    final repository = WalletRepository(
      testApi((request) async {
        if (request.url.path == '/api/v1/payments/topup/initiate') {
          expect(bodyOf(request), {'amount': 25000, 'client': 'mobile'});
          return jsonResponse({
            'payment_url': 'https://pay.test/checkout/1',
            'reference': 'topup_abc',
          });
        }
        expect(request.url.path, '/api/v1/payments/topup/status/topup_abc');
        return jsonResponse({'status': 'completed', 'amount': 25000});
      }),
    );

    final checkout = await repository.initiateTopup(25000);
    expect(checkout.paymentUrl, 'https://pay.test/checkout/1');
    expect(
      await repository.getTopupStatus(checkout.reference),
      TopupStatus.completed,
    );
  });

  test('recharge refusée : message du serveur', () async {
    final repository = WalletRepository(
      testApi((_) async => jsonResponse({'detail': 'Montant invalide'}, 400)),
    );
    expect(
      repository.initiateTopup(10),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Montant invalide',
        ),
      ),
    );
  });

  test('retraits : opérateurs et historique', () async {
    final repository = PayoutRepository(
      testApi((request) async {
        if (request.url.path == '/api/v1/payouts/providers') {
          return jsonResponse([
            {
              'provider_short_name': 'orange_gn',
              'provider_name': 'Orange Money',
            },
          ]);
        }
        expect(request.url.path, '/api/v1/payouts');
        return jsonResponse(<Object>[]);
      }),
    );
    expect(await repository.listProviders(), hasLength(1));
    expect(await repository.list(), isEmpty);
  });
}
