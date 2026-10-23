enum UploadPhase {
  idle,
  initializing,
  uploadingParts,
  finalizing,
  processing,

  /// Le suivi a été interrompu (délai dépassé) mais le traitement continue
  /// côté serveur.
  processingInBackground,
  ready,
  failed,
}

class VideoUploadProgress {
  const VideoUploadProgress({
    this.phase = UploadPhase.idle,
    this.uploadedParts = 0,
    this.totalParts = 0,
    this.processingPercent = 0,
    this.videoId,
    this.error,
  });

  final UploadPhase phase;
  final int uploadedParts;
  final int totalParts;
  final int processingPercent;
  final String? videoId;
  final Object? error;

  bool get isBusy =>
      phase != UploadPhase.idle &&
      phase != UploadPhase.ready &&
      phase != UploadPhase.processingInBackground &&
      phase != UploadPhase.failed;

  double get uploadFraction => totalParts == 0 ? 0 : uploadedParts / totalParts;

  VideoUploadProgress copyWith({
    UploadPhase? phase,
    int? uploadedParts,
    int? totalParts,
    int? processingPercent,
    String? videoId,
    Object? error,
  }) {
    return VideoUploadProgress(
      phase: phase ?? this.phase,
      uploadedParts: uploadedParts ?? this.uploadedParts,
      totalParts: totalParts ?? this.totalParts,
      processingPercent: processingPercent ?? this.processingPercent,
      videoId: videoId ?? this.videoId,
      error: error,
    );
  }
}
