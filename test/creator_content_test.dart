import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnplay/core/theme/app_theme.dart';
import 'package:gnplay/features/publish/presentation/screens/publish_screen.dart';
import 'package:gnplay/features/series/presentation/screens/series_screen.dart';
import 'package:gnplay/features/videos/presentation/screens/video_detail_screen.dart';
import 'package:gnplay/features/videos/presentation/screens/video_stats_screen.dart';
import 'package:gnplay/features/videos/presentation/screens/videos_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('creator content screens mount with offline samples', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const VideosScreen()));
    await tester.pump();
    expect(find.text('Mon contenu'), findsOneWidget);
    expect(find.text('Nuits de Conakry — épisode 3'), findsOneWidget);

    await tester.pumpWidget(_wrap(const PublishScreen()));
    await tester.pump();
    expect(find.text('Nouvelle vidéo'), findsOneWidget);
    expect(find.text('Choisir une vidéo'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(const VideoDetailScreen(videoId: 'sample-1')),
    );
    await tester.pump();
    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Nuits de Conakry — épisode 3'), findsOneWidget);

    await tester.pumpWidget(_wrap(const VideoStatsScreen(videoId: 'sample-1')));
    await tester.pump();
    expect(find.text('Statistiques'), findsOneWidget);
    expect(find.text('taux de complétion moyen'), findsOneWidget);

    await tester.pumpWidget(_wrap(const SeriesScreen(seriesId: 'series-1')));
    await tester.pump();
    expect(find.text('Mode de vente'), findsOneWidget);
    expect(find.text('Épisodes'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );
}
