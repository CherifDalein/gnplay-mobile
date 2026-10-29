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
/// [creatorVideosProvider]. Pendant un rafraîchissement (tirer pour actualiser,
/// sondage, retour sur l'écran) la valeur précédente est conservée : l'écran
/// garde son contenu au lieu de repasser par un chargement plein écran.
///
/// - données : la vidéo, ou `null` si elle n'existe plus dans la liste (ex.
///   supprimée ailleurs) ;
/// - erreur / chargement : uniquement tant qu'aucune liste n'a été chargée.
///
/// Pour savoir si un rafraîchissement a échoué, observer aussi
/// [creatorVideosProvider] (`hasError && hasValue`).
final videoByIdProvider = Provider.autoDispose
    .family<AsyncValue<VideoWithStats?>, String>((ref, videoId) {
      final state = ref.watch(creatorVideosProvider);
      final videos = state.valueOrNull;
      if (videos != null) {
        for (final video in videos) {
          if (video.id == videoId) return AsyncData(video);
        }
        return const AsyncData(null);
      }
      return state.hasError
          ? AsyncError(state.error!, state.stackTrace ?? StackTrace.current)
          : const AsyncLoading();
    });

final videoAnalyticsProvider = FutureProvider.autoDispose
    .family<VideoAnalytics, String>((ref, videoId) {
      return ref.watch(videoRepositoryProvider).loadVideoAnalytics(videoId);
    });

/// Session de lecture de la vidéo complète (`playback-session`, valable 2 h).
///
/// L'enregistrement de l'appareil au login (voir AuthController) est
/// best-effort et non bloquant : s'il n'a pas eu le temps de se terminer
/// (ou a échoué transitoirement) avant que l'utilisateur ouvre une vidéo,
/// la session de lecture est refusée avec « device not registered ». Plutôt
/// que de faire échouer la lecture pour une simple question de timing, on
/// (ré)enregistre explicitement l'appareil une fois puis on retente.
///
/// Rafraîchir ce provider (`ref.refresh`) crée une nouvelle session : c'est
/// ainsi que le lecteur renouvelle un jeton arrivé à expiration.
final videoPlaybackAccessProvider = FutureProvider.autoDispose
    .family<VideoPlaybackAccess, String>((ref, videoId) async {
      final repository = ref.read(videoRepositoryProvider);
      try {
        return await repository.createPlaybackSession(videoId);
      } on ApiException catch (error) {
        final isUnregisteredDevice =
            error.statusCode == 403 && error.serverSays('device');
        if (!isUnregisteredDevice) rethrow;

        // Le backend désactive au besoin l'appareil le plus ancien pour faire
        // de la place : l'enregistrement ne bloque plus à 3 appareils.
        final deviceId = await ref
            .read(tokenStorageProvider)
            .readOrCreateDeviceId();
        await ref
            .read(deviceRepositoryProvider)
            .registerDevice(deviceId: deviceId);
        return repository.createPlaybackSession(videoId);
      }
    });

/// Vidéos dont une action (publication, édition, suppression, relance) est en
/// cours. Chaque carte lit uniquement son propre identifiant.
final videoMutationControllerProvider =
    StateNotifierProvider<VideoMutationController, VideoMutationState>(
      (ref) => VideoMutationController(ref),
    );

final videoUploadControllerProvider =
    StateNotifierProvider.autoDispose<
      VideoUploadController,
      VideoUploadProgress
    >((ref) => VideoUploadController(ref));

class VideoMutationState {
  const VideoMutationState({this.busyVideoIds = const {}});

  final Set<String> busyVideoIds;

  bool isBusy(String videoId) => busyVideoIds.contains(videoId);
}

/// Actions du créateur sur ses vidéos. Chaque méthode lève l'[ApiException] du
/// serveur en cas d'échec (l'écran choisit où l'afficher : toast, feuille…) et
/// ignore l'appel (en renvoyant `false`) si la même vidéo est déjà en cours de
/// modification. Elles renvoient `true` quand l'action a bien été exécutée.
class VideoMutationController extends StateNotifier<VideoMutationState> {
  VideoMutationController(this._ref) : super(const VideoMutationState());

  final Ref _ref;

  /// Publie ou masque une vidéo prête.
  Future<bool> setPublished(VideoWithStats video, bool isPublished) {
    return _run(
      video.id,
      () => _ref
          .read(videoRepositoryProvider)
          .updateVideo(video.id, isPublished: isPublished),
    );
  }

  /// Modifie titre, description et/ou prix (seuls les champs fournis sont
  /// envoyés).
  Future<bool> updateDetails({
    required String videoId,
    String? title,
    String? description,
    int? price,
  }) {
    return _run(
      videoId,
      () => _ref
          .read(videoRepositoryProvider)
          .updateVideo(
            videoId,
            title: title,
            description: description,
            price: price,
          ),
    );
  }

  /// Supprime la vidéo (définitivement si jamais achetée, sinon retrait du
  /// catalogue). N'attend pas le rechargement de la liste : l'écran de détail
  /// se ferme aussitôt.
  Future<bool> deleteVideo(String videoId) {
    return _run(
      videoId,
      () => _ref.read(videoRepositoryProvider).deleteVideo(videoId),
      waitForList: false,
    );
  }

  /// Relance le transcodage d'une vidéo en échec. Un 409 signifie que la
  /// vidéo n'est plus en échec (liste périmée), un 503 que la mise en file a
  /// échoué : dans les deux cas la liste est rechargée pour refléter l'état réel.
  Future<bool> retryTranscode(String videoId) {
    return _run(
      videoId,
      () => _ref.read(videoRepositoryProvider).retryTranscode(videoId),
      refreshOnFailure: (error) =>
          error.statusCode == 409 || error.statusCode == 503,
    );
  }

  Future<bool> _run(
    String videoId,
    Future<void> Function() action, {
    bool waitForList = true,
    bool Function(ApiException error)? refreshOnFailure,
  }) async {
    if (state.isBusy(videoId)) return false;
    _setBusy(videoId, true);
    // L'état « occupé » n'est levé qu'après le rechargement de la liste : la
    // carte ne retrouve son interrupteur qu'avec les données à jour.
    try {
      try {
        await action();
      } on ApiException catch (error) {
        if (mounted && (refreshOnFailure?.call(error) ?? false)) {
          _invalidateVideoData(videoId);
        }
        rethrow;
      }
      if (!mounted) return true;
      _invalidateVideoData(videoId);
      if (waitForList) {
        try {
          await _ref.read(creatorVideosProvider.future);
        } catch (_) {
          // Échec du rechargement : l'écran affiche l'erreur d'actualisation.
        }
      }
      return true;
    } finally {
      _setBusy(videoId, false);
    }
  }

  void _setBusy(String videoId, bool busy) {
    if (!mounted) return;
    final ids = {...state.busyVideoIds};
    busy ? ids.add(videoId) : ids.remove(videoId);
    state = VideoMutationState(busyVideoIds: ids);
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
