import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/locale/currency_provider.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../../creator/domain/video_with_stats.dart';
import '../../../creator/presentation/providers/creator_content_provider.dart';

/// Ouvre la feuille « Modifier la vidéo ». Renvoie `true` si des
/// modifications ont été enregistrées.
Future<bool> showVideoEditSheet(
  BuildContext context,
  VideoWithStats video,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    elevation: 0,
    builder: (_) => VideoEditSheet(video: video),
  );
  return saved ?? false;
}

/// Édition du titre, de la description et du prix.
///
/// Validation locale avant tout appel ; les erreurs du serveur s'affichent
/// DANS la feuille (un toast serait masqué par elle). Il n'y a pas de champ
/// miniature : le serveur n'a pas de route d'envoi de miniature.
class VideoEditSheet extends ConsumerStatefulWidget {
  const VideoEditSheet({super.key, required this.video});

  final VideoWithStats video;

  @override
  ConsumerState<VideoEditSheet> createState() => _VideoEditSheetState();
}

class _VideoEditSheetState extends ConsumerState<VideoEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late bool _free;
  String? _titleError;
  String? _priceError;
  String? _serverError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final video = widget.video;
    _title = TextEditingController(text: video.title);
    _description = TextEditingController(text: video.description ?? '');
    _free = video.price <= 0;
    _price = TextEditingController(text: _free ? '' : '${video.price}');
    // Une erreur de saisie disparaît dès qu'on corrige le champ.
    _title.addListener(() {
      if (_titleError != null) setState(() => _titleError = null);
    });
    _price.addListener(() {
      if (_priceError != null) setState(() => _priceError = null);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  void _setFree(bool value) {
    setState(() {
      _free = value;
      _priceError = null;
      if (value) _price.clear();
    });
  }

  /// Valide les champs ; renvoie le prix en entier ou `null` si invalide.
  int? _validate(String currency) {
    final title = _title.text.trim();
    setState(() {
      _titleError = title.isEmpty ? 'Le titre est obligatoire.' : null;
      _serverError = null;
    });

    int? price;
    String? priceError;
    if (_free) {
      price = 0;
    } else {
      final raw = _price.text.trim();
      price = raw.isEmpty ? null : int.tryParse(raw);
      if (price == null) {
        priceError =
            'Indiquez un prix en $currency ou choisissez « Gratuite ».';
      } else if (price < 1) {
        priceError = 'Le prix doit être supérieur à 0, ou cochez « Gratuite ».';
      }
    }
    setState(() => _priceError = priceError);
    if (_titleError != null || priceError != null) return null;
    return price;
  }

  Future<void> _submit(String currency) async {
    if (_saving) return;
    final price = _validate(currency);
    if (price == null) return;

    final video = widget.video;
    final title = _title.text.trim();
    final description = _description.text.trim();
    final titleChanged = title != video.title;
    final descriptionChanged = description != (video.description ?? '').trim();
    final priceChanged = price != video.price;
    if (!titleChanged && !descriptionChanged && !priceChanged) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _saving = true;
      _serverError = null;
    });
    try {
      final done = await ref
          .read(videoMutationControllerProvider.notifier)
          .updateDetails(
            videoId: video.id,
            title: titleChanged ? title : null,
            description: descriptionChanged ? description : null,
            price: priceChanged ? price : null,
          );
      if (!mounted) return;
      if (!done) {
        setState(() {
          _saving = false;
          _serverError = 'Une modification est déjà en cours. Patientez.';
        });
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverError = 'Une erreur inattendue est survenue. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(userCurrencyProvider);
    final media = MediaQuery.of(context);

    return PopScope(
      canPop: !_saving,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.surface1,
            border: Border(top: BorderSide(color: AppColors.border1)),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadii.sheet),
            ),
          ),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(22, 12, 22, 22 + media.padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border1,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Modifier la vidéo',
                  style: AppTextStyles.sheetTitle.copyWith(
                    color: AppColors.text1,
                  ),
                ),
                const SizedBox(height: 16),
                GnTextField(
                  controller: _title,
                  label: 'Titre',
                  errorText: _titleError,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                GnTextField(
                  controller: _description,
                  label: 'Description',
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 14),
                _FreeRow(value: _free, enabled: !_saving, onChanged: _setFree),
                if (!_free) ...[
                  const SizedBox(height: 10),
                  GnTextField(
                    controller: _price,
                    label: 'Prix ($currency)',
                    errorText: _priceError,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9),
                    ],
                    onFieldSubmitted: (_) => _submit(currency),
                  ),
                ],
                if (_serverError != null) ...[
                  const SizedBox(height: 14),
                  GnBanner(
                    tone: GnBannerTone.danger,
                    title: 'Enregistrement impossible',
                    message: _serverError!,
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: GnButton(
                        label: 'Annuler',
                        variant: GnButtonVariant.ghost,
                        height: 48,
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: GnButton(
                        label: 'Enregistrer',
                        height: 48,
                        isLoading: _saving,
                        onPressed: _saving ? null : () => _submit(currency),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FreeRow extends StatelessWidget {
  const _FreeRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gratuite',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.text1,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Les spectateurs la regardent sans payer.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.text3,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        GnSwitch(
          value: value,
          onChanged: enabled ? onChanged : null,
          semanticLabel: 'Vidéo gratuite',
        ),
      ],
    );
  }
}
