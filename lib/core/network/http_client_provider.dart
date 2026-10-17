import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/providers/token_storage_provider.dart';
import 'authenticated_client.dart';

/// Client HTTP partagé par tous les dépôts nécessitant une session.
final Provider<AuthenticatedClient> authenticatedClientProvider =
    Provider<AuthenticatedClient>((ref) {
      final client = AuthenticatedClient(
        tokenStorage: ref.watch(tokenStorageProvider),
        // Lecture paresseuse : évite la dépendance circulaire avec le
        // contrôleur d'authentification, qui dépend lui-même des dépôts.
        onSessionExpired: () =>
            ref.read(authControllerProvider.notifier).handleSessionExpired(),
      );
      ref.onDispose(client.close);
      return client;
    });
