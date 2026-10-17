import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../auth/domain/device.dart';
import '../providers/device_provider.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(deviceRevokeControllerProvider, (
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

    final devicesState = ref.watch(devicesProvider);
    final devices = devicesState.valueOrNull ?? const <Device>[];
    final currentDeviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    final revokeState = ref.watch(deviceRevokeControllerProvider);
    final activeCount = devices.where((d) => d.isActive).length;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: RefreshIndicator(
            color: AppColors.accent500,
            backgroundColor: AppColors.surface1,
            onRefresh: () async {
              final future = ref.refresh(devicesProvider.future);
              await future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
              children: [
                _Header(onBack: () => _goBack(context)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      '$activeCount/3 appareils actifs',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.text2,
                        fontSize: 12.5,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(3, (index) {
                        final filled = index < activeCount;
                        return Padding(
                          padding: EdgeInsets.only(left: index == 0 ? 0 : 5),
                          child: Container(
                            width: 22,
                            height: 5,
                            decoration: BoxDecoration(
                              color: filled
                                  ? AppColors.accent500
                                  : AppColors.border1,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                if (activeCount >= 3) ...[
                  const SizedBox(height: 12),
                  GnCard(
                    radius: 12,
                    backgroundColor: AppColors.warningBg,
                    borderColor: AppColors.warning.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    child: Text(
                      'Limite atteinte. Révoquez un appareil avant d’en connecter un nouveau.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (devicesState.isLoading && devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent500,
                      ),
                    ),
                  )
                else if (devices.isEmpty)
                  GnCard(
                    backgroundColor: AppColors.surface2,
                    child: Column(
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          'Aucun appareil enregistré',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.text1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Reconnectez-vous pour enregistrer cet appareil.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.text3,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  )
                else
                  ...devices.map(
                    (device) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DeviceCard(
                        device: device,
                        isCurrent: device.deviceId == currentDeviceId,
                        isLoading: revokeState.isLoading,
                        onRevoke: () => ref
                            .read(deviceRevokeControllerProvider.notifier)
                            .revoke(device.id),
                      ),
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
          'Appareils connectés',
          style: AppTextStyles.heading.copyWith(
            color: AppColors.text1,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.isCurrent,
    required this.isLoading,
    required this.onRevoke,
  });

  final Device device;
  final bool isCurrent;
  final bool isLoading;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      radius: 14,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bgApp,
              border: Border.all(color: AppColors.border1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.phone_iphone,
              color: AppColors.text2,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.deviceName?.trim().isNotEmpty == true
                            ? device.deviceName!
                            : (device.platform ?? 'Appareil'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.text1,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 7),
                      const GnStatusPill(
                        label: 'CET APPAREIL',
                        tone: GnStatusTone.success,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _metaLabel(device),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text3,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            TextButton(
              onPressed: isLoading ? null : onRevoke,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Text(
                'Révoquer',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _metaLabel(Device device) {
    final platform = device.platform;
    final lastSeen = device.lastSeenAt;
    if (platform == null && lastSeen == null) {
      return 'Dernière activité inconnue';
    }
    final seenLabel = lastSeen == null ? '' : ' · ${_relativeLabel(lastSeen)}';
    return '${platform ?? 'Appareil'}$seenLabel';
  }

  String _relativeLabel(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 2) {
      return 'actif maintenant';
    }
    if (diff.inHours < 1) {
      return 'il y a ${diff.inMinutes} min';
    }
    if (diff.inDays < 1) {
      return 'il y a ${diff.inHours} h';
    }
    if (diff.inDays < 7) {
      return 'il y a ${diff.inDays} j';
    }
    return 'il y a ${(diff.inDays / 7).floor()} sem.';
  }
}
