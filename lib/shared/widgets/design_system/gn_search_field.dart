import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'gn_line_icon.dart';

/// Barre de recherche (44 px, rayon 12) avec bouton d'effacement.
///
/// Sans [controller], le champ gère le sien. Le bouton « Effacer » (cible de
/// 44 px) n'apparaît que lorsque le texte n'est pas vide ; il vide le champ,
/// puis appelle [onChanged] avec `''` et [onClear].
class GnSearchField extends StatefulWidget {
  const GnSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Rechercher',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final bool enabled;

  @override
  State<GnSearchField> createState() => _GnSearchFieldState();
}

class _GnSearchFieldState extends State<GnSearchField> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant GnSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onTextChanged);
      _controller.addListener(_onTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onTextChanged);
      _focusNode.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onTextChanged);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    final focused = _focusNode.hasFocus;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: focused ? AppColors.brand500 : AppColors.border1,
          ),
        ),
        child: Row(
          children: [
            const GnLineIcon(GnLineIconData.search, size: 16),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                textInputAction: TextInputAction.search,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                cursorColor: AppColors.accent500,
                style: AppTextStyles.bodyText(size: 13, color: AppColors.text1),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  hintText: widget.hintText,
                  hintStyle: AppTextStyles.bodyText(
                    size: 13,
                    color: AppColors.text3,
                  ),
                ),
              ),
            ),
            if (hasText && widget.enabled)
              Semantics(
                button: true,
                label: 'Effacer la recherche',
                excludeSemantics: true,
                onTap: _clear,
                child: InkResponse(
                  onTap: _clear,
                  radius: 22,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: GnLineIcon(
                        GnLineIconData.close,
                        size: 14,
                        color: AppColors.text2,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}
