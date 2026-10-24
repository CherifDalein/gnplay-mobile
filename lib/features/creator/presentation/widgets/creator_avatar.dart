import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Pastille ronde du créateur : sa photo si elle existe et se charge, sinon
/// ses initiales sur le dégradé de la marque.
///
/// Les initiales servent aussi de repli pendant le chargement et quand l'image
/// échoue (URL périmée, hors-ligne) : l'avatar n'est jamais vide ni cassé.
class CreatorAvatar extends StatelessWidget {
  const CreatorAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = 42,
  });

  final String initials;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final fallback = _Initials(initials: initials, size: size);

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: url == null || url.isEmpty
              ? fallback
              : Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : fallback,
                  errorBuilder: (context, error, stackTrace) => fallback,
                ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand800, AppColors.brand500],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: AppTextStyles.display(
            color: AppColors.text1,
            size: size * 0.36,
          ),
        ),
      ),
    );
  }
}
