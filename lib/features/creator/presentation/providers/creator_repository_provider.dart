import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/http_client_provider.dart';
import '../../../auth/presentation/providers/token_storage_provider.dart';
import '../../data/creator_repository.dart';

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  return CreatorRepository(
    ref.watch(tokenStorageProvider),
    client: ref.watch(authenticatedClientProvider),
  );
});
