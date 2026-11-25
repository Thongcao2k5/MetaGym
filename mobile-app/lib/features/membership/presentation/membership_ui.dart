import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

final NumberFormat _vndCurrency = NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
);

String formatMembershipMoney(num amount) => _vndCurrency.format(amount);

String formatMembershipDate(String value) {
  final trimmed = value.trim();
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
}

String formatMembershipDateTime(String value) {
  final trimmed = value.trim();
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return trimmed;
  final local = parsed.toLocal();
  if (trimmed.length <= 10) return DateFormat('dd/MM/yyyy').format(local);
  return DateFormat('dd/MM/yyyy HH:mm').format(local);
}

String formatPaymentMethodLabel(String? method) => switch (method) {
  'MOCK_QR' => 'VNPAY-QR (Giả lập)',
  'VNPAY' => 'VNPay Sandbox',
  'MOMO' => 'MoMo Sandbox',
  'ZALOPAY' => 'ZaloPay Sandbox',
  _ => method ?? 'Chưa xác định',
};

Color membershipStatusColor(String status) => switch (status) {
  'ACTIVE' || 'SUCCESS' => MetaGymTheme.progressGreen,
  'SCHEDULED' => MetaGymTheme.reflectionBlue,
  'PENDING' => MetaGymTheme.warningAmber,
  'CANCELLED' || 'FAILED' => MetaGymTheme.dangerCoral,
  _ => const Color(0xFF9AA3B2),
};

/// Thanh tiêu đề đồng bộ Warm Smoked Glass cho cụm màn hình Gói tập & Giao dịch.
class MembershipTopBar extends StatelessWidget {
  const MembershipTopBar({
    required this.eyebrow,
    required this.title,
    this.actions = const [],
    this.onBack,
    super.key,
  });

  final String eyebrow;
  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = onBack != null || Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              icon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Pill hiển thị trạng thái hoặc nhãn phân hạng theo hệ màu semantic Meta Gym.
class MembershipStatusPill extends StatelessWidget {
  const MembershipStatusPill({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.5, color: color),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiêu đề phân mục thống nhất trên các trang Gói tập.
class MembershipSectionHeader extends StatelessWidget {
  const MembershipSectionHeader({
    required this.title,
    this.icon,
    this.iconColor = MetaGymTheme.brandOrange,
    this.svgAsset,
    this.trailing,
    super.key,
  });

  final IconData? icon;
  final Color iconColor;
  final String? svgAsset;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          if (svgAsset != null) ...[
            MetaGymSvgIcon(svgAsset!, size: 19),
            const SizedBox(width: 8),
          ] else if (icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: iconColor.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MetaGymTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Thẻ thông báo lỗi chuẩn Meta Gym.
class MembershipErrorCard extends StatelessWidget {
  const MembershipErrorCard({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x2EF15B64),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x70F15B64)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    color: Color(0xFFFFB2AF),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: MetaGymTheme.brandOrange,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text(
                  'Thử lại',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nút hành động chính màu cam Meta Gym (đạt tối thiểu 48dp chiều cao).
class MembershipPrimaryButton extends StatelessWidget {
  const MembershipPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 14 : 15,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 14 : 15,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18),
            ],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 44 : 50),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: MetaGymTheme.brandOrange,
          disabledBackgroundColor: MetaGymTheme.brandOrange.withValues(
            alpha: 0.45,
          ),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 18 : 20,
            vertical: compact ? 11 : 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

/// Khung mã QR VNPAY-QR giả lập sắc nét vẽ bằng CustomPaint từ chuỗi `payload`.
class SimulatedVnPayQrBox extends StatelessWidget {
  const SimulatedVnPayQrBox({required this.payload, super.key});

  final String payload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          width: 118,
          height: 118,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(118),
                painter: _DeterministicQrPainter(payload: payload),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE5E9F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: MetaGymTheme.brandOrange,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'MG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeterministicQrPainter extends CustomPainter {
  const _DeterministicQrPainter({required this.payload});

  final String payload;

  static const int _gridSize = 21;

  bool _isInFinder(int row, int col) {
    final topLeft = row < 7 && col < 7;
    final topRight = row < 7 && col >= _gridSize - 7;
    final bottomLeft = row >= _gridSize - 7 && col < 7;
    return topLeft || topRight || bottomLeft;
  }

  bool _isInSeparator(int row, int col) {
    final nearTopLeft = row <= 7 && col <= 7 && !_isInFinder(row, col);
    final nearTopRight =
        row <= 7 && col >= _gridSize - 8 && !_isInFinder(row, col);
    final nearBottomLeft =
        row >= _gridSize - 8 && col <= 7 && !_isInFinder(row, col);
    return nearTopLeft || nearTopRight || nearBottomLeft;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _gridSize;
    final darkPaint = Paint()..color = const Color(0xFF0E131A);
    final accentPaint = Paint()..color = MetaGymTheme.brandOrange;

    int seed = 0x811C9DC5;
    for (final unit in payload.codeUnits) {
      seed ^= unit;
      seed = (seed * 0x01000193) & 0x7FFFFFFF;
    }
    final rng = math.Random(seed == 0 ? 42 : seed);

    for (var row = 0; row < _gridSize; row++) {
      for (var col = 0; col < _gridSize; col++) {
        // Vùng logo trung tâm 5x5 giữ trống.
        if (row >= 8 && row <= 12 && col >= 8 && col <= 12) continue;

        if (_isInFinder(row, col) || _isInSeparator(row, col)) continue;

        final isTiming = (row == 6 || col == 6) && (row + col).isEven;
        final draw = isTiming || rng.nextDouble() > 0.48;
        if (draw) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                col * cell + 0.35,
                row * cell + 0.35,
                cell - 0.7,
                cell - 0.7,
              ),
              Radius.circular(cell * 0.22),
            ),
            darkPaint,
          );
        }
      }
    }

    _drawFinder(canvas, 0, 0, cell, darkPaint, accentPaint);
    _drawFinder(canvas, 0, _gridSize - 7, cell, darkPaint, accentPaint);
    _drawFinder(canvas, _gridSize - 7, 0, cell, darkPaint, accentPaint);
  }

  void _drawFinder(
    Canvas canvas,
    int startRow,
    int startCol,
    double cell,
    Paint outerPaint,
    Paint innerPaint,
  ) {
    final left = startCol * cell;
    final top = startRow * cell;
    final outerRect = Rect.fromLTWH(left, top, cell * 7, cell * 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, Radius.circular(cell * 1.1)),
      outerPaint,
    );

    final holePaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + cell, top + cell, cell * 5, cell * 5),
        Radius.circular(cell * 0.65),
      ),
      holePaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + cell * 2, top + cell * 2, cell * 3, cell * 3),
        Radius.circular(cell * 0.45),
      ),
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DeterministicQrPainter oldDelegate) =>
      oldDelegate.payload != payload;
}
