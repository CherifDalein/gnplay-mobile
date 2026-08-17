import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/creator_series.dart';
import '../../domain/video_analytics.dart';
import '../../domain/video_playback_access.dart';
import '../../domain/video_upload_init_response.dart';
import '../../domain/video_with_stats.dart';
import 'creator_dashboard_provider.dart';
import 'creator_repository_provider.dart';

final creatorVideosProvider = FutureProvider.autoDispose<List<VideoWithStats>>((
  ref,
) async {
  return ref.watch(creatorRepositoryProvider).listMyVideos();
});

final creatorSeriesProvider = FutureProvider.autoDispose<List<CreatorSeries>>((
  ref,
) async {
  return ref.watch(creatorRepositoryProvider).listMySeries();
});

final creatorSeriesDetailProvider = FutureProvider.autoDispose
    .family<CreatorSeries, String>((ref, seriesId) {
      return ref.watch(creatorRepositoryProvider).loadSeries(seriesId);
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

final seriesMutationControllerProvider =
    StateNotifierProvider.autoDispose<
      SeriesMutationController,
      AsyncValue<void>
    >((ref) => SeriesMutationController(ref));

final videoUploadControllerProvider =
    StateNotifierProvider.autoDispose<
      VideoUploadController,
      AsyncValue<VideoUploadInitResponse?>
    >((ref) => VideoUploadController(ref));

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

class SeriesMutationController extends StateNotifier<AsyncValue<void>> {
  SeriesMutationController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> createSeries({
    required String name,
    String? description,
    bool isPublic = false,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(creatorRepositoryProvider)
          .createSeries(
            name: name,
            description: description,
            isPublic: isPublic,
          );
      _ref.invalidate(creatorSeriesProvider);
    });
  }

  Future<void> setPublic(CreatorSeries series, bool isPublic) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(creatorRepositoryProvider)
          .updateSeries(series.id, isPublic: isPublic);
      _ref.invalidate(creatorSeriesProvider);
      _ref.invalidate(creatorSeriesDetailProvider(series.id));
    });
  }
}

class VideoUploadController
    extends StateNotifier<AsyncValue<VideoUploadInitResponse?>> {
  VideoUploadController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> initUpload({
    required String filename,
    required int fileSize,
    required String mimeType,
    String? title,
    String? description,
    int? price,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _ref
          .read(creatorRepositoryProvider)
          .initVideoUpload(
            filename: filename,
            fileSize: fileSize,
            mimeType: mimeType,
            title: title,
            description: description,
            price: price,
          );
      _ref.invalidate(creatorVideosProvider);
      _ref.invalidate(creatorDashboardProvider);
      return response;
    });
  }
}
