import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';

class GnVideoThumbnail extends StatelessWidget {
  const GnVideoThumbnail({
    super.key,
    this.url,
    this.width,
    this.height,
    this.durationLabel,
    this.label = 'miniature',
  });

  final String? url;
  final double? width;
  final double? height;
  final String? durationLabel;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null || url!.isEmpty)
              _StripedPlaceholder(label: label)
            else
              Image.network(url!, fit: BoxFit.cover),
            if (durationLabel != null)
              Positioned(
                right: 5,
                bottom: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    child: Text(
                      durationLabel!,
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.text1,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GnContentSwitch extends StatelessWidget {
  const GnContentSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.isLoading = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final background = value ? AppColors.accent500 : AppColors.border1;
    final knobLeft = value ? 22.0 : 3.0;

    return GestureDetector(
      onTap: onChanged == null || isLoading ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          color: isLoading ? AppColors.surface3 : background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 160),
              top: 3,
              left: knobLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.text1,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GnMetricTile extends StatelessWidget {
  const GnMetricTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor = AppColors.text1,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      padding: const EdgeInsets.all(11),
      radius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTextStyles.heading.copyWith(
                color: valueColor,
                fontSize: 17,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.text3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class GnProgressBar extends StatelessWidget {
  const GnProgressBar({
    super.key,
    required this.value,
    this.height = 7,
    this.color = AppColors.accent500,
  });

  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.border1),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1).toDouble(),
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.brand600, color]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GnCompletionRing extends StatelessWidget {
  const GnCompletionRing({super.key, required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final normalized = (percent / 100).clamp(0, 1).toDouble();

    return SizedBox.square(
      dimension: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 170,
            child: CustomPaint(painter: _RingPainter(progress: normalized)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percent.round()}%',
                style: AppTextStyles.displayLg.copyWith(
                  color: AppColors.text1,
                  fontSize: 34,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 110,
                child: Text(
                  'taux de complétion moyen',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.text3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StripedPlaceholder extends StatelessWidget {
  const _StripedPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brand950,
        border: Border.all(color: AppColors.border1),
      ),
      child: CustomPaint(
        painter: const _StripePainter(),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.text3,
              fontFamily: AppFonts.mono,
              fontSize: 7.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1A0C12);
    for (var x = -size.height; x < size.width; x += 12) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + 6, size.height)
        ..lineTo(x + size.height + 6, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 9;
    final track = Paint()
      ..color = AppColors.border1
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11;
    final progressPaint = Paint()
      ..color = AppColors.accent500
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 11;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
