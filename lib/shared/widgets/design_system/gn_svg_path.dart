import 'dart:ui';

/// Mini-interpréteur de données de chemin SVG (attribut `d`), suffisant pour
/// les icônes du design system : M L H V C S Q T A Z, en absolu et en relatif.
///
/// Il évite d'ajouter une dépendance (`path_drawing`, `flutter_svg`) et permet
/// de reprendre tels quels les tracés de la maquette (viewBox 24x24).
Path parseSvgPath(String data) {
  return _SvgPathParser(data).parse();
}

class _SvgPathParser {
  _SvgPathParser(this._data);

  final String _data;
  int _pos = 0;

  static final RegExp _number = RegExp(
    r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
  );

  Path parse() {
    final path = Path();
    var x = 0.0, y = 0.0; // point courant
    var startX = 0.0, startY = 0.0; // début du sous-chemin
    var ctrlX = 0.0, ctrlY = 0.0; // dernier point de contrôle (S / T)
    String? cmd;
    String prev = '';

    while (true) {
      _skipSeparators();
      if (_pos >= _data.length) break;
      final c = _data[_pos];
      if (RegExp(r'[a-zA-Z]').hasMatch(c)) {
        cmd = c;
        _pos++;
        if (c == 'z' || c == 'Z') {
          path.close();
          x = startX;
          y = startY;
          prev = 'z';
          continue;
        }
      } else if (cmd == null) {
        throw FormatException('Chemin SVG invalide : $_data');
      } else if (cmd == 'M') {
        cmd = 'L';
      } else if (cmd == 'm') {
        cmd = 'l';
      }

      final rel = cmd == cmd.toLowerCase();
      switch (cmd.toUpperCase()) {
        case 'M':
          final nx = _num() + (rel ? x : 0);
          final ny = _num() + (rel ? y : 0);
          path.moveTo(nx, ny);
          x = startX = nx;
          y = startY = ny;
        case 'L':
          final nx = _num() + (rel ? x : 0);
          final ny = _num() + (rel ? y : 0);
          path.lineTo(nx, ny);
          x = nx;
          y = ny;
        case 'H':
          final nx = _num() + (rel ? x : 0);
          path.lineTo(nx, y);
          x = nx;
        case 'V':
          final ny = _num() + (rel ? y : 0);
          path.lineTo(x, ny);
          y = ny;
        case 'C':
          final x1 = _num() + (rel ? x : 0);
          final y1 = _num() + (rel ? y : 0);
          final x2 = _num() + (rel ? x : 0);
          final y2 = _num() + (rel ? y : 0);
          final nx = _num() + (rel ? x : 0);
          final ny = _num() + (rel ? y : 0);
          path.cubicTo(x1, y1, x2, y2, nx, ny);
          ctrlX = x2;
          ctrlY = y2;
          x = nx;
          y = ny;
        case 'S':
          final isAfterCubic = prev == 'C' || prev == 'S';
          final x1 = isAfterCubic ? 2 * x - ctrlX : x;
          final y1 = isAfterCubic ? 2 * y - ctrlY : y;
          final x2 = _num() + (rel ? x : 0);
          final y2 = _num() + (rel ? y : 0);
          final nx = _num() + (rel ? x : 0);
          final ny = _num() + (rel ? y : 0);
          path.cubicTo(x1, y1, x2, y2, nx, ny);
          ctrlX = x2;
          ctrlY = y2;
          x = nx;
          y = ny;
        case 'Q':
          final x1 = _num() + (rel ? x : 0);
          final y1 = _num() + (rel ? y : 0);
          final nx = _num() + (rel ? x : 0);
          final ny = _num() + (rel ? y : 0);
          path.quadraticBezierTo(x1, y1, nx, ny);
          ctrlX = x1;
          ctrlY = y1;
          x = nx;
          y = ny;
        case 'T':
          final isAfterQuad = prev == 'Q' || prev == 'T';
          final x1 = isAfterQuad ? 2 * x - ctrlX : x;
          final y1 = isAfterQuad ? 2 * y - ctrlY : y;
          final nx = _num() + (rel ? x : 0);
          final ny = _num() + (rel ? y : 0);
          path.quadraticBezierTo(x1, y1, nx, ny);
          ctrlX = x1;
          ctrlY = y1;
          x = nx;
          y = ny;
        case 'A':
          final rx = _num();
          final ry = _num();
          final rotation = _num();
          final largeArc = _flag();
          final sweep = _flag();
          final nx = _num() + (rel ? x : 0);
          final ny = _num() + (rel ? y : 0);
          if (rx == 0 || ry == 0) {
            path.lineTo(nx, ny);
          } else {
            path.arcToPoint(
              Offset(nx, ny),
              radius: Radius.elliptical(rx.abs(), ry.abs()),
              rotation: rotation,
              largeArc: largeArc,
              clockwise: sweep,
            );
          }
          x = nx;
          y = ny;
        default:
          throw FormatException('Commande SVG non gérée : $cmd dans $_data');
      }
      prev = cmd.toUpperCase();
    }
    return path;
  }

  void _skipSeparators() {
    while (_pos < _data.length) {
      final c = _data[_pos];
      if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') {
        _pos++;
      } else {
        break;
      }
    }
  }

  double _num() {
    _skipSeparators();
    final match = _number.matchAsPrefix(_data, _pos);
    if (match == null) {
      throw FormatException('Nombre attendu en position $_pos dans $_data');
    }
    _pos = match.end;
    return double.parse(match.group(0)!);
  }

  /// Les drapeaux d'arc peuvent être collés au nombre suivant (`a1 1 0 011 1`).
  bool _flag() {
    _skipSeparators();
    final c = _data[_pos];
    if (c != '0' && c != '1') {
      throw FormatException('Drapeau d\'arc attendu en position $_pos');
    }
    _pos++;
    return c == '1';
  }
}
