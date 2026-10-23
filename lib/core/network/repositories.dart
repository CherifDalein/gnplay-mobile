import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/device_repository.dart';
import '../../features/auth/presentation/providers/token_storage_provider.dart';
import '../../features/creator/data/creator_analytics_repository.dart';
import '../../features/earnings/data/payout_repository.dart';
import '../../features/earnings/data/wallet_repository.dart';
import '../../features/profile/data/notification_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/publish/data/upload_repository.dart';
import '../../features/videos/data/video_repository.dart';
import 'http_client_provider.dart';

// Un dépôt par domaine, tous construits sur le même `ApiClient`. Les types
// sont explicites : le contrôleur d'authentification dépend de ces dépôts et
// le client HTTP dépend du contrôleur (lecture paresseuse), ce qui forme un
// cycle que l'inférence de types ne sait pas résoudre.

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
      (ref) => AuthRepository(ref.watch(apiClientProvider)),
    );

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
      (ref) => ProfileRepository(ref.watch(apiClientProvider)),
    );

final Provider<DeviceRepository> deviceRepositoryProvider =
    Provider<DeviceRepository>(
      (ref) => DeviceRepository(ref.watch(apiClientProvider)),
    );

final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>(
      (ref) => NotificationRepository(ref.watch(apiClientProvider)),
    );

final Provider<VideoRepository> videoRepositoryProvider =
    Provider<VideoRepository>(
      (ref) => VideoRepository(
        ref.watch(apiClientProvider),
        ref.watch(tokenStorageProvider),
      ),
    );

final Provider<UploadRepository> uploadRepositoryProvider =
    Provider<UploadRepository>(
      (ref) => UploadRepository(ref.watch(apiClientProvider)),
    );

final Provider<CreatorAnalyticsRepository> creatorAnalyticsRepositoryProvider =
    Provider<CreatorAnalyticsRepository>(
      (ref) => CreatorAnalyticsRepository(ref.watch(apiClientProvider)),
    );

final Provider<WalletRepository> walletRepositoryProvider =
    Provider<WalletRepository>(
      (ref) => WalletRepository(ref.watch(apiClientProvider)),
    );

final Provider<PayoutRepository> payoutRepositoryProvider =
    Provider<PayoutRepository>(
      (ref) => PayoutRepository(ref.watch(apiClientProvider)),
    );
