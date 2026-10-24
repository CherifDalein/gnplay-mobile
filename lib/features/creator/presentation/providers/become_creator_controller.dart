import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/repositories.dart';
import '../../../auth/domain/user_read.dart';
import '../../../profile/presentation/providers/current_user_provider.dart';

/// Libéré à la sortie de l'écran : une erreur d'un essai précédent ne doit pas
/// réapparaître à la prochaine ouverture.
final becomeCreatorControllerProvider =
    StateNotifierProvider.autoDispose<
      BecomeCreatorController,
      AsyncValue<UserRead?>
    >((ref) => BecomeCreatorController(ref));

class BecomeCreatorController extends StateNotifier<AsyncValue<UserRead?>> {
  BecomeCreatorController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  /// Active le profil créateur. Renvoie le compte mis à jour, ou null en cas
  /// d'échec (l'erreur est alors dans [state]). Ne navigue pas : une fois le
  /// compte rechargé, le routeur renvoie lui-même le créateur vers l'accueil.
  Future<UserRead?> becomeCreator() async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    // Le routeur peut quitter l'écran dès que le compte est rechargé : on
    // garde le contrôleur en vie le temps de finir la requête.
    final keepAlive = _ref.keepAlive();
    try {
      final user = await _ref.read(profileRepositoryProvider).becomeCreator();
      // Le routeur lit le rôle dans currentUserProvider : tant qu'il n'est pas
      // rechargé, il garde le compte en spectateur. Pas besoin d'invalider le
      // tableau de bord : un spectateur n'en a pas, il se charge à l'arrivée.
      _ref.invalidate(currentUserProvider);
      if (mounted) state = AsyncData(user);
      return user;
    } catch (error, stackTrace) {
      if (mounted) state = AsyncError(error, stackTrace);
      return null;
    } finally {
      keepAlive.close();
    }
  }
}
