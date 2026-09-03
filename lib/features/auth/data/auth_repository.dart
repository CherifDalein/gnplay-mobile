import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../domain/register_request.dart';
import '../domain/token_response.dart';
import '../domain/user_read.dart';

class AuthRepository {
  AuthRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<TokenResponse> login({
    required String phoneNumber,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/login');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'password',
        'username': phoneNumber,
        'password': password,
        'scope': '',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return TokenResponse.fromJson(_decodeObject(response.body));
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<TokenResponse> refreshToken({required String refreshToken}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/refresh-token');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return TokenResponse.fromJson(_decodeObject(response.body));
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  /// [refreshToken] null révoque toutes les sessions de l'utilisateur ;
  /// fourni, ne révoque que cette session (cet appareil).
  Future<void> logout({
    required String accessToken,
    String? refreshToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/logout');
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode == 204) {
      return;
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<UserRead> myInfo({required String accessToken}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me');
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return UserRead.fromJson(_decodeObject(response.body));
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<UserRead> updateProfile({
    required String accessToken,
    String? fullName,
    String? pageName,
    String? bio,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/users/me');
    final response = await _client.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (fullName != null) 'full_name': fullName,
        if (pageName != null) 'page_name': pageName,
        if (bio != null) 'bio': bio,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return UserRead.fromJson(_decodeObject(response.body));
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<String> uploadProfilePicture({
    required String accessToken,
    required File file,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/users/me/profile-picture',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = _decodeObject(response.body);
      final url = decoded['profile_picture_url'];
      if (url is String && url.isNotEmpty) {
        return url;
      }
      throw const ApiException('Réponse inattendue du serveur.');
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<UserRead> becomeCreator({required String accessToken}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/users/me/become-creator',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return UserRead.fromJson(_decodeObject(response.body));
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<void> requestRegisterOtp({required String phoneNumber}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/request-otp');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phoneNumber, 'otp_type': 'register'}),
    );

    if (response.statusCode == 201) {
      return;
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<void> verifyRegisterOtp({
    required String phoneNumber,
    required String code,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/verify-otp');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'otp_type': 'register',
        'code': code,
      }),
    );

    if (response.statusCode == 204) {
      return;
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<void> requestPasswordReset({required String phoneNumber}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/auth/request-password-reset',
    );
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'otp_type': 'reset_password',
      }),
    );

    if (response.statusCode == 202) {
      return;
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<void> resetPassword({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/reset-password');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'otp_type': 'reset_password',
        'code': code,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode == 204) {
      return;
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Future<UserRead> register(RegisterRequest request) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/register');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return UserRead.fromJson(_decodeObject(response.body));
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('Reponse API invalide.');
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map<String, dynamic>) {
            final message = first['msg'];
            if (message is String && message.isNotEmpty) {
              return message;
            }
          }
        }
      }
    } on FormatException {
      return 'Impossible de lire la reponse du serveur.';
    }

    return 'La creation du compte a echoue.';
  }
}
