import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/http_client_provider.dart';
import '../../data/auth_repository.dart';

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      return AuthRepository(client: ref.watch(authenticatedClientProvider));
    });
