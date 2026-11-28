import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_action_button.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

enum CoachingPillTone { green, amber, coral, info, neutral }

T? optionalProvider<T>(BuildContext context) {
  try {
    return context.read<T?>();
  } on ProviderNotFoundException {
    return null;
  }
}

String coachInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'C';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String formatVnd(num amount) {
  final formatted = NumberFormat.decimalPattern('vi_VN').format(amount.round());
  return '$formatted ₫';
}

String formatVietnamDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '--';
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return raw;
  final local = parsed.isUtc ? parsed.add(const Duration(hours: 7)) : parsed;
  return DateFormat('dd/MM/yyyy').format(local);
}

String formatVietnamTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '--';
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return raw;
  final local = parsed.isUtc ? parsed.add(const Duration(hours: 7)) : parsed;
  return DateFormat('HH:mm · dd/MM').format(local);
}

class CoachingProtectedImage extends StatefulWidget {
  const CoachingProtectedImage({
    required this.url,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  final String? url;
  final Widget fallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<CoachingProtectedImage> createState() => _CoachingProtectedImageState();
}

class _CoachingProtectedImageState extends State<CoachingProtectedImage> {
  static const int _maxCachedImages = 60;
  static final Map<String, Uint8List> _imageCache = {};

  Future<Uint8List?>? _bytesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFuture();
  }

  @override
  void didUpdateWidget(covariant CoachingProtectedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytesFuture = null;
      _syncFuture();
    }
  }

  void _syncFuture() {
    final url = widget.url;
    if (url == null || url.isEmpty || _bytesFuture != null) return;
    final client = optionalProvider<ApiClient>(context);
    if (client == null) return;
    final resolved = url.startsWith('/')
        ? client.resolveServerPath(url).toString()
        : url;
    final cached = _imageCache[resolved];
    if (cached != null) {
      _bytesFuture = Future.value(cached);
      return;
    }
    _bytesFuture = client
        .getBytes(resolved)
        .then((bytes) {
          if (bytes == null || bytes.isEmpty) return null;
          final data = Uint8List.fromList(bytes);
          if (_imageCache.length >= _maxCachedImages) {
            _imageCache.remove(_imageCache.keys.first);
          }
          _imageCache[resolved] = data;
          return data;
        })
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final future = _bytesFuture;
    if (future == null) return widget.fallback;
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) return widget.fallback;
        final image = Image.memory(
          bytes,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (_, _, _) => widget.fallback,
        );
        if (widget.borderRadius != null) {
          return ClipRRect(borderRadius: widget.borderRadius!, child: image);
        }
        return image;
      },
    );
  }
}

class CoachingAvatar extends StatelessWidget {
  const CoachingAvatar({
    required this.fullName,
    this.avatarUrl,
    this.size = 48,
    this.round = false,
    this.paletteIndex = 0,
    super.key,
  });

  final String fullName;
  final String? avatarUrl;
  final double size;
  final bool round;

  /// Bảng màu avatar chữ viết tắt khớp preview (`0`: vàng LN `#F5B041`, `1`: xanh thép `#2E4057`, `2`: lục bảo trầm `#2C4C4B`).
  final int paletteIndex;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      round ? size / 2 : (size >= 56 ? 18 : 15),
    );
    final (bg, fg) = switch (paletteIndex % 3) {
      1 => (const Color(0xFF2E4057), Colors.white),
      2 => (const Color(0xFF314D4A), Colors.white),
      _ => (
        MetaGymTheme.coachAvatarBackground,
        MetaGymTheme.coachAvatarForeground,
      ),
    };
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      alignment: Alignment.center,
      child: Text(
        coachInitials(fullName),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );

    return CoachingProtectedImage(
      url: avatarUrl,
      width: size,
      height: size,
      borderRadius: radius,
      fallback: fallback,
    );
  }
}

class CoachingPill extends StatelessWidget {
  const CoachingPill({
    required this.label,
    this.tone = CoachingPillTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final CoachingPillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final (fg, bg, border) = switch (tone) {
      CoachingPillTone.green =>
        isLight
            ? (
                colors.success,
                colors.success.withValues(alpha: 0.14),
                colors.success.withValues(alpha: 0.36),
              )
            : (
                const Color(0xFF59E59A),
                const Color(0xFF173B2C),
                const Color(0xFF216F4B),
              ),
      CoachingPillTone.amber =>
        isLight
            ? (
                colors.warning,
                colors.warning.withValues(alpha: 0.14),
                colors.warning.withValues(alpha: 0.36),
              )
            : (
                const Color(0xFFFFC573),
                const Color(0xFF45311D),
                const Color(0xFF815423),
              ),
      CoachingPillTone.coral =>
        isLight
            ? (
                colors.primaryText,
                MetaGymTheme.brandOrange.withValues(alpha: 0.14),
                MetaGymTheme.brandOrange.withValues(alpha: 0.38),
              )
            : (
                const Color(0xFFFF987E),
                const Color(0xFF3D241D),
                const Color(0xFFA54E36),
              ),
      CoachingPillTone.info =>
        isLight
            ? (
                colors.info,
                colors.info.withValues(alpha: 0.14),
                colors.info.withValues(alpha: 0.36),
              )
            : (
                const Color(0xFF9ACBF5),
                const Color(0xFF14283B),
                const Color(0xFF2D5D8A),
              ),
      CoachingPillTone.neutral =>
        isLight
            ? (colors.textSecondary, colors.metricPanelBg, colors.border)
            : (
                const Color(0xFFE6E0DA),
                const Color(0xB82A2521),
                const Color(0x9A8C8176),
              ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border.withValues(alpha: 0.72), width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            MetaGymResolvedIcon(icon!, size: 12.5, fallbackColor: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ Warm Smoked Liquid Glass dùng chung cho hệ Coaching, tự thích ứng Dark + Light.
class CoachingGraphiteCard extends StatelessWidget {
  const CoachingGraphiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (backgroundColor == null) {
      return MetaGymGlassCard(
        solid: false,
        padding: padding,
        margin: margin,
        borderColor: borderColor,
        onTap: onTap,
        child: child,
      );
    }
    final colors = MetaGymColors.of(context);
    final radius = BorderRadius.circular(MetaGymTheme.radiusCard);
    final content = Padding(padding: padding, child: child);
    final body = Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: borderColor ?? colors.liquidGlassBorder,
          width: 1.1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : MetaGymTap(onTap: onTap, borderRadius: radius, child: content),
    );
    if (margin == null) return body;
    return Padding(padding: margin!, child: body);
  }
}

class CoachingPrimaryButton extends StatelessWidget {
  const CoachingPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.svgAsset,
    this.loading = false,
    this.status = MetaGymActionButtonStatus.idle,
    this.showSuccessOnCompletion = false,
    super.key,
  });

  final String label;
  final FutureOr<void> Function()? onPressed;
  final IconData? icon;
  final String? svgAsset;
  final bool loading;
  final MetaGymActionButtonStatus status;
  final bool showSuccessOnCompletion;

  @override
  Widget build(BuildContext context) {
    return MetaGymActionButton(
      label: label,
      icon: icon,
      svgAsset: svgAsset,
      onPressed: onPressed,
      status: loading ? MetaGymActionButtonStatus.loading : status,
      autoLoading: false,
      showSuccessOnCompletion: showSuccessOnCompletion,
      style: FilledButton.styleFrom(
        backgroundColor: MetaGymTheme.primary,
        foregroundColor: MetaGymTheme.onPrimary,
        disabledBackgroundColor: const Color(0xFF3A2924),
        disabledForegroundColor: Colors.white60,
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        ),
        textStyle: const TextStyle(
          fontFamily: MetaGymTheme.fontFamily,
          fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CoachingSecondaryButton extends StatelessWidget {
  const CoachingSecondaryButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.isDanger = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDanger ? colors.error : colors.textPrimary,
        backgroundColor: colors.liquidGlass,
        disabledForegroundColor: colors.textSecondary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(
          color: isDanger
              ? colors.error.withValues(alpha: 0.45)
              : colors.liquidGlassBorder,
          width: 1.1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
        ),
        textStyle: const TextStyle(
          fontFamily: MetaGymTheme.fontFamily,
          fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

void showCoachingSnackBar(BuildContext context, String message) {
  final colors = MetaGymColors.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: colors.textPrimary,
            fontFamily: MetaGymTheme.fontFamily,
            fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: colors.overlayGlass,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
          side: BorderSide(color: colors.liquidGlassBorder, width: 1.1),
        ),
      ),
    );
}

class CoachingErrorBanner extends StatelessWidget {
  const CoachingErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLight
            ? colors.error.withValues(alpha: 0.08)
            : const Color(0xFF24161A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLight
              ? colors.error.withValues(alpha: 0.35)
              : const Color(0xFF642B32),
        ),
      ),
      child: Row(
        children: [
          MetaGymSvgIcon(MetaGymIcons.stateError, size: 20, fallbackIcon: Icons.error_outline_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isLight ? colors.error : const Color(0xFFFFB2B6),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CoachOutcomeCard extends StatelessWidget {
  const CoachOutcomeCard({
    required this.outcome,
    this.statusBadge,
    this.footer,
    super.key,
  });

  final CoachOutcomeCase outcome;
  final Widget? statusBadge;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final hasPhotos =
        outcome.beforePhotoUrl != null || outcome.afterPhotoUrl != null;

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Hành trình thực tế',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (statusBadge != null) ...[
                const SizedBox(width: 8),
                statusBadge!,
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(bottom: 11),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colors.metricPanelBorder.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.metricPanelBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.metricPanelBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    outcome.studentInitials,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outcome.studentName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mục tiêu: ${outcome.goal}',
                        style: TextStyle(
                          color: colors.textWarmMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Thời gian đồng hành',
                    style: TextStyle(color: colors.textWarmMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${outcome.durationWeeks} tuần',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 11),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.metricPanelBorder.withValues(alpha: 0.45),
                ),
                bottom: BorderSide(
                  color: colors.metricPanelBorder.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MetricCompareColumn(
                      title: 'Ban đầu',
                      weightKg: outcome.beforeWeightKg,
                      bodyFatPercent: outcome.beforeBodyFatPercent,
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: colors.metricPanelBorder.withValues(alpha: 0.45),
                  ),
                  Expanded(
                    child: _MetricCompareColumn(
                      title: 'Sau quá trình tập',
                      weightKg: outcome.afterWeightKg,
                      bodyFatPercent: outcome.afterBodyFatPercent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasPhotos) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: _OutcomePhotoTile(
                    label: 'Ảnh trước',
                    url: outcome.beforePhotoUrl,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OutcomePhotoTile(
                    label: 'Ảnh sau',
                    url: outcome.afterPhotoUrl,
                  ),
                ),
              ],
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

class _MetricCompareColumn extends StatelessWidget {
  const _MetricCompareColumn({
    required this.title,
    required this.weightKg,
    this.bodyFatPercent,
  });

  final String title;
  final double weightKg;
  final double? bodyFatPercent;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: colors.textWarmMuted, fontSize: 11.5),
        ),
        const SizedBox(height: 4),
        Text(
          '${CoachOutcomeCase.formatNumber(weightKg)} kg',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
        if (bodyFatPercent != null) ...[
          const SizedBox(height: 2),
          Text(
            '${CoachOutcomeCase.formatNumber(bodyFatPercent!)}% mỡ cơ thể',
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 11.5,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ],
    );
  }
}

class _OutcomePhotoTile extends StatelessWidget {
  const _OutcomePhotoTile({required this.label, required this.url});

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final radius = BorderRadius.circular(14);
    final placeholder = Container(
      height: 156,
      decoration: BoxDecoration(
        color: colors.metricPanelBg,
        borderRadius: radius,
        border: Border.all(color: colors.metricPanelBorder),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MetaGymSvgIcon(MetaGymIcons.settingPersonalInfo, size: 26, fallbackIcon: Icons.person_outline_rounded),
          const SizedBox(height: 6),
          Text(
            '$label · tùy chọn',
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (url == null) return placeholder;

    return SizedBox(
      height: 156,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoachingProtectedImage(
            url: url,
            height: 156,
            borderRadius: radius,
            fallback: placeholder,
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xDE1B1714),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x66FFF5E9)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
