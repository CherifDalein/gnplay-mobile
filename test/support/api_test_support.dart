import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gnplay/core/network/api_client.dart';
import 'package:gnplay/features/auth/data/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Session enregistrée (jetons de test) dans le stockage sécurisé simulé.
void seedSession({Map<String, String> extra = const {}}) {
  FlutterSecureStorage.setMockInitialValues({
    'access_token': 'access-token',
    'refresh_token': 'refresh-token',
    ...extra,
  });
}

ApiClient testApi(MockClientHandler handler, {Duration? timeout}) => ApiClient(
  httpClient: MockClient(handler),
  tokenStorage: const TokenStorage(),
  timeout: timeout ?? const Duration(seconds: 30),
  baseUrl: 'https://api.test',
);

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> bodyOf(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;
