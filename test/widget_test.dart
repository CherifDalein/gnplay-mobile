import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gnplay/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('mounts the GNPlay app', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GnplayApp()));
    await tester.pump();

    expect(find.byType(GnplayApp), findsOneWidget);
  });
}
