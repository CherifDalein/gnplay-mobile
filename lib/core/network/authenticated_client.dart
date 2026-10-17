import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/auth/data/token_storage.dart';
import '../../features/auth/domain/token_response.dart';
import 'api_config.dart';

/// Client HTTP qui garde la session ouverte : sur une réponse 401 il renouvelle
/// le jeton d'accès (`POST /auth/refresh-token`) puis rejoue la requête une
/// fois, comme l'intercepteur axios du frontend web.
///
/// - Seules les requêtes portant `Authorization: Bearer …` sont concernées
///   (login, URL présignées R2, etc. passent telles quelles).
/// - Le jeton envoyé est toujours le plus récent du [TokenStorage], même si
///   l'appelant en a transmis un plus ancien.
/// - Le refresh token est **rotatif** côté backend : deux refresh concurrents
///   révoqueraient la session. Les renouvellements sont donc sérialisés
///   (un seul vol à la fois, les autres requêtes attendent son résultat).
/// - Si le refresh token est refusé, la session est vidée et
///   [onSessionExpired] est appelé (retour à l'écran de connexion).
class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    required TokenStorage tokenStorage,
    http.Client? inner,
    this.onSessionExpired,
  }) : _tokenStorage = tokenStorage,
       _inner = inner ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _inner;
  final void Function()? onSessionExpired;

  Future<String?>? _inFlightRefresh;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_hasBearer(request)) {
      return _inner.send(request);
    }

    final stored = await _tokenStorage.read();
    final usedToken = stored?.accessToken ?? _bearerOf(request)!;
    final first = await _inner.send(_withToken(request, usedToken));
    if (first.statusCode != 401 || request is! http.Request) {
      return first;
    }

    // Les requêtes en flux (multipart) ne peuvent pas être rejouées.
    final unauthorized = await http.Response.fromStream(first);
    final refreshed = await _refreshAccessToken(staleToken: usedToken);
    if (refreshed == null) {
      return _toStreamed(unauthorized, request);
    }
    return _inner.send(_withToken(request, refreshed));
  }

  /// Renvoie le nouveau jeton d'accès, ou null si le renouvellement est
  /// impossible (session expirée ou réseau indisponible).
  Future<String?> _refreshAccessToken({required String staleToken}) {
    final running = _inFlightRefresh;
    if (running != null) {
      return running;
    }
    final flight = _doRefresh(staleToken).whenComplete(() {
      _inFlightRefresh = null;
    });
    _inFlightRefresh = flight;
    return flight;
  }

  Future<String?> _doRefresh(String staleToken) async {
    final stored = await _tokenStorage.read();
    if (stored == null) {
      return null;
    }
    // Un autre appel a déjà renouvelé le jeton entre-temps : on le réutilise.
    if (stored.accessToken != staleToken) {
      return stored.accessToken;
    }

    final http.Response response;
    try {
      response = await _inner.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/refresh-token'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': stored.refreshToken}),
      );
    } catch (_) {
      return null; // Réseau KO : on ne déconnecte pas l'utilisateur.
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final token = TokenResponse.fromJson(decoded as Map<String, dynamic>);
        await _tokenStorage.save(token);
        return token.accessToken;
      } catch (_) {
        return null;
      }
    }

    if (response.statusCode >= 400 && response.statusCode < 500) {
      await _tokenStorage.clear();
      onSessionExpired?.call();
    }
    return null;
  }

  bool _hasBearer(http.BaseRequest request) => _bearerOf(request) != null;

  String? _bearerOf(http.BaseRequest request) {
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == 'authorization' &&
          entry.value.startsWith('Bearer ')) {
        return entry.value.substring(7);
      }
    }
    return null;
  }

  http.BaseRequest _withToken(http.BaseRequest original, String token) {
    final headers = {
      for (final entry in original.headers.entries)
        if (entry.key.toLowerCase() != 'authorization') entry.key: entry.value,
      'Authorization': 'Bearer $token',
    };

    if (original is http.Request) {
      return http.Request(original.method, original.url)
        ..headers.addAll(headers)
        ..bodyBytes = original.bodyBytes
        ..followRedirects = original.followRedirects
        ..maxRedirects = original.maxRedirects
        ..persistentConnection = original.persistentConnection;
    }

    // Requête non rejouable (multipart…) : on ne fait que remplacer l'en-tête.
    original.headers
      ..removeWhere((key, _) => key.toLowerCase() == 'authorization')
      ..addAll({'Authorization': 'Bearer $token'});
    return original;
  }

  http.StreamedResponse _toStreamed(
    http.Response response,
    http.BaseRequest request,
  ) {
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      request: request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
