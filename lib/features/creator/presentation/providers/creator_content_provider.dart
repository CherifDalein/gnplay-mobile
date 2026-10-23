import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/repositories.dart';
import '../../../auth/presentation/providers/token_storage_provider.dart';
import '../../../publish/data/upload_repository.dart';
import '../../../videos/data/video_repository.dart';
import '../../domain/video_analytics.dart';
import '../../domain/video_playback_access.dart';
import '../../domain/video_upload_init_response.dart';
import '../../domain/video_upload_progress.dart';
import '../../domain/video_with_stats.dart';
import 'creator_dashboard_provider.dart';

final creatorVideosProvider = FutureProvider.autoDispose<List<VideoWithStats>>((
  ref,
) async {
  // Une vidéo supprimée reste en base (soft-delete) si elle a été achetée :
  // elle ne doit plus apparaître dans l'espace du créateur.
  final videos = await ref.watch(videoRepositoryProvider).listMyVideos();
  return [
    for (final video in videos)
      if (!video.isDeleted) video,
  ];
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
      return ref.watch(videoRepositoryProvider).loadVideoAnalytics(videoId);
    });

/// L'enregistrement de l'appareil au login (voir AuthController) est
/// best-effort et non bloquant : s'il n'a pas eu le temps de se terminer
/// (ou a échoué transitoirement) avant que l'utilisateur ouvre une vidéo,
/// la session de lecture est refusée avec "device not registered". Plutôt
/// que de faire échouer la lecture pour une simple question de timing, on
/// (ré)enregistre explicitement l'appareil une fois puis on retente.
final videoPlaybackAccessProvider = FutureProvider.autoDispose
    .family<VideoPlaybackAccess, String>((ref, videoId) async {
      final repository = ref.watch(videoRepositoryProvider);
      final devices = ref.watch(deviceRepositoryProvider);
      final tokenStorage = ref.watch(tokenStorageProvider);
      try {
        return await repository.createPlaybackSession(videoId);
      } on ApiException catch (error) {
        final isUnregisteredDevice =
            error.statusCode == 403 && error.serverSays('device');
        if (!isUnregisteredDevice) rethrow;

        // Le backend désactive au besoin l'appareil le plus ancien pour faire
        // de la place : l'enregistrement ne bloque plus à 3 appareils.
        final deviceId = await tokenStorage.readOrCreateDeviceId();
        await devices.registerDevice(deviceId: deviceId);
        return repository.createPlaybackSession(videoId);
      }
    });

final videoMutationControllerProvider =
    StateNotifierProvider.autoDispose<
      VideoMutationController,
      AsyncValue<void>
    >((ref) => VideoMutationController(ref));

final videoUploadControllerProvider =
    StateNotifierProvider.autoDispose<
      VideoUploadController,
      VideoUploadProgress
    >((ref) => VideoUploadController(ref));

class VideoMutationController extends StateNotifier<AsyncValue<void>> {
  VideoMutationController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> setPublished(VideoWithStats video, bool isPublished) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ref
          .read(videoRepositoryProvider)
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
          .read(videoRepositoryProvider)
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
      await _ref.read(videoRepositoryProvider).deleteVideo(videoId);
      _invalidateVideoData(videoId);
    });
  }

  Future<void> retryTranscode(String videoId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _ref.read(videoRepositoryProvider).retryTranscode(videoId);
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
const _maxPartAttempts = 3;
const _processingPollInterval = Duration(seconds: 3);

/// Au-delà, on arrête de suivre le traitement dans l'écran : il continue côté
/// serveur et la vidéo apparaîtra dans « Mes vidéos » une fois prête.
const _processingWatchLimit = Duration(minutes: 30);

class VideoUploadController extends StateNotifier<VideoUploadProgress> {
  VideoUploadController(this._ref) : super(const VideoUploadProgress());

  final Ref _ref;

  /// Incrémenté à chaque envoi et à chaque annulation : les tâches d'un envoi
  /// abandonné le voient et s'arrêtent au lieu d'écraser le nouvel état.
  int _generation = 0;

  bool _isCurrent(int generation) => mounted && generation == _generation;

  void _update(int generation, VideoUploadProgress next) {
    if (_isCurrent(generation)) state = next;
  }

  Future<void> uploadFile({
    required PlatformFile file,
    required String title,
    required String description,
    required int price,
  }) async {
    final generation = ++_generation;
    state = const VideoUploadProgress(phase: UploadPhase.initializing);
    final uploads = _ref.read(uploadRepositoryProvider);
    final videos = _ref.read(videoRepositoryProvider);

    try {
      final init = await uploads.init(
        filename: file.name,
        fileSize: file.size,
        mimeType: _mimeTypeFor(file.extension),
        title: title,
        description: description,
        price: price,
      );
      if (init.videoId.isEmpty || init.uploadId.isEmpty || init.parts.isEmpty) {
        throw const ApiException(
          'Réponse d’initialisation d’envoi invalide.',
          kind: ApiErrorKind.unexpected,
        );
      }
      _update(
        generation,
        state.copyWith(
          phase: UploadPhase.uploadingParts,
          totalParts: init.totalParts,
          uploadedParts: 0,
          videoId: init.videoId,
        ),
      );

      final confirmedParts = await _uploadParts(
        generation: generation,
        repository: uploads,
        file: file,
        videoId: init.videoId,
        uploadId: init.uploadId,
        chunkSize: init.chunkSize,
        parts: init.parts,
      );
      if (!_isCurrent(generation)) return;

      _update(generation, state.copyWith(phase: UploadPhase.finalizing));
      await uploads.complete(
        init.videoId,
        uploadId: init.uploadId,
        parts: confirmedParts,
      );
      // À partir d'ici la vidéo existe pour de bon : une annulation ne doit
      // plus la supprimer.
      _ref.invalidate(creatorVideosProvider);

      _update(
        generation,
        state.copyWith(phase: UploadPhase.processing, processingPercent: 0),
      );
      final finished = await _watchProcessing(generation, videos, init.videoId);
      if (!_isCurrent(generation)) return;

      _update(
        generation,
        state.copyWith(
          phase: finished
              ? UploadPhase.ready
              : UploadPhase.processingInBackground,
          processingPercent: finished ? 100 : state.processingPercent,
        ),
      );
      _ref.invalidate(creatorVideosProvider);
      _ref.invalidate(creatorDashboardProvider);
    } catch (error) {
      _update(
        generation,
        state.copyWith(phase: UploadPhase.failed, error: error),
      );
    }
  }

  Future<List<({int partNumber, String etag})>> _uploadParts({
    required int generation,
    required UploadRepository repository,
    required PlatformFile file,
    required String videoId,
    required String uploadId,
    required int chunkSize,
    required List<UploadPartTarget> parts,
  }) async {
    final confirmed = <int, String>{};
    var nextIndex = 0;

    Future<void> worker() async {
      while (nextIndex < parts.length && _isCurrent(generation)) {
        final part = parts[nextIndex++];
        final start = (part.partNumber - 1) * chunkSize;
        final length = math.min(chunkSize, file.size - start);
        final bytes = await _readChunk(file, start, length);
        final etag = await _uploadPartWithRetry(
          generation: generation,
          repository: repository,
          videoId: videoId,
          uploadId: uploadId,
          part: part,
          bytes: bytes,
        );
        if (!_isCurrent(generation)) return;
        await repository.confirmPart(
          videoId,
          partNumber: part.partNumber,
          etag: etag,
          size: bytes.length,
        );
        confirmed[part.partNumber] = etag;
        _update(generation, state.copyWith(uploadedParts: confirmed.length));
      }
    }

    await Future.wait(
      List.generate(
        math.min(_maxParallelUploads, parts.length),
        (_) => worker(),
      ),
    );

    final ordered = confirmed.keys.toList()..sort();
    return [
      for (final partNumber in ordered)
        (partNumber: partNumber, etag: confirmed[partNumber]!),
    ];
  }

  /// Un envoi de 10 Mo sur réseau mobile échoue souvent ponctuellement : on
  /// retente avec une attente croissante et une URL pré-signée fraîche (la
  /// précédente a pu expirer).
  Future<String> _uploadPartWithRetry({
    required int generation,
    required UploadRepository repository,
    required String videoId,
    required String uploadId,
    required UploadPartTarget part,
    required List<int> bytes,
  }) async {
    var url = part.uploadUrl;
    for (var attempt = 1; ; attempt++) {
      try {
        if (url.isEmpty) throw const ApiException('URL d’envoi manquante.');
        return await repository.uploadPart(url, bytes);
      } catch (error) {
        if (attempt >= _maxPartAttempts || !_isCurrent(generation)) rethrow;
        await Future<void>.delayed(Duration(seconds: attempt * 2));
        try {
          final fresh = await repository.presignParts(
            videoId,
            uploadId: uploadId,
            partNumbers: [part.partNumber],
          );
          if (fresh.isNotEmpty && fresh.first.uploadUrl.isNotEmpty) {
            url = fresh.first.uploadUrl;
          }
        } catch (_) {
          // On retente avec l'URL précédente.
        }
      }
    }
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

  /// Suit le transcodage. Renvoie true si la vidéo est prête, false si l'on a
  /// cessé de suivre (délai dépassé) alors qu'elle est toujours en cours.
  /// Les erreurs réseau ponctuelles sont ignorées ; un échec du traitement
  /// lève une [ApiException].
  Future<bool> _watchProcessing(
    int generation,
    VideoRepository repository,
    String videoId,
  ) async {
    final deadline = DateTime.now().add(_processingWatchLimit);
    var consecutiveErrors = 0;
    while (_isCurrent(generation) && DateTime.now().isBefore(deadline)) {
      try {
        final status = await repository.getProcessingStatus(videoId);
        consecutiveErrors = 0;
        _update(generation, state.copyWith(processingPercent: status.progress));
        if (status.isDone) return true;
        if (status.isFailed) {
          throw ApiException(
            status.errorMessage == null
                ? 'Le traitement de la vidéo a échoué.'
                : 'Le traitement de la vidéo a échoué : ${status.errorMessage}',
            kind: ApiErrorKind.server,
          );
        }
      } on ApiException catch (error) {
        if (!error.isNetwork || ++consecutiveErrors >= 5) rethrow;
      }
      await Future<void>.delayed(_processingPollInterval);
    }
    return false;
  }

  /// Revient au formulaire vierge (après une publication réussie ou un échec).
  void reset() {
    _generation++;
    state = const VideoUploadProgress();
  }

  /// Annule l'envoi en cours. Avant la finalisation, l'envoi est abandonné
  /// côté serveur (ce qui supprime la vidéo incomplète). Pendant le
  /// traitement, la vidéo est déjà enregistrée : on arrête seulement de
  /// suivre sa progression, sans rien supprimer.
  Future<void> cancel() async {
    final videoId = state.videoId;
    final abortOnServer =
        state.phase == UploadPhase.initializing ||
        state.phase == UploadPhase.uploadingParts;
    reset();
    if (abortOnServer && videoId != null && videoId.isNotEmpty) {
      try {
        await _ref.read(uploadRepositoryProvider).abort(videoId);
      } catch (_) {
        // Best-effort : l'envoi expirera côté serveur.
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
