import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException, SocketException;

import 'package:http/http.dart' as http;

import '../../features/auth/data/token_storage.dart';
import 'api_config.dart';
import 'api_error_messages.dart';
import 'api_exception.dart';

/// Point d'entrée unique vers l'API GNPlay (`/api/v1/...`).
///
/// Centralise ce que chaque dépôt réimplémentait : URL de base, en-têtes,
/// jeton d'accès, délai maximal, décodage UTF-8 et conversion des erreurs en
/// [ApiException] lisibles. Le renouvellement du jeton sur 401 est assuré par
/// le client HTTP sous-jacent (`AuthenticatedClient`), qui peut rejouer les
/// requêtes construites ici (toujours des `http.Request`, jamais des flux).
class ApiClient {
  ApiClient({
    required http.Client httpClient,
    required TokenStorage tokenStorage,
    this.timeout = const Duration(seconds: 30),
    String? baseUrl,
  }) : _http = httpClient,
       _tokenStorage = tokenStorage,
       _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _http;
  final TokenStorage _tokenStorage;
  final String _baseUrl;
  final Duration timeout;

  /// URL absolue d'un chemin d'API (`/api/v1/...`).
  Uri uri(String path, [Map<String, Object?>? query]) {
    final cleanQuery = <String, String>{
      for (final entry in (query ?? const {}).entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };
    final base = Uri.parse('$_baseUrl$path');
    return cleanQuery.isEmpty
        ? base
        : base.replace(queryParameters: cleanQuery);
  }

  Future<Object?> get(
    String path, {
    Map<String, Object?>? query,
    bool authenticated = true,
  }) => _send('GET', path, query: query, authenticated: authenticated);

  Future<Object?> post(
    String path, {
    Object? json,
    Map<String, String>? form,
    Map<String, Object?>? query,
    bool authenticated = true,
  }) => _send(
    'POST',
    path,
    json: json,
    form: form,
    query: query,
    authenticated: authenticated,
  );

  Future<Object?> patch(
    String path, {
    Object? json,
    bool authenticated = true,
  }) => _send('PATCH', path, json: json, authenticated: authenticated);

  Future<Object?> delete(String path, {bool authenticated = true}) =>
      _send('DELETE', path, authenticated: authenticated);

  /// Envoi d'un fichier en `multipart/form-data` (non rejouable après un
  /// renouvellement de session : le jeton est donc lu juste avant l'envoi).
  Future<Object?> postFile(
    String path, {
    required String field,
    required String filePath,
    Duration? timeout,
  }) async {
    final request = http.MultipartRequest('POST', uri(path))
      ..headers.addAll(await _headers(authenticated: true, json: false))
      ..files.add(await http.MultipartFile.fromPath(field, filePath));
    return _decode(
      await _execute(request, timeout ?? const Duration(minutes: 2)),
    );
  }

  /// PUT brut vers une URL externe pré-signée (stockage R2) : aucun en-tête
  /// d'authentification, la signature est dans l'URL. Renvoie la réponse
  /// brute (l'appelant a besoin de l'en-tête `ETag`).
  Future<http.Response> putExternal(
    String url,
    List<int> bytes, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final request = http.Request('PUT', Uri.parse(url))..bodyBytes = bytes;
    final response = await _execute(request, timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'L’envoi d’une partie du fichier a échoué.',
        statusCode: response.statusCode,
      );
    }
    return response;
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? json,
    Map<String, String>? form,
    Map<String, Object?>? query,
    required bool authenticated,
  }) async {
    final request = http.Request(method, uri(path, query))
      ..headers.addAll(
        await _headers(authenticated: authenticated, json: form == null),
      );
    if (form != null) {
      request.bodyFields = form;
    } else if (json != null) {
      request.body = jsonEncode(json);
    }
    return _decode(await _execute(request, timeout));
  }

  Future<Map<String, String>> _headers({
    required bool authenticated,
    required bool json,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json; charset=utf-8',
    };
    if (authenticated) {
      final token = await _tokenStorage.read();
      if (token == null) {
        throw const ApiException(
          'Vous devez vous connecter.',
          kind: ApiErrorKind.unauthorized,
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer ${token.accessToken}';
    }
    return headers;
  }

  Future<http.Response> _execute(
    http.BaseRequest request,
    Duration limit,
  ) async {
    try {
      final streamed = await _http.send(request).timeout(limit);
      return await http.Response.fromStream(streamed).timeout(limit);
    } on TimeoutException {
      throw ApiException(
        ApiErrorMessages.forKind(ApiErrorKind.timeout),
        kind: ApiErrorKind.timeout,
      );
    } on SocketException {
      throw _networkError();
    } on HandshakeException {
      throw _networkError();
    } on http.ClientException {
      throw _networkError();
    }
  }

  ApiException _networkError() => ApiException(
    ApiErrorMessages.forKind(ApiErrorKind.network),
    kind: ApiErrorKind.network,
  );

  Object? _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    final ok = response.statusCode >= 200 && response.statusCode < 300;

    Object? decoded;
    if (text.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        if (ok) {
          throw ApiException(
            ApiErrorMessages.forKind(ApiErrorKind.unexpected),
            statusCode: response.statusCode,
            kind: ApiErrorKind.unexpected,
          );
        }
      }
    }

    if (ok) return decoded;

    final detail = _detailOf(decoded);
    throw ApiException(
      ApiErrorMessages.forServer(detail, response.statusCode),
      statusCode: response.statusCode,
      serverDetail: detail,
    );
  }

  /// `detail` FastAPI (texte, ou liste d'erreurs de validation 422) ou
  /// `error` (réponses 429 de slowapi).
  static String? _detailOf(Object? decoded) {
    if (decoded is! Map) return null;
    final detail = decoded['detail'] ?? decoded['error'] ?? decoded['message'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) return first['msg'] as String;
    }
    return null;
  }
}

/// Lecture défensive des réponses JSON.
extension ApiJson on Object? {
  Map<String, dynamic> get asObject {
    final value = this;
    if (value is Map<String, dynamic>) return value;
    throw const ApiException(
      'Réponse inattendue du serveur.',
      kind: ApiErrorKind.unexpected,
    );
  }

  /// Liste d'objets ; accepte aussi `{items|results|data: [...]}`.
  List<Map<String, dynamic>> get asObjectList {
    var value = this;
    if (value is Map) {
      value = value['items'] ?? value['results'] ?? value['data'];
    }
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    return const [];
  }
}
