import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

class _FanTierItem {
  const _FanTierItem({
    required this.badge,
    required this.title,
    required this.price,
    required this.subtitle,
    required this.frontAsset,
    required this.backAsset,
    required this.accentColor,
  });

  final String badge;
  final String title;
  final String price;
  final String subtitle;
  final String frontAsset;
  final String backAsset;
  final Color accentColor;
}

/// Khu vực "Đặc quyền Hội viên" dạng bộ thẻ quạt 4 hạng (Đồng / Bạc / Vàng / Kim Cương)
/// sử dụng thẻ đứng chuẩn CR80, hỗ trợ vuốt ngang mượt và chạm thẻ giữa để lật 3D xem mặt sau.
class MemberHomeFanDeck extends StatefulWidget {
  const MemberHomeFanDeck({required this.onOpenMembership, super.key});

  final VoidCallback onOpenMembership;

  @override
  State<MemberHomeFanDeck> createState() => _MemberHomeFanDeckState();
}

class _MemberHomeFanDeckState extends State<MemberHomeFanDeck> {
  static const _tiers = <_FanTierItem>[
    _FanTierItem(
      badge: 'Hạng Đồng · 1 Tháng',
      title: 'Thẻ Đồng — Starter',
      price: '890.000đ / tháng',
      subtitle: 'Quẹt thẻ NFC vào phòng tập · Tủ khóa cá nhân',
      frontAsset: 'assets/images/membership/card_bronze.jpg',
      backAsset: 'assets/images/membership/card_bronze_horizontal.jpg',
      accentColor: Color(0xFFCD8B5B),
    ),
    _FanTierItem(
      badge: 'Hạng Bạc · 3 Tháng',
      title: 'Thẻ Bạc — Plus',
      price: '2.490.000đ / 3 tháng',
      subtitle: 'Quẹt thẻ NFC · Tặng 1 lần InBody · Giảm 3% PT',
      frontAsset: 'assets/images/membership/card_silver.jpg',
      backAsset: 'assets/images/membership/card_silver_horizontal.jpg',
      accentColor: Color(0xFFA9C7E8),
    ),
    _FanTierItem(
      badge: 'Phổ biến nhất · 6 Tháng',
      title: 'Thẻ Vàng — Pro VIP',
      price: '4.490.000đ / 6 tháng',
      subtitle: 'Quẹt thẻ NFC · InBody hàng tháng · Tặng 2 buổi PT 1:1',
      frontAsset: 'assets/images/membership/card_gold.jpg',
      backAsset: 'assets/images/membership/card_gold_horizontal.jpg',
      accentColor: Color(0xFFF5B041),
    ),
    _FanTierItem(
      badge: 'Kim Cương · 12 Tháng',
      title: 'Thẻ Kim Cương — Elite',
      price: '8.490.000đ / năm',
      subtitle: 'Thẻ kim loại VIP · InBody không giới hạn · Ưu tiên Coach',
      frontAsset: 'assets/images/membership/card_diamond.jpg',
      backAsset: 'assets/images/membership/card_diamond_horizontal.jpg',
      accentColor: Color(0xFF70AEE8),
    ),
  ];

  int _activeIndex = 2; // Mặc định: Thẻ Vàng — Pro VIP
  bool _centerFlipped = false;
  double _dragAccumX = 0.0;
  bool _isDragging = false;

  void _selectIndex(int index, {bool toggleIfActive = false}) {
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      HapticFeedback.lightImpact();
    }
    final normalized = (index + _tiers.length) % _tiers.length;
    setState(() {
      if (normalized == _activeIndex && toggleIfActive) {
        _centerFlipped = !_centerFlipped;
      } else if (normalized != _activeIndex) {
        _activeIndex = normalized;
        _centerFlipped = false;
      }
      _dragAccumX = 0.0;
      _isDragging = false;
    });
  }

  int _relativePosition(int index) {
    final diff = (index - _activeIndex + _tiers.length) % _tiers.length;
    if (diff == 0) return 0; // Center
    if (diff == 1) return 1; // Right
    if (diff == _tiers.length - 1) return -1; // Left
    return 2; // Back
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final reducedMotion =
        MetaGymTheme.isFlutterTestEnvironment ||
        MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    final activeTier = _tiers[_activeIndex];

    // Vẽ từ sau ra trước: pos 2 -> pos -1 & 1 -> pos 0 (nổi trên cùng)
    final drawOrder = List<int>.generate(_tiers.length, (i) => i)
      ..sort((a, b) {
        int priority(int pos) => switch (pos) {
          2 => 0,
          -1 => 1,
          1 => 2,
          _ => 3,
        };
        return priority(_relativePosition(a))
            .compareTo(priority(_relativePosition(b)));
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const MetaGymSvgIcon(
              MetaGymIcons.premiumCrown,
              size: 18,
              fallbackIcon: Icons.workspace_premium_outlined,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Đặc quyền Hội viên',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            InkWell(
              onTap: widget.onOpenMembership,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  'Xem tất cả ›',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Sân khấu thẻ quạt ngang CR80 full-bleed tràn sát 2 mép màn hình + lật 3D
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) {
            setState(() {
              _isDragging = true;
              _dragAccumX = 0.0;
            });
          },
          onHorizontalDragUpdate: (details) {
            setState(() => _dragAccumX += details.delta.dx);
          },
          onHorizontalDragEnd: (details) {
            final vx = details.primaryVelocity ?? 0;
            if (vx < -140 || _dragAccumX < -44) {
              _selectIndex(_activeIndex + 1);
            } else if (vx > 140 || _dragAccumX > 44) {
              _selectIndex(_activeIndex - 1);
            } else {
              setState(() {
                _isDragging = false;
                _dragAccumX = 0.0;
              });
            }
          },
          onHorizontalDragCancel: () {
            setState(() {
              _isDragging = false;
              _dragAccumX = 0.0;
            });
          },
          child: Builder(
            builder: (context) {
              final screenW = MediaQuery.sizeOf(context).width;
              final cardW = (screenW * 0.51).clamp(174.0, 224.0);
              final cardH = (cardW * 1.44).clamp(250.0, 322.0);
              final sideOffset = (screenW * 0.345).clamp(118.0, 165.0);
              final stageH = cardH + 22.0;
              final dragOffset = (_dragAccumX * 0.28).clamp(-38.0, 38.0);
              return SizedBox(
                height: stageH,
                width: double.infinity,
                child: OverflowBox(
                  maxWidth: screenW,
                  minWidth: screenW,
                  maxHeight: stageH,
                  minHeight: stageH,
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final idx in drawOrder)
                          _buildFanCard(
                            idx: idx,
                            pos: _relativePosition(idx),
                            centerX: screenW / 2,
                            cardW: cardW,
                            cardH: cardH,
                            sideOffset: sideOffset,
                            dragOffset: dragOffset,
                            reducedMotion: reducedMotion,
                            duration: duration,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Khối thông tin trong suốt hoàn toàn ngay dưới bộ thẻ (không khung hộp)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey<int>(_activeIndex),
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: palette.primaryText,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            activeTier.badge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeTier.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeTier.price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      activeTier.subtitle,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_tiers.length, (i) {
                      final active = i == _activeIndex;
                      return GestureDetector(
                        onTap: () => _selectIndex(i),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3.5,
                            vertical: 8,
                          ),
                          child: AnimatedContainer(
                            duration: duration,
                            curve: Curves.easeOutCubic,
                            width: active ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? MetaGymTheme.brandOrange
                                  : palette.textSecondary.withValues(
                                      alpha: 0.38,
                                    ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 14),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onOpenMembership,
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: MetaGymTheme.brandOrange.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: MetaGymTheme.brandOrange.withValues(
                              alpha: 0.55,
                            ),
                            width: 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Xem gói tập ›',
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
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
    );
  }

  Widget _buildCardFrame({
    required _FanTierItem tier,
    required String assetPath,
    required bool isCenter,
    int quarterTurns = 0,
    double extraShadow = 0.0,
  }) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: isCenter ? const Color(0x70FFE2BE) : const Color(0x2EFFFFFF),
        width: isCenter ? 1.2 : 0.9,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isCenter ? 0.56 : 0.30),
          blurRadius: (isCenter ? 24 : 12) + extraShadow * 10,
          offset: Offset(0, 10 + extraShadow * 6),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: RotatedBox(
      quarterTurns: quarterTurns,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Container(
          color: MetaGymTheme.elevatedSurface,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(
            tier.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildFanCard({
    required int idx,
    required int pos,
    required double centerX,
    required double cardW,
    required double cardH,
    required double sideOffset,
    required double dragOffset,
    required bool reducedMotion,
    required Duration duration,
  }) {
    final tier = _tiers[idx];
    final (dx, dy, angleDeg, scale, opacity) = switch (pos) {
      0 => (dragOffset, 4.0, 0.0, 1.0, 1.0),
      -1 => (
        -sideOffset + dragOffset * 0.35,
        18.0,
        -7.5,
        0.86,
        _centerFlipped ? 0.25 : 0.88,
      ),
      1 => (
        sideOffset + dragOffset * 0.35,
        18.0,
        7.5,
        0.86,
        _centerFlipped ? 0.25 : 0.88,
      ),
      _ => (0.0, 26.0, 0.0, 0.76, _centerFlipped ? 0.15 : 0.32),
    };

    final frontCard = _buildCardFrame(
      tier: tier,
      assetPath: tier.frontAsset,
      isCenter: pos == 0,
    );

    final faceContent = pos == 0
        ? TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _centerFlipped ? math.pi : 0.0),
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 560),
            curve: Curves.easeInOutCubic,
            builder: (context, flipAngle, _) {
              final showBack = flipAngle > math.pi / 2;
              final edgeSin = math.sin(flipAngle).abs();
              final liftScale = 1.0 + edgeSin * 0.03;
              final face = showBack
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: _buildCardFrame(
                        tier: tier,
                        assetPath: tier.backAsset,
                        isCenter: true,
                        quarterTurns: 1,
                        extraShadow: edgeSin,
                      ),
                    )
                  : _buildCardFrame(
                      tier: tier,
                      assetPath: tier.frontAsset,
                      isCenter: true,
                      extraShadow: edgeSin,
                    );

              return Transform.scale(
                scale: liftScale,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.00145)
                    ..rotateY(flipAngle),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        face,
                        if (edgeSin > 0.03)
                          IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(
                                    -0.85 + math.sin(flipAngle) * 1.1,
                                    -0.8,
                                  ),
                                  end: Alignment(
                                    0.85 + math.sin(flipAngle) * 1.1,
                                    0.8,
                                  ),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(
                                      alpha: (edgeSin * 0.24).clamp(0.0, 0.24),
                                    ),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        : frontCard;

    return AnimatedPositioned(
      key: ValueKey<String>('fan-card-$idx'),
      duration: _isDragging ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      left: centerX - (cardW / 2) + dx,
      top: dy,
      width: cardW,
      height: cardH,
      child: GestureDetector(
        onTap: () => _selectIndex(idx, toggleIfActive: true),
        child: AnimatedOpacity(
          duration: duration,
          opacity: opacity,
          child: AnimatedRotation(
            duration: duration,
            curve: Curves.easeOutCubic,
            turns: angleDeg / 360.0,
            child: AnimatedScale(
              duration: duration,
              curve: Curves.easeOutCubic,
              scale: scale,
              child: faceContent,
            ),
          ),
        ),
      ),
    );
  }
}
