import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/auth/presentation/providers/token_storage_provider.dart';
import 'api_client.dart';
import 'authenticated_client.dart';

/// Client HTTP partagé : renouvelle la session sur 401 et rejoue la requête.
/// Les tests remplacent ce provider par un `MockClient`.
final Provider<http.Client> httpClientProvider = Provider<http.Client>((ref) {
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

/// Accès à l'API utilisé par tous les dépôts.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    httpClient: ref.watch(httpClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});
