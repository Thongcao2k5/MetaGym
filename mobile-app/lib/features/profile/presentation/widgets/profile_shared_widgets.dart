import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';

/// Quyền truy cập thư viện ảnh thiết bị cho ảnh đại diện.
enum PhotoAccessMode { unset, full, selectedOnly, denied }

/// Nhãn tiếng Việt tương ứng với [PhotoAccessMode].
String photoAccessModeLabel(PhotoAccessMode mode) => switch (mode) {
  PhotoAccessMode.full => 'Cho phép truy cập đầy đủ',
  PhotoAccessMode.selectedOnly => 'Hạn chế quyền truy cập Ảnh và video',
  PhotoAccessMode.denied => 'Không cho phép',
  PhotoAccessMode.unset => 'Chưa cấp quyền truy cập ảnh',
};

/// Hành động người dùng chọn trong modal Cập nhật ảnh đại diện (5.1 & 5.2).
enum ProfileAvatarAction { camera, gallery, remove }

/// Hiển thị toast đồng bộ Dark + Light cho luồng Hồ sơ.
void showProfileToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final colors = MetaGymColors.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.overlayGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError
                ? colors.error.withValues(alpha: 0.55)
                : colors.borderStrong,
          ),
        ),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: isError ? colors.error : colors.success,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Khung trang con đồng bộ preview (`5.2`, `5.3`, `5.11`–`5.14`):
/// - Nền [MetaGymBackground] thích ứng Dark/Light + `RepaintBoundary`
/// - Header với [MetaGymCircleIconButton] dùng `common_back.svg`, eyebrow cam, tiêu đề đậm
/// - Thanh CTA đáy `.bottom-cta-dock` có `SafeArea(top: false)` khi truyền [bottomBar].
class ProfileSubPageScaffold extends StatelessWidget {
  const ProfileSubPageScaffold({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.actions = const <Widget>[],
    this.bottomBar,
    super.key,
  });

  final String eyebrow;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MetaGymBackground()),
          SafeArea(
            bottom: bottomBar == null,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      MetaGymCircleIconButton(
                        svgAsset: MetaGymIcons.commonBack,
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              eyebrow.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.primaryText,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 18.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final action in actions) ...[
                        const SizedBox(width: 8),
                        action,
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      MetaGymTheme.pageGutter,
                      4,
                      MetaGymTheme.pageGutter,
                      bottomBar == null ? 28 : 20,
                    ),
                    child: body,
                  ),
                ),
                if (bottomBar != null)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? colors.overlayGlass
                          : const Color(0xF0181513),
                      border: Border(
                        top: BorderSide(
                          color: colors.metricPanelBorder.withValues(
                            alpha: 0.65,
                          ),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: bottomBar!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhóm danh mục đóng/mở đồng bộ `.accordion-card` trong `tab5-profile.js`.
class ProfileAccordionCard extends StatelessWidget {
  const ProfileAccordionCard({
    required this.title,
    required this.svgIcon,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.children,
    super.key,
  });

  final String title;
  final String svgIcon;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final duration = MetaGymTheme.stateDurationOf(context);
    return MetaGymGlassCard(
      solid: false,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MetaGymTap(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
            semanticLabel: '$title, $count mục',
            selected: expanded,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    MetaGymIcon(
                      svgIcon,
                      size: MetaGymIconSize.sm,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.metricPanelBg,
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusFull,
                        ),
                        border: Border.all(
                          color: colors.metricPanelBorder.withValues(
                            alpha: 0.75,
                          ),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: colors.textWarmMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0.0,
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: expanded
                            ? colors.primaryText
                            : colors.textWarmMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Divider(
              height: 1,
              indent: 14,
              endIndent: 14,
              color: colors.metricPanelBorder.withValues(alpha: 0.65),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    children[index],
                    if (index < children.length - 1)
                      Divider(
                        height: 1,
                        indent: 10,
                        endIndent: 10,
                        color: colors.metricPanelBorder.withValues(alpha: 0.42),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dòng mục con trong `.accordion-body` (`.accordion-row`), đảm bảo vùng chạm `>= 48dp`.
class ProfileAccordionRow extends StatelessWidget {
  const ProfileAccordionRow({
    required this.title,
    required this.onTap,
    this.svgIcon,
    this.trailingBadge,
    super.key,
  });

  final String title;
  final VoidCallback onTap;
  final String? svgIcon;
  final String? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      semanticLabel: title,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              if (svgIcon != null) ...[
                MetaGymIcon(
                  svgIcon!,
                  size: MetaGymIconSize.xs,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailingBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.chipActiveBg,
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusFull,
                    ),
                  ),
                  child: Text(
                    trailingBadge!,
                    style: TextStyle(
                      color: colors.primaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trường nhập có nhãn bên ngoài `.field > label + .input-box` khớp preview `5.2` & `5.3`.
class ProfileLabeledTextField extends StatelessWidget {
  const ProfileLabeledTextField({
    required this.controller,
    this.label,
    this.hintText,
    this.leadingSvg,
    this.trailing,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.tabularFigures = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? leadingSvg;
  final Widget? trailing;
  final int? minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool tabularFigures;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          minLines: obscureText ? 1 : minLines,
          maxLines: obscureText ? 1 : maxLines,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.35,
            fontFeatures: tabularFigures
                ? const [FontFeature.tabularFigures()]
                : null,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13.5),
            filled: true,
            fillColor: colors.metricPanelBg,
            isDense: false,
            contentPadding: EdgeInsets.symmetric(
              horizontal: leadingSvg != null ? 10 : 14,
              vertical: maxLines > 1 ? 12 : 13,
            ),
            prefixIcon: leadingSvg == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: MetaGymIcon(
                      leadingSvg!,
                      size: MetaGymIconSize.sm,
                      excludeFromSemantics: true,
                    ),
                  ),
            prefixIconConstraints: leadingSvg == null
                ? null
                : const BoxConstraints(minWidth: 42, minHeight: 42),
            suffixIcon: trailing,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              borderSide: BorderSide(color: colors.metricPanelBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              borderSide: BorderSide(color: colors.metricPanelBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              borderSide: BorderSide(color: colors.focus, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill lựa chọn đồng bộ `.filter-pill` trong `tab5-profile.js` & `tokens.css`.
/// Co gọn theo chiều rộng nội dung để xếp ngang tự nhiên bên trong [Wrap].
class ProfileFilterPill extends StatelessWidget {
  const ProfileFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? colors.chipActiveBg : colors.metricPanelBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: selected
                ? MetaGymTheme.brandOrange
                : colors.metricPanelBorder,
            width: selected ? 1.25 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
          highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.08),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 11 : 14,
              vertical: compact ? 6 : 8,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? colors.chipActiveText : colors.textWarmMuted,
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dòng thông tin cặp khóa – giá trị thích ứng Dark + Light.
class ProfileInfoKeyValueRow extends StatelessWidget {
  const ProfileInfoKeyValueRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.tabularFigures = false,
    super.key,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool tabularFigures;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? colors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontFeatures: tabularFigures
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal chọn nguồn cập nhật ảnh đại diện (Level 3 Overlay Glass khớp `screens-preview.html` 6b).
Future<ProfileAvatarAction?> showProfileAvatarPickerSheet(
  BuildContext context, {
  required PhotoAccessMode accessMode,
  required bool hasCustomAvatar,
}) {
  return showDialog<ProfileAvatarAction>(
    context: context,
    barrierColor: MetaGymColors.of(context).scrim,
    builder: (ctx) {
      final colors = MetaGymColors.of(ctx);
      final disableAnimations = MediaQuery.disableAnimationsOf(ctx);
      final isGranted =
          accessMode == PhotoAccessMode.full ||
          accessMode == PhotoAccessMode.selectedOnly;
      final sheet = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: colors.overlayGlass,
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
              border: Border.all(color: colors.overlayGlassBorder, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 36,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cập nhật ảnh đại diện',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (isGranted ? colors.success : colors.warning)
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusFull,
                        ),
                      ),
                      child: Text(
                        isGranted ? 'Đã cấp quyền ảnh' : 'Cần quyền ảnh',
                        style: TextStyle(
                          color: isGranted ? colors.success : colors.warning,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Chọn nguồn tải ảnh mới cho hồ sơ của bạn',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                _AvatarActionOption(
                  svgAsset: MetaGymIcons.commonCamera,
                  accentColor: MetaGymTheme.brandOrange,
                  title: 'Chụp ảnh mới',
                  subtitle: 'Mở camera trước hoặc sau',
                  onTap: () =>
                      Navigator.of(ctx).pop(ProfileAvatarAction.camera),
                ),
                const SizedBox(height: 8),
                _AvatarActionOption(
                  svgAsset: MetaGymIcons.mediaGallery,
                  accentColor: colors.info,
                  title: 'Chọn từ thư viện ảnh',
                  subtitle: 'Hỗ trợ JPG, PNG · Tối đa 5MB',
                  onTap: () =>
                      Navigator.of(ctx).pop(ProfileAvatarAction.gallery),
                ),
                if (hasCustomAvatar) ...[
                  const SizedBox(height: 8),
                  MetaGymTap(
                    onTap: () =>
                        Navigator.of(ctx).pop(ProfileAvatarAction.remove),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.error.withValues(alpha: 0.34),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Xóa ảnh đại diện hiện tại',
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      backgroundColor: colors.surfaceRaised,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final child = Center(
        child: Padding(padding: const EdgeInsets.all(20), child: sheet),
      );
      if (disableAnimations || MetaGymTheme.isFlutterTestEnvironment) {
        return child;
      }
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: math.min(MetaGymTheme.overlayGlassBlur, 14),
          sigmaY: math.min(MetaGymTheme.overlayGlassBlur, 14),
        ),
        child: child,
      );
    },
  );
}

class _AvatarActionOption extends StatelessWidget {
  const _AvatarActionOption({
    required this.svgAsset,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String svgAsset;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.38)),
              ),
              alignment: Alignment.center,
              child: MetaGymIcon(
                svgAsset,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal xác nhận đăng xuất (Level 3 Overlay Glass khớp preview `5.1` trong `tab5-profile.js`).
Future<bool?> showProfileSignOutDialog(
  BuildContext context, {
  required String fullName,
  required String email,
  required String roleLabel,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: MetaGymColors.of(context).scrim,
    builder: (ctx) {
      final colors = MetaGymColors.of(ctx);
      final disableAnimations = MediaQuery.disableAnimationsOf(ctx);
      final sheet = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              color: colors.overlayGlass,
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
              border: Border.all(color: colors.overlayGlassBorder, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 36,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.error.withValues(alpha: 0.16),
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.45),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: MetaGymIcon(
                    MetaGymIcons.settingLogout,
                    size: MetaGymIconSize.md,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Đăng xuất tài khoản?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bạn sẽ cần đăng nhập lại để quẹt thẻ NFC, xem lịch Coach và đồng bộ nhật ký tập luyện.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'Tài khoản Meta Gym' : fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email.isEmpty ? roleLabel : '$email · $roleLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            backgroundColor: colors.surfaceRaised,
                            side: BorderSide(color: colors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.error,
                            foregroundColor: MetaGymTheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text(
                            'Đăng xuất',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final child = Center(
        child: Padding(padding: const EdgeInsets.all(20), child: sheet),
      );
      if (disableAnimations || MetaGymTheme.isFlutterTestEnvironment) {
        return child;
      }
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: math.min(MetaGymTheme.overlayGlassBlur, 14),
          sigmaY: math.min(MetaGymTheme.overlayGlassBlur, 14),
        ),
        child: child,
      );
    },
  );
}
