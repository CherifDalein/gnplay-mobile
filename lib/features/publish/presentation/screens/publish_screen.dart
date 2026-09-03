import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_upload_progress.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _thumbnailController = TextEditingController();

  PlatformFile? _pickedFile;
  int _step = 1;
  bool _isFree = false;
  bool _picking = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VideoUploadProgress>(videoUploadControllerProvider, (
      previous,
      next,
    ) {
      if (next.phase == UploadPhase.failed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(
              '${next.error}',
              style: AppTextStyles.caption.copyWith(color: AppColors.text1),
            ),
          ),
        );
      }
    });

    final uploadState = ref.watch(videoUploadControllerProvider);
    final effectiveStep = _stepForPhase(uploadState.phase) ?? _step;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
            children: [
              _Header(onCancel: () => _handleCancel(uploadState)),
              const SizedBox(height: 16),
              _StepBars(step: effectiveStep),
              const SizedBox(height: 9),
              Text(
                'Étape $effectiveStep sur 4 · ${_stepName(effectiveStep)}',
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.text3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (effectiveStep == 1)
                _FileStep(
                  file: _pickedFile,
                  isPicking: _picking,
                  onPick: _pickFile,
                  onContinue: _pickedFile == null
                      ? null
                      : () => setState(() => _step = 2),
                )
              else if (effectiveStep == 2)
                _DetailsStep(
                  titleController: _titleController,
                  descriptionController: _descriptionController,
                  priceController: _priceController,
                  thumbnailController: _thumbnailController,
                  isFree: _isFree,
                  isLoading: uploadState.phase == UploadPhase.initializing,
                  onFreeChanged: (value) => setState(() {
                    _isFree = value;
                    if (value) {
                      _priceController.text = '0';
                    }
                  }),
                  onSubmit: _startUpload,
                )
              else if (effectiveStep == 3)
                _UploadingStep(progress: uploadState)
              else
                _ProcessingStep(
                  progress: uploadState,
                  onFinish: () => context.go('/videos'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int? _stepForPhase(UploadPhase phase) {
    return switch (phase) {
      UploadPhase.uploadingParts || UploadPhase.finalizing => 3,
      UploadPhase.processing || UploadPhase.ready => 4,
      UploadPhase.idle || UploadPhase.initializing || UploadPhase.failed =>
        null,
    };
  }

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
      );
      final files = result?.files ?? const [];
      final file = files.isNotEmpty ? files.first : null;
      if (file != null && mounted) {
        setState(() {
          _pickedFile = file;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = _titleFromFilename(file.name);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  Future<void> _startUpload() async {
    final file = _pickedFile;
    final title = _titleController.text.trim();

    if (file == null || title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: Text(
            'Choisissez un fichier et renseignez un titre.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textInverse),
          ),
        ),
      );
      return;
    }

    await ref
        .read(videoUploadControllerProvider.notifier)
        .uploadFile(
          file: file,
          title: title,
          description: _descriptionController.text.trim(),
          price: _isFree ? 0 : int.tryParse(_priceController.text) ?? 0,
        );
  }

  Future<void> _handleCancel(VideoUploadProgress state) async {
    if (state.isBusy) {
      await ref.read(videoUploadControllerProvider.notifier).cancel();
    }
    if (mounted) {
      context.go('/videos');
    }
  }
}

String _titleFromFilename(String filename) {
  final withoutExtension = filename.contains('.')
      ? filename.substring(0, filename.lastIndexOf('.'))
      : filename;
  return withoutExtension.replaceAll(RegExp(r'[_-]+'), ' ').trim();
}

class _Header extends StatelessWidget {
  const _Header({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Nouvelle vidéo',
            style: AppTextStyles.title.copyWith(
              color: AppColors.text1,
              fontSize: 19,
            ),
          ),
        ),
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.text3,
            padding: EdgeInsets.zero,
          ),
          child: Text(
            'Annuler',
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
        ),
      ],
    );
  }
}

class _StepBars extends StatelessWidget {
  const _StepBars({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (index) {
        final active = index + 1 <= step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 3 ? 0 : 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: active ? AppColors.accent500 : AppColors.border1,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(height: 3),
            ),
          ),
        );
      }),
    );
  }
}

class _FileStep extends StatelessWidget {
  const _FileStep({
    required this.file,
    required this.isPicking,
    required this.onPick,
    required this.onContinue,
  });

  final PlatformFile? file;
  final bool isPicking;
  final VoidCallback onPick;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        children: [
          InkWell(
            onTap: isPicking ? null : onPick,
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border1, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent500.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: isPicking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.accent500,
                              ),
                            )
                          : const GnLineIcon(
                              GnLineIconData.video,
                              color: AppColors.accent500,
                              size: 24,
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      file == null ? 'Choisir une vidéo' : 'Changer de vidéo',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.text1,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'MP4 ou MOV · l’envoi reprend automatiquement s’il est interrompu',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.text3,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (file != null) ...[
            const SizedBox(height: 14),
            GnCard(
              radius: 14,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const GnVideoThumbnail(width: 56, height: 40, label: ''),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.text1,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${(file!.size / (1024 * 1024)).toStringAsFixed(1)} Mo',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.text3,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check, color: AppColors.success, size: 17),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          GnButton(
            label: 'Continuer',
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.titleController,
    required this.descriptionController,
    required this.priceController,
    required this.thumbnailController,
    required this.isFree,
    required this.isLoading,
    required this.onFreeChanged,
    required this.onSubmit,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController thumbnailController;
  final bool isFree;
  final bool isLoading;
  final ValueChanged<bool> onFreeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        children: [
          GnTextField(controller: titleController, label: 'Titre *'),
          const SizedBox(height: 12),
          GnTextField(
            controller: descriptionController,
            label: 'Description',
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GnTextField(
                  controller: priceController,
                  label: 'Prix',
                  enabled: !isFree,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                child: GnCard(
                  radius: 12,
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gratuite',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.text3,
                        ),
                      ),
                      const SizedBox(height: 7),
                      GnContentSwitch(value: isFree, onChanged: onFreeChanged),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GnTextField(
            controller: thumbnailController,
            label: 'Miniature — URL de l’image',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          GnCard(
            radius: 12,
            backgroundColor: AppColors.infoBg,
            borderColor: AppColors.info.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'L’envoi direct d’un fichier image n’est pas encore disponible côté API — collez une URL en attendant.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.text2,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GnButton(
            label: 'Envoyer la vidéo',
            isLoading: isLoading,
            onPressed: isLoading ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _UploadingStep extends StatelessWidget {
  const _UploadingStep({required this.progress});

  final VideoUploadProgress progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.uploadFraction * 100).round();
    final finalizing = progress.phase == UploadPhase.finalizing;

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Text(
            finalizing ? '100' : '$percent',
            style: AppTextStyles.displayLg.copyWith(
              color: AppColors.text1,
              fontSize: 44,
            ),
          ),
          Text(
            finalizing
                ? 'Finalisation…'
                : 'Envoi en cours… (${progress.uploadedParts}/${progress.totalParts})',
            style: AppTextStyles.caption.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: 22),
          GnProgressBar(value: finalizing ? 1 : progress.uploadFraction, height: 8),
          const SizedBox(height: 12),
          Text(
            'Ne quittez pas l’application.\nEn cas de coupure, l’envoi reprendra où il s’est arrêté.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
        ],
      ),
    );
  }
}

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({required this.progress, required this.onFinish});

  final VideoUploadProgress progress;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final ready = progress.phase == UploadPhase.ready;

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent500.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: GnLineIcon(
              ready ? GnLineIconData.chevronRight : GnLineIconData.video,
              color: AppColors.accent500,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            ready ? 'Vidéo prête' : 'Traitement en cours',
            style: AppTextStyles.title.copyWith(
              color: AppColors.text1,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ready
                ? 'Génération des qualités vidéo et de l’aperçu de 15 secondes terminée.'
                : 'Génération des qualités vidéo et de l’aperçu de 15 secondes.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
          const SizedBox(height: 24),
          GnProgressBar(
            value: progress.processingPercent / 100,
            height: 8,
            color: ready ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(height: 10),
          Text(
            ready
                ? 'Publiée dans votre catalogue'
                : '${progress.processingPercent} % · vous pouvez fermer l’app',
            style: AppTextStyles.caption.copyWith(
              color: ready ? AppColors.success : AppColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          GnButton(
            label: 'Voir mon contenu',
            onPressed: ready ? onFinish : null,
          ),
        ],
      ),
    );
  }
}

String _stepName(int step) {
  return switch (step) {
    1 => 'Fichier',
    2 => 'Détails',
    3 => 'Upload',
    _ => 'Traitement',
  };
}
