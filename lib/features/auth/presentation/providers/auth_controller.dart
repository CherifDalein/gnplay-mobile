import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../data/device_repository.dart';
import '../../data/token_storage.dart';
import '../../domain/token_response.dart';
import 'auth_repository_provider.dart';
import 'device_repository_provider.dart';
import 'token_storage_provider.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<TokenResponse?>>((ref) {
      return AuthController(
        ref.watch(authRepositoryProvider),
        ref.watch(tokenStorageProvider),
        ref.watch(deviceRepositoryProvider),
      );
    });

final postAuthRedirectProvider = StateProvider<String?>((ref) => null);

class AuthController extends StateNotifier<AsyncValue<TokenResponse?>> {
  AuthController(this._repository, this._tokenStorage, this._deviceRepository)
    : super(const AsyncLoading()) {
    bootstrap();
  }

  final AuthRepository _repository;
  final TokenStorage _tokenStorage;
  final DeviceRepository _deviceRepository;

  Future<void> bootstrap() async {
    try {
      final storedToken = await _tokenStorage.read();
      if (storedToken == null) {
        state = const AsyncData(null);
        return;
      }

      final refreshedToken = await _repository.refreshToken(
        refreshToken: storedToken.refreshToken,
      );
      await _tokenStorage.save(refreshedToken);
      state = AsyncData(refreshedToken);
      _registerCurrentDevice(refreshedToken.accessToken);
    } catch (_) {
      await _tokenStorage.clear();
      state = const AsyncData(null);
    }
  }

  Future<TokenResponse?> login({
    required String phoneNumber,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final token = await _repository.login(
        phoneNumber: phoneNumber,
        password: password,
      );
      await _tokenStorage.save(token);
      state = AsyncData(token);
      _registerCurrentDevice(token.accessToken);
      return token;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<TokenResponse?> loginAfterRegistration({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final token = await _repository.login(
        phoneNumber: phoneNumber,
        password: password,
      );
      await _tokenStorage.save(token);
      state = AsyncData(token);
      _registerCurrentDevice(token.accessToken);
      return token;
    } catch (_) {
      return null;
    }
  }

  /// Enregistre cet appareil auprès du backend en arrière-plan : requis pour
  /// que la lecture vidéo (sessions HLS) et l'écran Appareils fonctionnent.
  /// Best-effort — une limite de 3 appareils atteinte ne doit pas bloquer la
  /// connexion, l'utilisateur la verra sur l'écran Appareils.
  void _registerCurrentDevice(String accessToken) {
    Future(() async {
      try {
        final deviceId = await _tokenStorage.readOrCreateDeviceId();
        await _deviceRepository.registerDevice(
          accessToken: accessToken,
          deviceId: deviceId,
        );
      } catch (_) {
        // Ignoré : la limite de 3 appareils (ou une panne réseau) ne doit
        // pas empêcher la connexion.
      }
    });
  }

  Future<void> logout() async {
    final currentToken = state.valueOrNull ?? await _tokenStorage.read();
    state = const AsyncLoading();

    try {
      if (currentToken != null) {
        await _repository.logout(
          accessToken: currentToken.accessToken,
          refreshToken: currentToken.refreshToken,
        );
      }
    } finally {
      await _tokenStorage.clear();
      state = const AsyncData(null);
    }
  }

  Future<void> logoutAllDevices() async {
    final currentToken = state.valueOrNull ?? await _tokenStorage.read();
    state = const AsyncLoading();

    try {
      if (currentToken != null) {
        await _repository.logout(accessToken: currentToken.accessToken);
      }
    } finally {
      await _tokenStorage.clear();
      state = const AsyncData(null);
    }
  }
}
