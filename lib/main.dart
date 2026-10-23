import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // `video_player` n'a pas d'implémentation Linux native : sans ceci,
  // VideoPlayerController.initialize() lève UnimplementedError sur le bureau
  // Linux. Android/iOS/macOS/web continuent d'utiliser leur plugin natif.
  VideoPlayerMediaKit.ensureInitialized(linux: true);
  runApp(const ProviderScope(child: GnplayApp()));
}

class GnplayApp extends ConsumerWidget {
  const GnplayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GNPlay Créateur',
      // Menus système (copier/coller, sélecteur de date…) en français.
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
