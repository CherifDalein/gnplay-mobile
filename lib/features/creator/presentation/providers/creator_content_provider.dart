import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/presentation/providers/device_repository_provider.dart';
import '../../../auth/presentation/providers/token_storage_provider.dart';
import '../../data/creator_repository.dart';
import '../../domain/video_analytics.dart';
import '../../domain/video_playback_access.dart';
import '../../domain/video_upload_init_response.dart';
import '../../domain/video_upload_progress.dart';
import '../../domain/video_with_stats.dart';
import 'creator_dashboard_provider.dart';
import 'creator_repository_provider.dart';

final creatorVideosProvider = FutureProvider.autoDispose<List<VideoWithStats>>((
  ref,
) async {
  return ref.watch(creatorRepositoryProvider).listMyVideos();
});

/// Résout une vidéo par id depuis la liste déjà chargée par
/// [creatorVideosProvider] — état de chargement/erreur transmis tel quel, et
/// `null` en cas de succès si la vidéo n'existe plus dans la liste (ex.
/// supprimée ailleurs). Centralise cette recherche pour éviter de la
/// dupliquer (avec un faux repli sur des données d'exemple) dans chaque écran.
final videoByIdProvider = Provider.autoDispose
    .family<AsyncValue<VideoWithStats?>, String>((ref, videoId) {
      return ref.watch(creatorVideosProvider).whenData((videos) {
        for (final video in videos) {
          if (video.id == videoId) {
            return video;
          }
        }
        return null;
      });
    });

final videoAnalyticsProvider = FutureProvider.autoDispose
    .family<VideoAnalytics, String>((ref, videoId) {
      return ref.watch(creatorRepositoryProvider).loadVideoAnalytics(videoId);
    });

/// L'enregistrement de l'appareil au login (voir AuthController) est
/// best-effort et non bloquant : s'il n'a pas eu le temps de se terminer
/// (ou a échoué transitoirement) avant que l'utilisateur ouvre une vidéo,
/// la session de lecture est refusée avec "device not registered". Plutôt
/// que de faire échouer la lecture pour une simple question de timing, on
/// (ré)enregistre explicitement l'appareil une fois puis on retente.
final videoPlaybackAccessProvider = FutureProvider.autoDispose
    .family<VideoPlaybackAccess, String>((ref, videoId) async {
      final repository = ref.watch(creatorRepositoryProvider);
      try {
        return await repository.loadVideoPlaybackAccess(videoId);
      } on ApiException catch (error) {
        final isUnregisteredDevice =
            error.statusCode == 403 &&
            error.message.toLowerCase().contains('device');
        if (!isUnregisteredDevice) {
          rethrow;
        }

        final authToken = ref.read(authControllerProvider).valueOrNull;
        if (authToken == null) {
          rethrow;
        }

        final deviceId = await ref
            .watch(tokenStorageProvider)
            .readOrCreateDeviceId();
        // Si l'appareil courant est déjà au maximum (3/3 ailleurs), cet
        // appel lève sa propre erreur explicite ("Maximum of 3 active
        // devices reached...") qui remplace l'originale, moins actionnable.
        await ref
            .watch(deviceRepositoryProvider)
            .registerDevice(accessToken: authToken.accessToken, deviceId: deviceId);

        return await repository.loadVideoPlaybackAccess(videoId);
      }
    });

final videoMutationControllerProvider =
    StateNotifierProvider.autoDispose<
      VideoMutationController,
      AsyncValue<void>
    >((ref) => VideoMutationController(ref));

final videoUploadControllerProvider =
    StateNotifierProvider.autoDispose<VideoUploadController, VideoUploadProgress>(
      (ref) => VideoUploadController(ref),
    );

class VideoMutationController extends StateNotifier<AsyncValue<void>> {
  VideoMutationController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> setPublished(VideoWithStats video, bool isPublished) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(creatorRepositoryProvider)
          .updateVideo(video.id, isPublished: isPublished);
      _invalidateVideoData(video.id);
    });
  }

  Future<void> updateVideo({
    required String videoId,
    String? title,
    String? description,
    int? price,
    String? thumbnailUrl,
    bool? isPublished,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(creatorRepositoryProvider)
          .updateVideo(
            videoId,
            title: title,
            description: description,
            price: price,
            thumbnailUrl: thumbnailUrl,
            isPublished: isPublished,
          );
      _invalidateVideoData(videoId);
    });
  }

  Future<void> deleteVideo(String videoId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ref.read(creatorRepositoryProvider).deleteVideo(videoId);
      _invalidateVideoData(videoId);
    });
  }

  void _invalidateVideoData(String videoId) {
    _ref.invalidate(creatorVideosProvider);
    _ref.invalidate(videoAnalyticsProvider(videoId));
    _ref.invalidate(creatorDashboardProvider);
  }
}

const _maxParallelUploads = 3;

class VideoUploadController extends StateNotifier<VideoUploadProgress> {
  VideoUploadController(this._ref) : super(const VideoUploadProgress());

  final Ref _ref;

  Future<void> uploadFile({
    required PlatformFile file,
    required String title,
    required String description,
    required int price,
  }) async {
    state = const VideoUploadProgress(phase: UploadPhase.initializing);
    final repository = _ref.read(creatorRepositoryProvider);

    try {
      final init = await repository.initVideoUpload(
        filename: file.name,
        fileSize: file.size,
        mimeType: _mimeTypeFor(file.extension),
        title: title,
        description: description,
        price: price,
      );

      if (init.videoId.isEmpty || init.uploadId.isEmpty || init.parts.isEmpty) {
        throw const ApiException('Réponse d’initialisation d’envoi invalide.');
      }

      state = state.copyWith(
        phase: UploadPhase.uploadingParts,
        totalParts: init.totalParts,
        uploadedParts: 0,
        videoId: init.videoId,
      );

      final confirmedParts = await _uploadParts(
        repository: repository,
        file: file,
        videoId: init.videoId,
        chunkSize: init.chunkSize,
        parts: init.parts,
      );

      state = state.copyWith(phase: UploadPhase.finalizing);
      await repository.completeUpload(
        init.videoId,
        uploadId: init.uploadId,
        parts: confirmedParts,
      );

      state = state.copyWith(phase: UploadPhase.processing, processingPercent: 0);
      await _pollProcessing(repository, init.videoId);

      state = state.copyWith(phase: UploadPhase.ready, processingPercent: 100);
      _ref.invalidate(creatorVideosProvider);
      _ref.invalidate(creatorDashboardProvider);
    } catch (error) {
      state = state.copyWith(phase: UploadPhase.failed, error: error);
    }
  }

  Future<List<({int partNumber, String etag})>> _uploadParts({
    required CreatorRepository repository,
    required PlatformFile file,
    required String videoId,
    required int chunkSize,
    required List<UploadPartTarget> parts,
  }) async {
    final confirmed = <int, String>{};
    var nextIndex = 0;

    Future<void> worker() async {
      while (nextIndex < parts.length) {
        final part = parts[nextIndex++];
        final start = (part.partNumber - 1) * chunkSize;
        final length = math.min(chunkSize, file.size - start);
        final bytes = await _readChunk(file, start, length);
        final etag = await repository.uploadChunk(part.uploadUrl, bytes);
        await repository.confirmUploadPart(
          videoId,
          partNumber: part.partNumber,
          etag: etag,
          size: bytes.length,
        );
        confirmed[part.partNumber] = etag;
        state = state.copyWith(uploadedParts: confirmed.length);
      }
    }

    await Future.wait(
      List.generate(math.min(_maxParallelUploads, parts.length), (_) => worker()),
    );

    final ordered = confirmed.keys.toList()..sort();
    return ordered
        .map((partNumber) => (partNumber: partNumber, etag: confirmed[partNumber]!))
        .toList();
  }

  Future<List<int>> _readChunk(PlatformFile file, int start, int length) async {
    final bytes = file.bytes;
    if (bytes != null) {
      final end = math.min(start + length, bytes.length);
      return bytes.sublist(start, end);
    }

    final path = file.path;
    if (path == null) {
      throw const ApiException('Fichier vidéo introuvable sur l’appareil.');
    }

    final raf = await File(path).open();
    try {
      await raf.setPosition(start);
      return await raf.read(length);
    } finally {
      await raf.close();
    }
  }

  Future<void> _pollProcessing(
    CreatorRepository repository,
    String videoId,
  ) async {
    while (true) {
      final status = await repository.getProcessingStatus(videoId);
      state = state.copyWith(processingPercent: status.progress);
      if (status.isDone) {
        return;
      }
      if (status.isFailed) {
        throw ApiException(
          status.errorMessage ?? 'Le traitement de la vidéo a échoué.',
        );
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void reset() => state = const VideoUploadProgress();

  Future<void> cancel() async {
    final videoId = state.videoId;
    final wasBusy = state.isBusy;
    state = const VideoUploadProgress();
    if (wasBusy && videoId != null && videoId.isNotEmpty) {
      try {
        await _ref.read(creatorRepositoryProvider).abortUpload(videoId);
      } catch (_) {
        // Best-effort: l'envoi sera nettoyé côté serveur par expiration.
      }
    }
  }

  String _mimeTypeFor(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mp4':
      default:
        return 'video/mp4';
    }
  }
}
