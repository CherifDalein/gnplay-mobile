import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AppNotification>> list(
    String accessToken, {
    int limit = 20,
    int offset = 0,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/v1/notifications',
    ).replace(queryParameters: {'limit': '$limit', 'offset': '$offset'});
    final response = await _client.get(uri, headers: _authHeaders(accessToken));

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
    }
    return const [];
  }

  Future<int> unreadCount(String accessToken) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/notifications/unread-count'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> && decoded['unread_count'] is num) {
      return (decoded['unread_count'] as num).round();
    }
    return 0;
  }

  Future<void> markRead(String accessToken, String notificationId) async {
    final response = await _client.patch(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/v1/notifications/$notificationId/read',
      ),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }
  }

  Future<void> markAllRead(String accessToken) async {
    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/notifications/read-all'),
      headers: _authHeaders(accessToken),
    );

    if (!_isSuccess(response)) {
      throw _apiException(response);
    }
  }

  Map<String, String> _authHeaders(String accessToken) {
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  bool _isSuccess(http.Response response) {
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  ApiException _apiException(http.Response response) {
    return ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
    );
  }

  String _extractErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }
    } on FormatException {
      return 'Impossible de lire la réponse du serveur.';
    }
    return 'La requête a échoué.';
  }
}
