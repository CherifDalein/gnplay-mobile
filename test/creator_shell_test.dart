import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/creator/presentation/screens/creator_dashboard_screen.dart';
import 'package:gnplay/features/earnings/presentation/screens/earnings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('creator dashboard and earnings screens mount', (tester) async {
    await tester.pumpWidget(_wrap(const CreatorDashboardScreen()));
    await tester.pump();
    expect(find.text('SOLDE RETIRABLE'), findsOneWidget);

    await tester.pumpWidget(_wrap(const EarningsScreen()));
    await tester.pump();
    expect(find.text('Portefeuille'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );
}
