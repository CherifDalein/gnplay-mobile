import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/repositories.dart';
import '../../../auth/domain/user_read.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

/// Compte connecté (`GET /users/me`), ou null si déconnecté. Rechargé à chaque
/// connexion/déconnexion ; à invalider après une modification du profil ou
/// le passage en créateur.
final currentUserProvider = FutureProvider<UserRead?>((ref) async {
  final isAuthenticated = ref.watch(
    authControllerProvider.select((state) => state.valueOrNull != null),
  );
  if (!isAuthenticated) return null;
  return ref.watch(profileRepositoryProvider).me();
});
