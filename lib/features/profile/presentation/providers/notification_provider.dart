import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/http_client_provider.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/notification_repository.dart';
import '../../domain/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(client: ref.watch(authenticatedClientProvider));
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    final repository = ref.watch(notificationRepositoryProvider);
    final accessToken = await _requireAccessToken(ref);
    return repository.list(accessToken, limit: 100);
  },
);

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final repository = ref.watch(notificationRepositoryProvider);
  final accessToken = await _requireAccessToken(ref);
  return repository.unreadCount(accessToken);
});

final notificationMutationControllerProvider =
    StateNotifierProvider.autoDispose<
      NotificationMutationController,
      AsyncValue<void>
    >((ref) => NotificationMutationController(ref));

class NotificationMutationController extends StateNotifier<AsyncValue<void>> {
  NotificationMutationController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> markRead(String notificationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = _ref.read(notificationRepositoryProvider);
      final accessToken = await _requireAccessToken(_ref);
      await repository.markRead(accessToken, notificationId);
      _invalidate();
    });
  }

  Future<void> markAllRead() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = _ref.read(notificationRepositoryProvider);
      final accessToken = await _requireAccessToken(_ref);
      await repository.markAllRead(accessToken);
      _invalidate();
    });
  }

  void _invalidate() {
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(unreadNotificationCountProvider);
  }
}

Future<String> _requireAccessToken(Ref ref) async {
  final token = ref.read(authControllerProvider).valueOrNull;
  if (token == null) {
    throw const ApiException('Vous devez vous connecter.');
  }
  return token.accessToken;
}
