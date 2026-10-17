import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../auth/domain/user_read.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';
import '../../../creator/presentation/providers/creator_dashboard_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserRead?>>(profileControllerProvider, (
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

    final dashboardState = ref.watch(creatorDashboardProvider);
    final dashboard = dashboardState.valueOrNull;
    if (dashboard == null) {
      return Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: GnAppBackground(
            child: dashboardState.hasError
                ? GnAsyncError(
                    message: friendlyErrorMessage(dashboardState.error!),
                    onRetry: () => ref.invalidate(creatorDashboardProvider),
                  )
                : const GnLoadingState(),
          ),
        ),
      );
    }
    final user = dashboard.user;
    final unreadCount =
        ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final isLoggingOut = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
            children: [
              Text(
                'Profil',
                style: AppTextStyles.title.copyWith(
                  color: AppColors.text1,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Avatar(
                    user: user,
                    isUploading: _uploadingAvatar,
                    onTap: _pickAvatar,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: AppTextStyles.heading.copyWith(
                            color: AppColors.text1,
                            fontSize: 17,
                          ),
                        ),
                        if ((user.pageName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            '@${user.pageName}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.accent500,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                        if ((user.bio ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            user.bio!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.text3,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openEditSheet(context, user),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.text3,
                      size: 19,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GnCard(
                      radius: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dashboard.analytics.totalFollowers}',
                            style: AppTextStyles.displayMd.copyWith(
                              color: AppColors.text1,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Abonnés',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.text3,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: GnCard(
                      radius: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dashboard.analytics.totalVideos}',
                            style: AppTextStyles.displayMd.copyWith(
                              color: AppColors.text1,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vidéos publiées',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.text3,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GnCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _NavRow(
                      label: 'Appareils connectés',
                      onTap: () => context.push('/devices'),
                    ),
                    const Divider(height: 1, color: AppColors.border2),
                    _NavRow(
                      label: 'Notifications',
                      badge: unreadCount > 0 ? '$unreadCount' : null,
                      onTap: () => context.push('/notifications'),
                    ),
                    const Divider(height: 1, color: AppColors.border2),
                    _NavRow(
                      label: 'Réglages & sécurité',
                      onTap: () => context.push('/settings'),
                    ),
                    const Divider(height: 1, color: AppColors.border2),
                    _NavRow(
                      label: 'Statistiques de la chaîne',
                      onTap: () => context.go('/home'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GnButton(
                label: isLoggingOut ? 'Déconnexion…' : 'Se déconnecter',
                variant: GnButtonVariant.danger,
                isLoading: isLoggingOut,
                onPressed: isLoggingOut ? null : () => _logout(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final path = result?.files.firstOrNull?.path;
    if (path == null || !mounted) {
      return;
    }
    setState(() => _uploadingAvatar = true);
    await ref.read(profileControllerProvider.notifier).uploadAvatar(File(path));
    if (mounted) {
      setState(() => _uploadingAvatar = false);
    }
  }

  void _openEditSheet(BuildContext context, UserRead user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(user: user),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) {
      context.go('/login');
    }
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.user,
    required this.isUploading,
    required this.onTap,
  });

  final UserRead user;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isUploading ? null : onTap,
      customBorder: const CircleBorder(),
      child: Stack(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand,
              image: user.avatar == null || user.avatar!.isEmpty
                  ? null
                  : DecorationImage(
                      image: NetworkImage(user.avatar!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: user.avatar == null || user.avatar!.isEmpty
                ? Text(
                    user.initials,
                    style: AppTextStyles.heading.copyWith(
                      color: AppColors.text1,
                      fontSize: 24,
                    ),
                  )
                : null,
          ),
          if (isUploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.accent500,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent500,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bgApp, width: 3),
              ),
              child: const Icon(
                Icons.add,
                color: AppColors.textInverse,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap, this.badge});

  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.text1,
                  fontSize: 13.5,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent500,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  badge!,
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.textInverse,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
            ],
            const Icon(Icons.chevron_right, color: AppColors.text4, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});

  final UserRead user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _pageNameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _pageNameController = TextEditingController(
      text: widget.user.pageName ?? '',
    );
    _bioController = TextEditingController(text: widget.user.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: GnCard(
        backgroundColor: AppColors.surface2,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modifier le profil',
              style: AppTextStyles.heading.copyWith(color: AppColors.text1),
            ),
            const SizedBox(height: 14),
            GnTextField(controller: _nameController, label: 'Nom complet'),
            const SizedBox(height: 12),
            GnTextField(
              controller: _pageNameController,
              label: 'Identifiant public (page_name)',
            ),
            const SizedBox(height: 12),
            GnTextField(
              controller: _bioController,
              label: 'Bio',
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            GnButton(
              label: 'Enregistrer',
              isLoading: state.isLoading,
              onPressed: state.isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final ok = await ref
        .read(profileControllerProvider.notifier)
        .updateProfile(
          fullName: name,
          pageName: _pageNameController.text.trim(),
          bio: _bioController.text.trim(),
        );

    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }
}
