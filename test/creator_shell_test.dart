import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/core/network/http_client_provider.dart';
import 'package:gnplay/features/creator/presentation/screens/creator_dashboard_screen.dart';
import 'package:gnplay/features/earnings/presentation/screens/earnings_screen.dart';
import 'package:gnplay/features/auth/domain/user_read.dart';
import 'package:gnplay/features/profile/presentation/providers/current_user_provider.dart';
import 'package:gnplay/features/profile/presentation/providers/notification_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
    });
  });

  testWidgets('dashboard renders real balances, top videos and unread badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const CreatorDashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('SOLDE RETIRABLE'), findsOneWidget);
    expect(find.text('Mariama Diallo'), findsOneWidget);
    expect(find.text('Marché Madina'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // badge notifications non lues
  });

  testWidgets('earnings shows ledger entries from the API', (tester) async {
    await tester.pumpWidget(_wrap(const EarningsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Portefeuille'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Recharge de crédit via DexPay'), findsOneWidget);
    expect(find.text('Recharger'), findsOneWidget);
  });

  testWidgets('dashboard surfaces API failures instead of fake data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const CreatorDashboardScreen(), failing: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger le contenu'), findsOneWidget);
    expect(find.text('Mariama Diallo'), findsNothing);
  });
}

Widget _wrap(Widget child, {bool failing = false}) {
  final client = _fakeClient(failing: failing);
  return ProviderScope(
    overrides: [
      httpClientProvider.overrideWithValue(client),
      currentUserProvider.overrideWith((ref) async => _user),
      unreadNotificationCountProvider.overrideWith((ref) async => 3),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );
}

final _user = UserRead.fromJson(const {
  'id': 'u1',
  'full_name': 'Mariama Diallo',
  'phone_number': '+224621458807',
  'role': 'creator',
  'is_active': true,
  'is_superuser': false,
  'is_verified': true,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
});

http.Client _fakeClient({required bool failing}) {
  http.Response ok(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  return MockClient((request) async {
    if (failing) {
      return http.Response(jsonEncode({'detail': 'Service indisponible'}), 503);
    }
    switch (request.url.path) {
      case '/api/v1/users/me':
        return ok({
          'id': 'u1',
          'full_name': 'Mariama Diallo',
          'phone_number': '+224621458807',
          'role': 'creator',
          'is_active': true,
          'is_superuser': false,
          'is_verified': true,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        });
      case '/api/v1/creators/me/analytics':
        return ok({
          'total_videos': 2,
          'total_views': 100,
          'total_followers': 10,
          'revenue_total': 5000,
          'revenue_this_month': 1000,
          'top_videos': [
            {
              'video_id': 'v1',
              'title': 'Marché Madina',
              'view_count': 90,
              'likes_count': 5,
              'revenue': 4000,
            },
          ],
        });
      case '/api/v1/payouts/balance':
        return ok({
          'withdrawable_balance': 4000,
          'wallet_balance': 6000,
          'total_earnings': 5000,
          'total_withdrawn': 1000,
          'total_refunded': 0,
        });
      case '/api/v1/videos/mine':
        // Comme le vrai backend : la vidéo du top figure aussi dans la liste
        // (une vidéo absente de la liste est une vidéo supprimée).
        return ok([
          {
            'id': 'v1',
            'title': 'Marché Madina',
            'view_count': 90,
            'likes_count': 5,
            'revenue': 4000,
            'price': 1000,
            'duration': 120,
            'status': 'ready',
            'is_published': true,
            'created_at': '2026-02-01T00:00:00Z',
            'updated_at': '2026-02-01T00:00:00Z',
          },
        ]);
      case '/api/v1/wallets/transactions':
        return ok([
          {
            'description': 'Recharge de crédit via DexPay',
            'amount': 2000,
            'direction': 'credit',
            'transaction_type': 'topup',
            'created_at': '2026-08-12T09:41:00Z',
          },
        ]);
    }
    return http.Response(jsonEncode({'detail': 'not found'}), 404);
  });
}
