import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';

enum MetaGymActionButtonStatus { idle, loading, success, error }

/// Shared primary action button with guarded async submission and result states.
///
/// Success is shown only after [onPressed] completes. Callers that already own
/// request state can pass [status] to reflect the API result directly.
class MetaGymActionButton extends StatefulWidget {
  const MetaGymActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.status = MetaGymActionButtonStatus.idle,
    this.enabled = true,
    this.showSuccessOnCompletion = false,
    this.autoLoading = true,
    this.successLabel = 'Đã xong',
    this.errorLabel = 'Có lỗi · Thử lại',
    this.style,
    this.onError,
    super.key,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final IconData? icon;
  final MetaGymActionButtonStatus status;
  final bool enabled;
  final bool showSuccessOnCompletion;
  final bool autoLoading;
  final String successLabel;
  final String errorLabel;
  final ButtonStyle? style;
  final ValueChanged<Object>? onError;

  @override
  State<MetaGymActionButton> createState() => _MetaGymActionButtonState();
}

class _MetaGymActionButtonState extends State<MetaGymActionButton> {
  bool _submitting = false;
  bool _showCompleted = false;
  bool _showCaughtError = false;
  Timer? _resultTimer;

  @override
  void dispose() {
    _resultTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    final callback = widget.onPressed;
    if (callback == null ||
        !widget.enabled ||
        _submitting ||
        widget.status == MetaGymActionButtonStatus.loading ||
        widget.status == MetaGymActionButtonStatus.success) {
      return;
    }

    setState(() {
      _submitting = true;
      _showCaughtError = false;
      _showCompleted = false;
    });
    try {
      await callback();
      if (widget.showSuccessOnCompletion && mounted) {
        setState(() => _showCompleted = true);
        _scheduleResultReset();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _showCaughtError = true);
        widget.onError?.call(error);
        _scheduleResultReset();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _scheduleResultReset() {
    _resultTimer?.cancel();
    _resultTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _showCaughtError = false;
          _showCompleted = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final status = widget.status;
    final isLoading =
        (widget.autoLoading && _submitting) ||
        status == MetaGymActionButtonStatus.loading;
    final isSuccess =
        _showCompleted || status == MetaGymActionButtonStatus.success;
    final isError =
        _showCaughtError || status == MetaGymActionButtonStatus.error;
    final isEnabled =
        widget.enabled &&
        widget.onPressed != null &&
        !_submitting &&
        status != MetaGymActionButtonStatus.loading &&
        status != MetaGymActionButtonStatus.success;
    final text = isSuccess
        ? widget.successLabel
        : isError
        ? widget.errorLabel
        : widget.label;

    Widget child;
    if (isLoading) {
      child = const SizedBox(
        key: ValueKey('loading'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: MetaGymTheme.onPrimary,
          semanticsLabel: 'Đang xử lý',
        ),
      );
    } else {
      child = Row(
        key: ValueKey(text),
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSuccess)
            const Icon(Icons.check_circle_outline_rounded, size: 19)
          else if (isError)
            const Icon(Icons.error_outline_rounded, size: 19)
          else if (widget.icon != null)
            Icon(widget.icon, size: 19),
          if (isSuccess || isError || widget.icon != null)
            const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Semantics(
      liveRegion: isLoading || isSuccess || isError,
      label: isLoading ? '${widget.label} · Đang xử lý' : null,
      excludeSemantics: isLoading,
      button: true,
      enabled: isEnabled,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: isEnabled ? _submit : null,
          style: widget.style,
          child: AnimatedSwitcher(
            duration: disableAnimations
                ? Duration.zero
                : MetaGymTheme.pressDuration,
            child: child,
          ),
        ),
      ),
    );
  }
}
