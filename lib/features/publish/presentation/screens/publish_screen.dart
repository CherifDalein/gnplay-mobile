import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';
import '../../../creator/presentation/widgets/creator_content_widgets.dart';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final _filenameController = TextEditingController(
    text: 'konakry-nights-final.mp4',
  );
  final _fileSizeController = TextEditingController(text: '842');
  final _mimeController = TextEditingController(text: 'video/mp4');
  final _titleController = TextEditingController(
    text: 'Nuits de Conakry — épisode 4',
  );
  final _descriptionController = TextEditingController(
    text: 'Le quatrième volet de la série documentaire, tourné à Kaloum.',
  );
  final _priceController = TextEditingController(text: '15000');
  final _thumbnailController = TextEditingController();

  int _step = 1;
  bool _isFree = false;

  @override
  void dispose() {
    _filenameController.dispose();
    _fileSizeController.dispose();
    _mimeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(videoUploadControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (response) {
          if (response != null && mounted) {
            setState(() => _step = 3);
            Future<void>.delayed(const Duration(milliseconds: 700), () {
              if (mounted) {
                setState(() => _step = 4);
              }
            });
          }
        },
        error: (error, stackTrace) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              content: Text(
                '$error',
                style: AppTextStyles.caption.copyWith(color: AppColors.text1),
              ),
            ),
          );
        },
      );
    });

    final uploadState = ref.watch(videoUploadControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: GnAppBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 116),
            children: [
              _Header(onCancel: () => context.go('/videos')),
              const SizedBox(height: 16),
              _StepBars(step: _step),
              const SizedBox(height: 9),
              Text(
                'Étape $_step sur 4 · ${_stepName(_step)}',
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.text3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_step == 1)
                _FileStep(
                  filenameController: _filenameController,
                  fileSizeController: _fileSizeController,
                  mimeController: _mimeController,
                  onContinue: () => setState(() => _step = 2),
                )
              else if (_step == 2)
                _DetailsStep(
                  titleController: _titleController,
                  descriptionController: _descriptionController,
                  priceController: _priceController,
                  thumbnailController: _thumbnailController,
                  isFree: _isFree,
                  isLoading: uploadState.isLoading,
                  onFreeChanged: (value) => setState(() {
                    _isFree = value;
                    if (value) {
                      _priceController.text = '0';
                    }
                  }),
                  onSubmit: _initUpload,
                )
              else if (_step == 3)
                const _UploadingStep()
              else
                _ProcessingStep(onFinish: () => context.go('/videos')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initUpload() async {
    final filename = _filenameController.text.trim();
    final mimeType = _mimeController.text.trim();
    final fileSizeMb = int.tryParse(_fileSizeController.text) ?? 0;
    final title = _titleController.text.trim();

    if (filename.isEmpty ||
        mimeType.isEmpty ||
        fileSizeMb <= 0 ||
        title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: Text(
            'Renseignez le fichier, le type MIME et le titre.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textInverse),
          ),
        ),
      );
      return;
    }

    await ref
        .read(videoUploadControllerProvider.notifier)
        .initUpload(
          filename: filename,
          fileSize: fileSizeMb * 1024 * 1024,
          mimeType: mimeType,
          title: title,
          description: _descriptionController.text,
          price: _isFree ? 0 : int.tryParse(_priceController.text) ?? 0,
        );
  }
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
    required this.filenameController,
    required this.fileSizeController,
    required this.mimeController,
    required this.onContinue,
  });

  final TextEditingController filenameController;
  final TextEditingController fileSizeController;
  final TextEditingController mimeController;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        children: [
          DecoratedBox(
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
                    child: const GnLineIcon(
                      GnLineIconData.video,
                      color: AppColors.accent500,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choisir une vidéo',
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
                        filenameController.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.text1,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${fileSizeController.text} Mo · ${mimeController.text}',
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
          const SizedBox(height: 12),
          GnTextField(controller: filenameController, label: 'Nom du fichier'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GnTextField(
                  controller: fileSizeController,
                  label: 'Taille Mo',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GnTextField(controller: mimeController, label: 'MIME'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GnButton(label: 'Continuer', onPressed: onContinue),
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
                    'L’envoi direct du fichier est initialisé côté API. Le transfert binaire sera branché quand le endpoint renverra sa cible d’upload.',
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
  const _UploadingStep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Text(
            '100',
            style: AppTextStyles.displayLg.copyWith(
              color: AppColors.text1,
              fontSize: 44,
            ),
          ),
          Text(
            'Envoi initialisé',
            style: AppTextStyles.caption.copyWith(color: AppColors.text2),
          ),
          const SizedBox(height: 22),
          const GnProgressBar(value: 1, height: 8),
          const SizedBox(height: 12),
          Text(
            'Le backend a créé la session d’upload.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
        ],
      ),
    );
  }
}

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
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
            child: const GnLineIcon(
              GnLineIconData.video,
              color: AppColors.accent500,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Traitement en cours',
            style: AppTextStyles.title.copyWith(
              color: AppColors.text1,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Génération des qualités vidéo et de l’aperçu de 15 secondes.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.text3),
          ),
          const SizedBox(height: 24),
          const GnProgressBar(value: 0.64, height: 8, color: AppColors.warning),
          const SizedBox(height: 10),
          Text(
            '64 % · vous pouvez fermer l’app',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          GnButton(label: 'Voir mon contenu', onPressed: onFinish),
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
