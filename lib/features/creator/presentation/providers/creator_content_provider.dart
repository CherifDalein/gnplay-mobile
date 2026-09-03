import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
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

final videoAnalyticsProvider = FutureProvider.autoDispose
    .family<VideoAnalytics, String>((ref, videoId) {
      return ref.watch(creatorRepositoryProvider).loadVideoAnalytics(videoId);
    });

final videoPlaybackAccessProvider = FutureProvider.autoDispose
    .family<VideoPlaybackAccess, String>((ref, videoId) {
      return ref
          .watch(creatorRepositoryProvider)
          .loadVideoPlaybackAccess(videoId);
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
