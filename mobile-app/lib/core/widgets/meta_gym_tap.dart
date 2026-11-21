import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

/// Shared keyboard-accessible tap feedback; nested controls keep their own taps.
/// Only the foreground content transforms, so glass blur stays stationary.
class MetaGymTap extends StatefulWidget {
  const MetaGymTap({
    required this.child,
    this.onTap,
    this.borderRadius,
    this.customBorder,
    this.splashColor,
    this.highlightColor,
    this.focusColor,
    this.hoverColor,
    this.overlayColor,
    this.semanticLabel,
    this.selected,
    super.key,
  });

  final Widget child;
  final FutureOr<void> Function()? onTap;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final Color? splashColor;
  final Color? highlightColor;
  final Color? focusColor;
  final Color? hoverColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<MetaGymTap> createState() => _MetaGymTapState();
}

class _MetaGymTapState extends State<MetaGymTap> {
  bool _pressed = false;
  bool _busy = false;
  bool _focused = false;

  Future<void> _tap() async {
    if (_busy || widget.onTap == null) return;
    _busy = true;
    try {
      await widget.onTap!();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      selected: widget.selected,
      child: InkWell(
        onTap: widget.onTap == null ? null : _tap,
        onHighlightChanged: (value) {
          if (_pressed != value) setState(() => _pressed = value);
        },
        onFocusChange: (value) {
          if (_focused != value) setState(() => _focused = value);
        },
        borderRadius: widget.borderRadius,
        customBorder: widget.customBorder,
        splashColor:
            widget.splashColor ??
            MetaGymTheme.brandOrange.withValues(alpha: 0.16),
        highlightColor:
            widget.highlightColor ??
            MetaGymTheme.brandOrange.withValues(alpha: 0.10),
        focusColor:
            widget.focusColor ?? MetaGymTheme.focusBlue.withValues(alpha: 0.24),
        hoverColor: widget.hoverColor,
        overlayColor: widget.overlayColor,
        child: Container(
          foregroundDecoration: _focused
              ? BoxDecoration(
                  shape: widget.customBorder is CircleBorder
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: widget.customBorder is CircleBorder
                      ? null
                      : widget.borderRadius ??
                            BorderRadius.circular(MetaGymTheme.radiusInput),
                  border: Border.all(color: MetaGymTheme.focusBlue, width: 2),
                )
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: AnimatedScale(
              scale: _pressed && !reduced ? 0.98 : 1,
              duration: reduced ? Duration.zero : MetaGymTheme.pressDuration,
              curve: Curves.easeOutCubic,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
