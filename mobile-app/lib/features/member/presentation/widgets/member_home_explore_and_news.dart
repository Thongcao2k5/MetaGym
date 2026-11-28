import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_3d_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Khu vực "Khám phá Meta Gym" (lưới 4 ô SVG) & "Tin tức & Bài viết" (thẻ Level 1 đặc)
/// đồng bộ 1:1 với `tab1-home.js`.
class MemberHomeExploreGrid extends StatelessWidget {
  const MemberHomeExploreGrid({
    required this.onOpenAll,
    required this.onOpenEquipment,
    required this.onOpenVisits,
    required this.onOpenMeasurements,
    required this.onOpenCoach,
    super.key,
  });

  final VoidCallback onOpenAll;
  final VoidCallback onOpenEquipment;
  final VoidCallback onOpenVisits;
  final VoidCallback onOpenMeasurements;
  final VoidCallback onOpenCoach;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const MetaGymSvgIcon(
              MetaGymIcons.exerciseStepGuide,
              size: 18,
              fallbackIcon: Icons.explore_outlined,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Khám phá Meta Gym',
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
              onTap: onOpenAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  'Tất cả ›',
                  style: TextStyle(
                    color: palette.reflection,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ExploreTile(
                label: 'Thiết bị',
                icon3dAsset: MetaGym3dIcons.equipMachine,
                fallbackIcon: Icons.fitness_center_outlined,
                onTap: onOpenEquipment,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExploreTile(
                label: 'Điểm danh',
                icon3dAsset: MetaGym3dIcons.checkinBadge,
                fallbackIcon: Icons.qr_code_scanner_rounded,
                onTap: onOpenVisits,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExploreTile(
                label: 'Chỉ số',
                icon3dAsset: MetaGym3dIcons.bodyWeightScale,
                fallbackIcon: Icons.monitor_weight_outlined,
                onTap: onOpenMeasurements,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ExploreTile(
                label: 'Coach',
                icon3dAsset: MetaGym3dIcons.coachSearch,
                fallbackIcon: Icons.groups_outlined,
                onTap: onOpenCoach,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({
    required this.label,
    required this.icon3dAsset,
    required this.fallbackIcon,
    required this.onTap,
  });

  final String label;
  final String icon3dAsset;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
      solid: false,
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            MetaGym3dIcon(icon3dAsset, size: 36, fallbackIcon: fallbackIcon),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Danh sách 2 bài viết nổi bật dùng bề mặt đặc Level 1 (`#181B22` + viền 1px `#262A34`).
class MemberHomeArticlesSection extends StatelessWidget {
  const MemberHomeArticlesSection({
    required this.onOpenGymIntro,
    required this.onOpenBeginnerGuide,
    super.key,
  });

  final VoidCallback onOpenGymIntro;
  final VoidCallback onOpenBeginnerGuide;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Tin tức & Bài viết',
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
              onTap: onOpenBeginnerGuide,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Text(
                  'Xem thêm ›',
                  style: TextStyle(
                    color: palette.reflection,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ArticleCard(
          category: 'Kiến thức tập luyện',
          categoryColor: palette.primaryText,
          readTime: '4 phút đọc',
          title: 'Nguyên tắc tăng tiến tải trọng (Progressive Overload)',
          excerpt:
              'Cách ghi tạ và phục hồi hiệu quả để tăng cơ bền vững...',
          onTap: onOpenBeginnerGuide,
        ),
        const SizedBox(height: 8),
        _ArticleCard(
          category: 'Dinh dưỡng',
          categoryColor: palette.success,
          readTime: '3 phút đọc',
          title: 'Bữa ăn trước & sau tập giúp tối ưu tổng hợp đạm',
          excerpt:
              'Khung giờ vàng nạp carb và protein cho buổi tập 90 phút...',
          onTap: onOpenGymIntro,
        ),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.category,
    required this.categoryColor,
    required this.readTime,
    required this.title,
    required this.excerpt,
    required this.onTap,
  });

  final String category;
  final Color categoryColor;
  final String readTime;
  final String title;
  final String excerpt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
      solid: false,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusFull,
                    ),
                  ),
                  child: Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                readTime,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
