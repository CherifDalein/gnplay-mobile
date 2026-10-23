import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_line_icon.dart';

/// Touche en bas à gauche du pavé.
enum GnKeypadExtraKey {
  /// « 000 » (saisie de montants).
  tripleZero,

  /// « , » (décimales).
  comma,

  /// Aucune touche (case vide).
  none,
}

/// Pavé numérique 3x4 : 1-9, [extraKey], 0, effacer.
///
/// Deux modes, combinables :
/// - callbacks : [onDigit] reçoit « 0 »..« 9 », « 000 » ou « , » ;
///   [onBackspace] est appelé par la touche d'effacement ;
/// - [controller] : le pavé écrit directement dans le contrôleur (ajout en
///   fin de texte, effacement du dernier caractère). Pas de zéro initial
///   superflu sauf si [allowLeadingZero] ; [maxLength] borne la longueur ;
///   une seule virgule est acceptée.
///
/// Un appui long sur « effacer » vide le contrôleur. [enabled] à `false`
/// grise et bloque tout le pavé.
class GnNumericKeypad extends StatelessWidget {
  const GnNumericKeypad({
    super.key,
    this.controller,
    this.onDigit,
    this.onBackspace,
    this.extraKey = GnKeypadExtraKey.tripleZero,
    this.maxLength,
    this.allowLeadingZero = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onDigit;
  final VoidCallback? onBackspace;
  final GnKeypadExtraKey extraKey;
  final int? maxLength;
  final bool allowLeadingZero;
  final bool enabled;

  static const double keyHeight = 44;

  @override
  Widget build(BuildContext context) {
    final extraLabel = switch (extraKey) {
      GnKeypadExtraKey.tripleZero => '000',
      GnKeypadExtraKey.comma => ',',
      GnKeypadExtraKey.none => null,
    };

    final keys = <_KeySpec?>[
      for (var i = 1; i <= 9; i++) _KeySpec.digit('$i'),
      extraLabel == null ? null : _KeySpec.digit(extraLabel),
      _KeySpec.digit('0'),
      const _KeySpec.backspace(),
    ];

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.x2,
          crossAxisSpacing: AppSpacing.x2,
          mainAxisExtent: keyHeight,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          for (final key in keys)
            if (key == null)
              const SizedBox.shrink()
            else
              _PadKey(
                spec: key,
                enabled: enabled,
                onPressed: () => _press(key),
                onLongPress: key.isBackspace ? _clearAll : null,
              ),
        ],
      ),
    );
  }

  void _press(_KeySpec key) {
    if (!enabled) return;
    if (key.isBackspace) {
      final c = controller;
      if (c != null && c.text.isNotEmpty) {
        _setText(c, c.text.substring(0, c.text.length - 1));
      }
      onBackspace?.call();
      return;
    }
    final digit = key.label;
    final c = controller;
    if (c != null) _append(c, digit);
    onDigit?.call(digit);
  }

  void _clearAll() {
    if (!enabled) return;
    final c = controller;
    if (c != null && c.text.isNotEmpty) _setText(c, '');
  }

  void _append(TextEditingController c, String input) {
    var text = c.text;
    if (input == ',') {
      if (text.contains(',')) return;
      if (text.isEmpty) text = '0';
    } else if (!allowLeadingZero) {
      final isZero = input == '0' || input == '000';
      if (text.isEmpty && isZero) return;
      if (text == '0') text = '';
    }
    final next = text + input;
    if (maxLength != null && next.length > maxLength!) return;
    _setText(c, next);
  }

  void _setText(TextEditingController c, String text) {
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _KeySpec {
  const _KeySpec.digit(this.label) : isBackspace = false;
  const _KeySpec.backspace() : label = '', isBackspace = true;

  final String label;
  final bool isBackspace;
}

class _PadKey extends StatefulWidget {
  const _PadKey({
    required this.spec,
    required this.enabled,
    required this.onPressed,
    this.onLongPress,
  });

  final _KeySpec spec;
  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: spec.isBackspace
          ? 'Effacer'
          : (spec.label == ',' ? 'Virgule' : spec.label),
      excludeSemantics: true,
      onTap: widget.enabled ? widget.onPressed : null,
      child: Material(
        color: _pressed ? AppColors.surfaceHover : AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.r11),
          side: const BorderSide(color: AppColors.border1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.enabled ? widget.onPressed : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Center(
            child: spec.isBackspace
                ? const GnLineIcon(
                    GnLineIconData.backspace,
                    size: 20,
                    color: AppColors.text1,
                  )
                : Text(
                    spec.label,
                    style: AppTextStyles.display(
                      size: 15,
                      weight: FontWeight.w600,
                      color: AppColors.text1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
