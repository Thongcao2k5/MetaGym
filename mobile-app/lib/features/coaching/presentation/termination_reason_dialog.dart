import 'package:meta_gym_app/core/theme/theme_controller.dart';

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';

/// Hộp thoại nhập lý do kết thúc sớm (Level 3 Warm Smoked Overlay Glass),
/// thích ứng đồng bộ Dark + Light Daylight Studio.
class TerminationReasonDialog extends StatefulWidget {
  const TerminationReasonDialog({
    this.title = 'Yêu cầu kết thúc sớm?',
    this.description = 'Yêu cầu sẽ gửi tới đối tác với thời hạn phản hồi 72 giờ. Nếu đối tác từ chối hoặc quá hạn, yêu cầu sẽ tự chuyển Admin phân xử.',
    this.label = 'Lý do kết thúc sớm',
    this.confirmLabel = 'Xác nhận kết thúc',
    this.maxLength = 1000,
    super.key,
  });

  final String title;
  final String? description;
  final String label;
  final String confirmLabel;
  final int maxLength;

  @override
  State<TerminationReasonDialog> createState() =>
      _TerminationReasonDialogState();
}

class _TerminationReasonDialogState extends State<TerminationReasonDialog> {
  final _controller = TextEditingController();
  bool _showValidation = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(MetaGymTheme.radiusGlassDock);
    final enableBlur =
        !isLight &&
        !MetaGymSurfacePreferences.reduceBlurOf(context) &&
        !disableAnimations &&
        !MetaGymTheme.isFlutterTestEnvironment;

    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xEB332C27), Color(0xF0241F1B)],
              ),
        color: isLight ? colors.overlayGlass : null,
        border: Border.all(
          color: colors.liquidGlassBorder,
          width: isLight ? 1.0 : 1.15,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 36,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (!isLight)
            Positioned(
              left: 22,
              right: 22,
              top: 0,
              child: IgnorePointer(
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: colors.warmGlassHighlight),
                ),
              ),
            ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.error.withValues(alpha: 0.42),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const MetaGymIcon(
                        MetaGymIcons.coachingTermination,
                        size: MetaGymIconSize.sm,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 11),
                  Text(
                    widget.description!,
                    style: TextStyle(
                      color: colors.textWarmMuted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('termination-reason'),
                  controller: _controller,
                  cursorColor: MetaGymTheme.brandOrange,
                  maxLength: widget.maxLength,
                  maxLines: 3,
                  onChanged: (_) {
                    if (_showValidation) {
                      setState(() => _showValidation = false);
                    }
                  },
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    labelText: widget.label,
                    labelStyle: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                    ),
                    floatingLabelStyle: TextStyle(
                      color: _showValidation
                          ? colors.error
                          : colors.primaryText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    counterStyle: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    errorText: _showValidation ? 'Vui lòng nhập lý do.' : null,
                    errorStyle: TextStyle(
                      color: colors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: colors.metricPanelBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: BorderSide(color: colors.metricPanelBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: BorderSide(color: colors.metricPanelBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: BorderSide(
                        color: MetaGymTheme.primary,
                        width: 1.4,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: BorderSide(color: colors.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                      borderSide: BorderSide(color: colors.error, width: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            backgroundColor: colors.metricPanelBg,
                            side: BorderSide(color: colors.metricPanelBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MetaGymTheme.radiusInput,
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text(
                            'Quay lại',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: FilledButton(
                          key: const Key('termination-submit-btn'),
                          onPressed: () {
                            final reason = _controller.text.trim();
                            if (reason.isEmpty) {
                              setState(() => _showValidation = true);
                              return;
                            }
                            Navigator.pop(context, reason);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: MetaGymTheme.primary,
                            foregroundColor: MetaGymTheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                MetaGymTheme.radiusInput,
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(
                            widget.confirmLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: enableBlur
            ? RepaintBoundary(
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: card,
                  ),
                ),
              )
            : card,
      ),
    );
  }
}
