import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/token_response.dart';

class TokenStorage {
  const TokenStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenTypeKey = 'token_type';
  static const _deviceIdKey = 'gnplay_device_id';

  final FlutterSecureStorage _secureStorage;

  Future<TokenResponse?> read() async {
    final accessToken = await _secureStorage.read(key: _accessTokenKey);
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final tokenType = await _secureStorage.read(key: _tokenTypeKey);

    if (accessToken == null || refreshToken == null) {
      return null;
    }

    return TokenResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType ?? 'bearer',
    );
  }

  Future<void> save(TokenResponse token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token.accessToken);
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: token.refreshToken,
    );
    await _secureStorage.write(key: _tokenTypeKey, value: token.tokenType);
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _tokenTypeKey);
  }

  Future<String> readOrCreateDeviceId() async {
    final existing = await _secureStorage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final suffix = List.generate(
      12,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    final deviceId = 'gnplay_flutter_$suffix';
    await _secureStorage.write(key: _deviceIdKey, value: deviceId);
    return deviceId;
  }
}
