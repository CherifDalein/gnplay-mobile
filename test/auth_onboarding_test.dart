import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/auth/presentation/screens/login_screen.dart';
import 'package:gnplay/features/auth/presentation/screens/register_screen.dart';
import 'package:gnplay/features/creator/presentation/screens/become_creator_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Aucun accès réseau dans les tests : pas de téléchargement des polices.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('auth onboarding screens mount with design system copy', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pump();
    expect(find.text('Content de vous revoir'), findsOneWidget);

    await tester.pumpWidget(_wrap(const RegisterScreen()));
    await tester.pump();
    expect(find.text('Créer votre compte'), findsOneWidget);

    await tester.pumpWidget(_wrap(const BecomeCreatorScreen()));
    await tester.pump();
    expect(find.text('Passez créateur\nsur GNPlay'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );
}
