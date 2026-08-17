import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/creator_dashboard.dart';
import 'creator_repository_provider.dart';

final creatorDashboardProvider = FutureProvider.autoDispose<CreatorDashboard>((
  ref,
) async {
  return ref.watch(creatorRepositoryProvider).loadDashboard();
});
