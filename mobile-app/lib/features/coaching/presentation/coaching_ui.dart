import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:provider/provider.dart';

enum CoachingPillTone { green, amber, coral, neutral }

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
    super.key,
  });

  final String fullName;
  final String? avatarUrl;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      round ? size / 2 : (size >= 56 ? 18 : 15),
    );
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MetaGymTheme.coachAvatarBackground,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Text(
        coachInitials(fullName),
        style: TextStyle(
          color: MetaGymTheme.coachAvatarForeground,
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
    final (fg, bg, border) = switch (tone) {
      CoachingPillTone.green => (
        const Color(0xFF59E59A),
        const Color(0xFF173B2C),
        const Color(0xFF216F4B),
      ),
      CoachingPillTone.amber => (
        const Color(0xFFFFC573),
        const Color(0xFF45311D),
        const Color(0xFF815423),
      ),
      CoachingPillTone.coral => (
        const Color(0xFFFF987E),
        const Color(0xFF3D241D),
        const Color(0xFFA54E36),
      ),
      CoachingPillTone.neutral => (
        const Color(0xFFDCE0E7),
        const Color(0xFF24262C),
        const Color(0xFF494D58),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CoachingGraphiteCard extends StatelessWidget {
  const CoachingGraphiteCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MetaGymTheme.radiusCard);
    final body = Material(
      color: MetaGymTheme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? MetaGymTheme.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(padding: padding, child: child),
            ),
    );

    if (margin != null) return Padding(padding: margin!, child: body);
    return body;
  }
}

class CoachingPrimaryButton extends StatelessWidget {
  const CoachingPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
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
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: MetaGymTheme.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 19),
                  ],
                ],
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
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: MetaGymTheme.textPrimary,
        backgroundColor: MetaGymTheme.elevatedSurface,
        disabledForegroundColor: MetaGymTheme.textSecondary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: MetaGymTheme.darkBorderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        ),
        textStyle: const TextStyle(
          fontFamily: MetaGymTheme.fontFamily,
          fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

void showCoachingSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: MetaGymTheme.textPrimary,
            fontFamily: MetaGymTheme.fontFamily,
            fontFamilyFallback: MetaGymTheme.fontFamilyFallback,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: MetaGymTheme.elevatedSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
          side: const BorderSide(color: MetaGymTheme.darkBorderStrong),
        ),
      ),
    );
}

class CoachingErrorBanner extends StatelessWidget {
  const CoachingErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF24161A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF642B32)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: MetaGymTheme.dangerCoral,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFFB2B6),
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
    final hasPhotos =
        outcome.beforePhotoUrl != null || outcome.afterPhotoUrl != null;

    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Hành trình thực tế',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
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
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x20FFFFFF))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF324050),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    outcome.studentInitials,
                    style: const TextStyle(
                      color: Color(0xFFDBE9FA),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mục tiêu: ${outcome.goal}',
                        style: const TextStyle(
                          color: Color(0xFFC7CBD2),
                          fontSize: 11.5,
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
                const Flexible(
                  child: Text(
                    'Thời gian đồng hành',
                    style: TextStyle(color: Color(0xFFBFC3CC), fontSize: 11.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${outcome.durationWeeks} tuần',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 11),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0x20FFFFFF)),
                bottom: BorderSide(color: Color(0x20FFFFFF)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0x20FFFFFF),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Color(0xFFAEB5C0), fontSize: 10.5),
        ),
        const SizedBox(height: 4),
        Text(
          '${CoachOutcomeCase.formatNumber(weightKg)} kg',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (bodyFatPercent != null) ...[
          const SizedBox(height: 2),
          Text(
            '${CoachOutcomeCase.formatNumber(bodyFatPercent!)}% mỡ cơ thể',
            style: const TextStyle(color: Color(0xFFCCD0D7), fontSize: 10.5),
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
    final radius = BorderRadius.circular(13);
    final placeholder = Container(
      height: 156,
      decoration: BoxDecoration(
        color: MetaGymTheme.elevatedSurface,
        borderRadius: radius,
        border: Border.all(color: MetaGymTheme.darkBorderStrong),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline_rounded,
            color: MetaGymTheme.textSecondary,
            size: 26,
          ),
          const SizedBox(height: 6),
          Text(
            '$label · tùy chọn',
            style: const TextStyle(
              color: Color(0xFFB7BCC5),
              fontSize: 11,
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
                color: MetaGymTheme.darkCanvas.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
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
