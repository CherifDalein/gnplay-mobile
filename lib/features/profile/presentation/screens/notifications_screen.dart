import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../domain/app_notification.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(notificationMutationControllerProvider, (
      previous,
      next,
    ) {
      next.whenOrNull(
        error: (error, stackTrace) =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.danger,
                content: Text(
                  '$error',
                  style: AppTextStyles.caption.copyWith(color: AppColors.text1),
                ),
              ),
            ),
      );
    });

    final notificationsState = ref.watch(notificationsProvider);
    final notifications =
        notificationsState.valueOrNull ?? const <AppNotification>[];
    final mutationState = ref.watch(notificationMutationControllerProvider);
    final hasUnread = notifications.any((n) => n.isUnread);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: RefreshIndicator(
            color: AppColors.accent500,
            backgroundColor: AppColors.surface1,
            onRefresh: () async {
              final future = ref.refresh(notificationsProvider.future);
              await future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Header(onBack: () => _goBack(context)),
                    ),
                    if (hasUnread)
                      TextButton(
                        onPressed: mutationState.isLoading
                            ? null
                            : () => ref
                                  .read(
                                    notificationMutationControllerProvider
                                        .notifier,
                                  )
                                  .markAllRead(),
                        child: Text(
                          'Tout marquer comme lu',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent500,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                  ],
                ),
                if (notificationsState.isLoading && notifications.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent500,
                      ),
                    ),
                  )
                else if (notifications.isEmpty)
                  const _EmptyState()
                else
                  ...notifications.map(
                    (notification) => _NotificationRow(
                      notification: notification,
                      onTap: () {
                        if (notification.isUnread) {
                          ref
                              .read(
                                notificationMutationControllerProvider.notifier,
                              )
                              .markRead(notification.id);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/profile');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.text2, size: 20),
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Notifications',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.text1,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.surface1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: notification.isUnread
                      ? AppColors.accent500
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.text1,
                      fontSize: 13,
                    ),
                  ),
                  if ((notification.body ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.body!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.text3,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    _relativeLabel(notification.createdAt),
                    style: AppTextStyles.micro.copyWith(color: AppColors.text3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeLabel(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) {
      return 'à l’instant';
    }
    if (diff.inMinutes < 60) {
      return 'il y a ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'il y a ${diff.inHours} h';
    }
    return 'il y a ${diff.inDays} j';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border1),
            ),
            child: const Icon(
              Icons.notifications_none,
              color: AppColors.border1,
              size: 26,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Aucune notification pour le moment',
            style: AppTextStyles.label.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Vos alertes apparaîtront ici.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.text3),
            ),
          ),
        ],
      ),
    );
  }
}
