import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

enum GnLineIconData {
  home,
  video,
  plus,
  wallet,
  user,
  bell,
  eye,
  group,
  chevronRight,
  arrowUp,
  arrowDown,
  info,
}

class GnLineIcon extends StatelessWidget {
  const GnLineIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color = AppColors.text3,
    this.strokeWidth = 1.8,
  });

  final GnLineIconData icon;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GnLineIconPainter(
          icon: icon,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _GnLineIconPainter extends CustomPainter {
  const _GnLineIconPainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
  });

  final GnLineIconData icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24;
    final sy = size.height / 24;
    canvas.save();
    canvas.scale(sx, sy);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case GnLineIconData.home:
        _path(canvas, paint, [
          Offset(3.5, 10.5),
          Offset(12, 4),
          Offset(20.5, 10.5),
          Offset(20.5, 20),
          Offset(14.8, 20),
          Offset(14.8, 14),
          Offset(9.2, 14),
          Offset(9.2, 20),
          Offset(3.5, 20),
          Offset(3.5, 10.5),
        ]);
      case GnLineIconData.video:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 6.5, 16, 11),
            const Radius.circular(2),
          ),
          paint,
        );
        final play = Path()
          ..moveTo(10, 9.5)
          ..lineTo(15, 12)
          ..lineTo(10, 14.5)
          ..close();
        canvas.drawPath(play, paint);
      case GnLineIconData.plus:
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), paint);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), paint);
      case GnLineIconData.wallet:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 7, 16, 11),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.drawLine(const Offset(7, 7), const Offset(17, 7), paint);
        canvas.drawCircle(const Offset(16.7, 12.5), 0.8, paint);
      case GnLineIconData.user:
        canvas.drawCircle(const Offset(12, 8.2), 3.1, paint);
        final path = Path()
          ..moveTo(5.5, 20)
          ..cubicTo(6.3, 15.9, 9, 14, 12, 14)
          ..cubicTo(15, 14, 17.7, 15.9, 18.5, 20);
        canvas.drawPath(path, paint);
      case GnLineIconData.bell:
        final path = Path()
          ..moveTo(18, 16)
          ..lineTo(18, 11)
          ..cubicTo(18, 7.7, 15.3, 5, 12, 5)
          ..cubicTo(8.7, 5, 6, 7.7, 6, 11)
          ..lineTo(6, 16)
          ..lineTo(4, 19)
          ..lineTo(20, 19)
          ..lineTo(18, 16);
        canvas.drawPath(path, paint);
        final clapper = Path()
          ..moveTo(10, 20)
          ..cubicTo(10.5, 21, 13.5, 21, 14, 20);
        canvas.drawPath(clapper, paint);
      case GnLineIconData.eye:
        final path = Path()
          ..moveTo(3.5, 12)
          ..cubicTo(5.8, 8, 8.6, 6.5, 12, 6.5)
          ..cubicTo(15.4, 6.5, 18.2, 8, 20.5, 12)
          ..cubicTo(18.2, 16, 15.4, 17.5, 12, 17.5)
          ..cubicTo(8.6, 17.5, 5.8, 16, 3.5, 12);
        canvas.drawPath(path, paint);
        canvas.drawCircle(const Offset(12, 12), 2.4, paint);
      case GnLineIconData.group:
        canvas.drawCircle(const Offset(9, 8.5), 2.6, paint);
        canvas.drawCircle(const Offset(16.2, 9.4), 2.1, paint);
        final path = Path()
          ..moveTo(4.5, 19)
          ..cubicTo(5.1, 15.6, 7, 14, 9.3, 14)
          ..cubicTo(11.6, 14, 13.5, 15.6, 14.1, 19)
          ..moveTo(14.3, 15)
          ..cubicTo(16.7, 15.2, 18.5, 16.6, 19.4, 19);
        canvas.drawPath(path, paint);
      case GnLineIconData.chevronRight:
        _path(canvas, paint, [
          Offset(9.5, 5.5),
          Offset(16, 12),
          Offset(9.5, 18.5),
        ]);
      case GnLineIconData.arrowUp:
        _path(canvas, paint, [
          Offset(12, 19),
          Offset(12, 5),
          Offset(6.5, 10.5),
          Offset(12, 5),
          Offset(17.5, 10.5),
        ]);
      case GnLineIconData.arrowDown:
        _path(canvas, paint, [
          Offset(12, 5),
          Offset(12, 19),
          Offset(6.5, 13.5),
          Offset(12, 19),
          Offset(17.5, 13.5),
        ]);
      case GnLineIconData.info:
        canvas.drawCircle(const Offset(12, 12), 8, paint);
        canvas.drawLine(const Offset(12, 11), const Offset(12, 16), paint);
        canvas.drawCircle(const Offset(12, 8), 0.35, paint);
    }

    canvas.restore();
  }

  void _path(Canvas canvas, Paint paint, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GnLineIconPainter oldDelegate) {
    return icon != oldDelegate.icon ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
