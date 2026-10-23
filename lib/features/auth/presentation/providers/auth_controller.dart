import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/repositories.dart';
import '../../data/auth_repository.dart';
import '../../data/device_repository.dart';
import '../../data/token_storage.dart';
import '../../domain/token_response.dart';
import 'token_storage_provider.dart';

/// État de session : `AsyncLoading` uniquement pendant la restauration au
/// démarrage, puis le jeton courant (ou null si déconnecté).
///
/// La connexion elle-même ne repasse PAS l'état en chargement : le routeur
/// redirige vers l'écran de démarrage pendant un chargement, ce qui détruisait
/// le formulaire de connexion. Son état (chargement, erreur) vit dans
/// `loginControllerProvider`.
final StateNotifierProvider<AuthController, AsyncValue<TokenResponse?>>
authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<TokenResponse?>>((ref) {
      return AuthController(
        ref.watch(authRepositoryProvider),
        ref.watch(tokenStorageProvider),
        ref.watch(deviceRepositoryProvider),
      );
    });

/// Destination à ouvrir juste après une connexion (ex. `/become-creator`
/// après l'inscription). Lue puis effacée par le routeur.
final postAuthRedirectProvider = StateProvider<String?>((ref) => null);

class AuthController extends StateNotifier<AsyncValue<TokenResponse?>> {
  AuthController(this._repository, this._tokenStorage, this._deviceRepository)
    : super(const AsyncLoading()) {
    bootstrap();
  }

  final AuthRepository _repository;
  final TokenStorage _tokenStorage;
  final DeviceRepository _deviceRepository;

  bool get isAuthenticated => state.valueOrNull != null;

  /// Restaure la session enregistrée. Seul un refus explicite du refresh
  /// token (4xx) déconnecte : hors-ligne ou serveur indisponible, on garde la
  /// session locale et les requêtes la renouvelleront plus tard.
  Future<void> bootstrap() async {
    final storedToken = await _tokenStorage.read();
    if (storedToken == null) {
      _set(null);
      return;
    }

    try {
      final refreshed = await _repository.refreshToken(
        refreshToken: storedToken.refreshToken,
      );
      await _tokenStorage.save(refreshed);
      _set(refreshed);
      _registerCurrentDevice();
    } on ApiException catch (error) {
      final rejected =
          error.statusCode != null &&
          error.statusCode! >= 400 &&
          error.statusCode! < 500;
      if (rejected) {
        await _tokenStorage.clear();
        _set(null);
      } else {
        _set(storedToken);
      }
    } catch (_) {
      _set(storedToken);
    }
  }

  /// Connecte l'utilisateur ; lève une [ApiException] en cas d'échec.
  Future<TokenResponse> login({
    required String phoneNumber,
    required String password,
  }) async {
    final token = await _repository.login(
      phoneNumber: phoneNumber,
      password: password,
    );
    await _tokenStorage.save(token);
    _set(token);
    _registerCurrentDevice();
    return token;
  }

  /// Appelé par le client HTTP quand le refresh token est refusé : le stockage
  /// est déjà vidé, il ne reste qu'à repasser à l'état déconnecté (le routeur
  /// renvoie alors vers /login).
  void handleSessionExpired() => _set(null);

  /// Déconnecte cet appareil. La session locale est effacée même si l'appel
  /// au serveur échoue (hors-ligne) : l'utilisateur doit pouvoir se
  /// déconnecter en toutes circonstances.
  Future<void> logout() => _signOut(allDevices: false);

  /// Révoque toutes les sessions du compte.
  Future<void> logoutAllDevices() => _signOut(allDevices: true);

  Future<void> _signOut({required bool allDevices}) async {
    // Le refresh token tourne à chaque renouvellement : le stockage est la
    // seule source à jour.
    final current = await _tokenStorage.read();
    try {
      if (current != null) {
        await _repository.logout(
          refreshToken: allDevices ? null : current.refreshToken,
        );
      }
    } catch (_) {
      // Ignoré : la déconnexion locale prime.
    } finally {
      await _tokenStorage.clear();
      _set(null);
    }
  }

  /// Enregistre cet appareil en arrière-plan : requis pour la lecture vidéo.
  /// Best-effort, la lecture le refait au besoin.
  void _registerCurrentDevice() {
    Future(() async {
      try {
        final deviceId = await _tokenStorage.readOrCreateDeviceId();
        await _deviceRepository.registerDevice(deviceId: deviceId);
      } catch (_) {
        // Ignoré : ne doit pas empêcher la connexion.
      }
    });
  }

  void _set(TokenResponse? token) {
    if (mounted) state = AsyncData(token);
  }
}

/// Chargement / erreur du formulaire de connexion.
final loginControllerProvider =
    StateNotifierProvider.autoDispose<LoginController, AsyncValue<void>>(
      (ref) => LoginController(ref),
    );

class LoginController extends StateNotifier<AsyncValue<void>> {
  LoginController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<bool> login({
    required String phoneNumber,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      await _ref
          .read(authControllerProvider.notifier)
          .login(phoneNumber: phoneNumber, password: password);
      if (mounted) state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      if (mounted) state = AsyncError(error, stackTrace);
      return false;
    }
  }
}
