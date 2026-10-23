import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_button.dart';

/// Contenu du bottom sheet de confirmation de la maquette : titre Sora 700 18,
/// texte 12.5 `text2`, deux boutons de 48 px (« Annuler » en contour, action
/// principale pleine ; rouge si [destructive]).
///
/// Ne gère pas la navigation : [onConfirm] / [onCancel] sont appelés au
/// toucher. Pour l'afficher et récupérer la réponse, utiliser
/// [showGnConfirmSheet].
class GnConfirmSheet extends StatelessWidget {
  const GnConfirmSheet({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.message,
    this.cancelLabel = 'Annuler',
    this.destructive = false,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.border1)),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 24, 22, 30 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.sheetTitle.copyWith(color: AppColors.text1),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.text2),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: GnButton(
                    label: cancelLabel,
                    onPressed: onCancel,
                    variant: GnButtonVariant.ghost,
                    height: 48,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: GnButton(
                    label: confirmLabel,
                    onPressed: onConfirm,
                    variant: destructive
                        ? GnButtonVariant.dangerFilled
                        : GnButtonVariant.primary,
                    height: 48,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Affiche un [GnConfirmSheet] en bas de l'écran et renvoie `true` si
/// l'utilisateur confirme, `false` s'il annule ou ferme la feuille (toucher
/// à côté, geste retour). Remplace les `AlertDialog` de confirmation.
///
/// ```dart
/// final ok = await showGnConfirmSheet(
///   context,
///   title: 'Supprimer cette vidéo ?',
///   message: 'Elle disparaîtra du catalogue.',
///   confirmLabel: 'Supprimer',
///   destructive: true,
/// );
/// if (ok) { ... }
/// ```
Future<bool> showGnConfirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Annuler',
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    elevation: 0,
    builder: (sheetContext) => GnConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      onConfirm: () => Navigator.of(sheetContext).pop(true),
      onCancel: () => Navigator.of(sheetContext).pop(false),
    ),
  );
  return result ?? false;
}
