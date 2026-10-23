import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_svg_path.dart';

/// Icônes dessinées en traits (viewBox 24x24, extrémités arrondies), qui
/// remplacent les `Icons.*` Material : le design system interdit les polices
/// d'icônes.
///
/// Les 12 premières sont dessinées à la main dans le peintre ; les suivantes
/// sont décrites par des tracés SVG (voir [_svgPaths]).
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

  // --- Navigation et actions ---
  /// Flèche de retour (tracé unique de la maquette).
  back,
  chevronLeft,
  chevronUp,
  chevronDown,
  close,
  search,
  filter,
  edit,
  trash,
  copy,
  externalLink,
  moreVertical,
  refresh,
  check,
  download,
  upload,
  share,
  backspace,

  // --- Médias ---
  play,
  pause,
  volume,
  volumeOff,
  image,

  // --- État et alertes ---
  checkCircle,
  alert,
  error,
  exclamation,
  wifiOff,

  // --- Compte, sécurité et appareils ---
  lock,
  logout,
  settings,
  phone,
  device,
  monitor,
  shield,

  // --- Divers ---
  clock,
  calendar,
  chart,
  percent,
  moon,
  document,
  star,
  heart,
  coins,
}

/// Tracés SVG (viewBox 24x24) des icônes qui ne sont pas dessinées à la main.
/// Chaque entrée peut contenir plusieurs sous-chemins.
const Map<GnLineIconData, String> _svgPaths = {
  GnLineIconData.back: 'M19 12H5M11.5 5.5 5 12l6.5 6.5',
  GnLineIconData.chevronLeft: 'M14.5 5.5 8 12l6.5 6.5',
  GnLineIconData.chevronUp: 'M5.5 14.5 12 8l6.5 6.5',
  GnLineIconData.chevronDown: 'M5.5 9.5 12 16l6.5-6.5',
  GnLineIconData.close: 'M6 6l12 12M18 6 6 18',
  GnLineIconData.search:
      'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM16.6 16.6 21 21',
  GnLineIconData.filter: 'M4 6h16M7 12h10M10 18h4',
  GnLineIconData.edit:
      'M4.5 19.5l.8-3.8L15.8 5.2a2.1 2.1 0 0 1 3 3L8.3 18.7zM14 7l3 3',
  GnLineIconData.trash:
      'M4 7h16M9 7V4.5h6V7M6.5 7l.8 12.5a1 1 0 0 0 1 .9h7.4a1 1 0 0 0 1-.9L17.5 7M10 11v5M14 11v5',
  GnLineIconData.copy:
      'M9 9h9a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H9a1 1 0 0 1-1-1v-9a1 1 0 0 1 1-1zM5.5 15H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v.5',
  GnLineIconData.externalLink:
      'M14 4.5h5.5V10M19.5 4.5 11 13M17.5 14v4.5a1 1 0 0 1-1 1h-10a1 1 0 0 1-1-1v-10a1 1 0 0 1 1-1H10',
  // moreVertical est dessinée à part (points pleins).
  GnLineIconData.moreVertical: 'M12 5.5h.01M12 12h.01M12 18.5h.01',
  GnLineIconData.refresh: 'M20.2 12a8.2 8.2 0 1 1-2.6-6M20.4 4v4.4h-4.4',
  GnLineIconData.check: 'M5 13l4.5 4.5L19 7',
  GnLineIconData.download: 'M12 4v11M7.5 11.5 12 16l4.5-4.5M4.5 20h15',
  GnLineIconData.upload: 'M12 16.5v-11M7.5 9 12 4.5 16.5 9M4.5 20h15',
  GnLineIconData.share:
      'M17 8.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM7 14.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM17 20.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM9.2 10.8l5.6-2.6M9.2 13.2l5.6 2.6',
  GnLineIconData.backspace:
      'M9 5.5h10a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1H9L3.5 12zM12.5 9.5l5 5M17.5 9.5l-5 5',
  GnLineIconData.play: 'M8 5.5v13l11-6.5z',
  GnLineIconData.pause: 'M9 5.5v13M15 5.5v13',
  GnLineIconData.volume:
      'M4 9.5h3.5L12 5.5v13l-4.5-4H4zM15.5 9a4.5 4.5 0 0 1 0 6M18.2 6.5a8 8 0 0 1 0 11',
  GnLineIconData.volumeOff:
      'M4 9.5h3.5L12 5.5v13l-4.5-4H4zM16 9.5l5 5M21 9.5l-5 5',
  GnLineIconData.image:
      'M5 4.5h14a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-13a1 1 0 0 1 1-1zM9.5 8.2a1.3 1.3 0 1 0 0 2.6 1.3 1.3 0 0 0 0-2.6zM4 16l4.5-4.5 4 4 3-3L20 16.5',
  GnLineIconData.checkCircle:
      'M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM8.3 12.3l2.5 2.5 4.9-5.3',
  GnLineIconData.alert: 'M12 4.2 21 19.5H3zM12 10v4.2M12 16.9h.01',
  GnLineIconData.error:
      'M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM12 7.8v5M12 16.2h.01',
  GnLineIconData.exclamation: 'M12 5.5v9M12 18.5h.01',
  GnLineIconData.wifiOff:
      'M3 3l18 18M3.5 9.2A13 13 0 0 1 8.4 6.3M13.8 6A13 13 0 0 1 20.5 9.2M6.8 13A8 8 0 0 1 10 11M14 11.2A8 8 0 0 1 17.2 13M12 18.5h.01',
  GnLineIconData.lock:
      'M7 10.5V8a5 5 0 0 1 10 0v2.5M6 10.5h12a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1zM12 14.5v2.5',
  GnLineIconData.logout:
      'M9 4.5H6A1.5 1.5 0 0 0 4.5 6v12A1.5 1.5 0 0 0 6 19.5h3M15 8l4 4-4 4M19 12H9',
  GnLineIconData.settings:
      'M12 15.2a3.2 3.2 0 1 0 0-6.4 3.2 3.2 0 0 0 0 6.4zM19.4 12c0-.6-.1-1.1-.2-1.6l1.6-1.2-1.8-3.1-1.9.8c-.8-.6-1.7-1.1-2.6-1.3L13.8 3.5h-3.6l-.7 2.1c-1 .2-1.9.7-2.6 1.3l-1.9-.8-1.8 3.1 1.6 1.2c-.1.5-.2 1-.2 1.6s.1 1.1.2 1.6l-1.6 1.2 1.8 3.1 1.9-.8c.8.6 1.7 1.1 2.6 1.3l.7 2.1h3.6l.7-2.1c1-.2 1.9-.7 2.6-1.3l1.9.8 1.8-3.1-1.6-1.2c.1-.5.2-1 .2-1.6z',
  GnLineIconData.phone:
      'M6.5 4h3l1.5 4-2 1.3a10 10 0 0 0 5.7 5.7L16 13l4 1.5v3a2 2 0 0 1-2 2C10.8 19.5 4.5 13.2 4.5 6a2 2 0 0 1 2-2z',
  GnLineIconData.device:
      'M8 3h8a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM10.5 18h3',
  GnLineIconData.monitor:
      'M4 5h16a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zM8.5 20h7M12 16v4',
  GnLineIconData.shield:
      'M12 3.5 5 6v5.5c0 4.2 2.8 7.4 7 9 4.2-1.6 7-4.8 7-9V6zM9 12l2.2 2.2L15.2 10',
  GnLineIconData.clock: 'M12 20a8 8 0 1 0 0-16 8 8 0 0 0 0 16zM12 8v4.4l3 1.8',
  GnLineIconData.calendar:
      'M5 5.5h14a1 1 0 0 1 1 1V19a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V6.5a1 1 0 0 1 1-1zM4 10h16M8 3.5v4M16 3.5v4',
  GnLineIconData.chart: 'M4 20h16M7 17v-5M12 17V6M17 17v-8',
  GnLineIconData.percent:
      'M7.5 9.2a1.7 1.7 0 1 0 0-3.4 1.7 1.7 0 0 0 0 3.4zM16.5 18.2a1.7 1.7 0 1 0 0-3.4 1.7 1.7 0 0 0 0 3.4zM18 6 6 18',
  GnLineIconData.moon: 'M20 14.5A8 8 0 1 1 9.5 4a6.3 6.3 0 0 0 10.5 10.5z',
  GnLineIconData.document:
      'M7 3.5h7l4 4V19.5a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1v-15a1 1 0 0 1 1-1zM14 3.5V8h4M9 12.5h6M9 16h6',
  GnLineIconData.star:
      'M12 3.8l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 17.2 6.8 19.9l1-5.8L3.5 10l5.9-.9z',
  GnLineIconData.heart:
      'M12 20.2C7 17 3.8 14 3.8 10.4A4.2 4.2 0 0 1 12 8.6a4.2 4.2 0 0 1 8.2 1.8c0 3.6-3.2 6.6-8.2 9.8z',
  GnLineIconData.coins:
      'M12 8.2c4.3 0 7.8-1.1 7.8-2.5S16.3 3.2 12 3.2 4.2 4.3 4.2 5.7 7.7 8.2 12 8.2zM19.8 5.7v12.6c0 1.4-3.5 2.5-7.8 2.5s-7.8-1.1-7.8-2.5V5.7M19.8 12c0 1.4-3.5 2.5-7.8 2.5S4.2 13.4 4.2 12',
};

final Map<GnLineIconData, Path> _svgPathCache = {};

Path? _pathFor(GnLineIconData icon) {
  final data = _svgPaths[icon];
  if (data == null) return null;
  return _svgPathCache.putIfAbsent(icon, () => parseSvgPath(data));
}

/// Vrai si [icon] est décrite par un tracé SVG (donc toutes sauf les 12
/// premières). Exposé pour les tests.
bool gnLineIconHasSvgPath(GnLineIconData icon) => _svgPaths.containsKey(icon);

class GnLineIcon extends StatelessWidget {
  const GnLineIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color = AppColors.text3,
    this.strokeWidth = 1.8,
    this.filled = false,
    this.semanticLabel,
  });

  final GnLineIconData icon;
  final double size;
  final Color color;
  final double strokeWidth;

  /// Remplit aussi la forme (play, star, heart...). À réserver aux icônes
  /// formées d'un contour fermé ; sans effet utile sur les icônes ouvertes.
  final bool filled;

  /// Libellé lu par les lecteurs d'écran. Sans libellé, l'icône est décorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final painted = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GnLineIconPainter(
          icon: icon,
          color: color,
          strokeWidth: strokeWidth,
          filled: filled,
        ),
      ),
    );
    if (semanticLabel == null) return painted;
    return Semantics(label: semanticLabel, image: true, child: painted);
  }
}

class _GnLineIconPainter extends CustomPainter {
  const _GnLineIconPainter({
    required this.icon,
    required this.color,
    required this.strokeWidth,
    this.filled = false,
  });

  final GnLineIconData icon;
  final Color color;
  final double strokeWidth;
  final bool filled;

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

    if (icon == GnLineIconData.moreVertical) {
      final dot = Paint()..color = color;
      for (final cy in const [5.5, 12.0, 18.5]) {
        canvas.drawCircle(Offset(12, cy), 1.6, dot);
      }
      canvas.restore();
      return;
    }

    final svg = _pathFor(icon);
    if (svg != null) {
      if (filled) {
        canvas.drawPath(
          svg,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawPath(svg, paint);
      canvas.restore();
      return;
    }

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
      default:
        // Les autres icônes sont décrites par un tracé SVG (traité plus haut).
        break;
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
        strokeWidth != oldDelegate.strokeWidth ||
        filled != oldDelegate.filled;
  }
}
