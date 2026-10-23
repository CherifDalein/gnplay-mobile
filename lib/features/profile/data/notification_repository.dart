import '../../../core/network/api_client.dart';
import '../../../shared/utils/json_helpers.dart';
import '../domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> list({int limit = 100, int offset = 0}) async {
    final json = await _api.get(
      '/api/v1/notifications',
      query: {'limit': limit, 'offset': offset},
    );
    return json.asObjectList.map(AppNotification.fromJson).toList();
  }

  Future<int> unreadCount() async {
    final json = await _api.get('/api/v1/notifications/unread-count');
    return jsonInt(json.asObject['unread_count']);
  }

  Future<void> markRead(String notificationId) =>
      _api.patch('/api/v1/notifications/$notificationId/read');

  Future<void> markAllRead() => _api.patch('/api/v1/notifications/read-all');
}
