import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/repositories.dart';
import '../../domain/app_notification.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) {
    return ref.watch(notificationRepositoryProvider).list();
  },
);

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(notificationRepositoryProvider).unreadCount();
});

final notificationMutationControllerProvider =
    StateNotifierProvider.autoDispose<
      NotificationMutationController,
      AsyncValue<void>
    >((ref) => NotificationMutationController(ref));

class NotificationMutationController extends StateNotifier<AsyncValue<void>> {
  NotificationMutationController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> markRead(String notificationId) => _run(
    () => _ref.read(notificationRepositoryProvider).markRead(notificationId),
  );

  Future<void> markAllRead() =>
      _run(() => _ref.read(notificationRepositoryProvider).markAllRead());

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await action();
      _ref.invalidate(notificationsProvider);
      _ref.invalidate(unreadNotificationCountProvider);
    });
    if (mounted) state = result;
  }
}
