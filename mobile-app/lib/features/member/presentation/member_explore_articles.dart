import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

enum ExploreArticleType { gymIntroduction, beginnerGuide }

class ExploreArticleSection {
  const ExploreArticleSection({
    required this.heading,
    required this.paragraphs,
    this.bullets = const [],
  });

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
}

class ExploreArticleItem {
  const ExploreArticleItem({
    required this.id,
    required this.type,
    required this.eyebrow,
    required this.title,
    required this.shortDescription,
    required this.categoryLabel,
    required this.categoryColor,
    required this.readTimeLabel,
    required this.publishedDateLabel,
    required this.authorInitials,
    required this.authorName,
    required this.sections,
    required this.practiceTipTitle,
    required this.practiceTipBody,
    required this.ctaLabel,
    required this.ctaRoute,
    required this.imageAsset,
  });

  final String id;
  final ExploreArticleType type;
  final String eyebrow;
  final String title;
  final String shortDescription;
  final String categoryLabel;
  final Color categoryColor;
  final String readTimeLabel;
  final String publishedDateLabel;
  final String authorInitials;
  final String authorName;
  final List<ExploreArticleSection> sections;
  final String practiceTipTitle;
  final String practiceTipBody;
  final String ctaLabel;
  final String ctaRoute;
  final String imageAsset;
}

/// Hai bài viết kiến thức & dinh dưỡng đồng bộ 1:1 với mục "Tin tức & Bài viết"
/// trên Trang chủ và màn hình 1.5 Chi tiết bài viết.
const List<ExploreArticleItem> kMemberExploreArticles = [
  ExploreArticleItem(
    id: 'pre-post-workout-nutrition',
    type: ExploreArticleType.gymIntroduction,
    eyebrow: 'DINH DƯỠNG & PHỤC HỒI',
    title: 'Bữa ăn trước & sau tập giúp tối ưu tổng hợp đạm',
    shortDescription:
        'Khung giờ vàng nạp carb và protein cho buổi tập 90 phút để tối đa hiệu suất và phục hồi cơ.',
    categoryLabel: 'Dinh dưỡng',
    categoryColor: MetaGymTheme.progressGreen,
    readTimeLabel: '3 phút đọc',
    publishedDateLabel: '21/11/2026',
    authorInitials: 'LN',
    authorName: 'HLV Lê Hoàng Nam',
    sections: [
      ExploreArticleSection(
        heading: '1. Trước buổi tập 60–90 phút nên ăn gì?',
        paragraphs: [
          'Một bữa ăn giàu tinh bột hấp thu vừa kết hợp lượng đạm nhẹ bụng giúp duy trì năng lượng ổn định suốt 90 phút tập tạ mà không gây nặng bụng.',
        ],
        bullets: [
          '35–45g tinh bột sạch: khoai lang hấp, yến mạch hoặc 1 quả chuối chín.',
          '25–30g đạm nhanh: 100g ức gà áp chảo hoặc 1 muỗng Whey Protein Isolate.',
          'Uống trước 400ml nước lọc để hạn chế chuột rút và hụt sức ở hiệp cuối.',
        ],
      ),
      ExploreArticleSection(
        heading: '2. Tối ưu tổng hợp đạm sau buổi tập',
        paragraphs: [
          'Trong vòng 45–60 phút sau khi kết thúc buổi tập, cơ bắp nhạy cảm nhất với axit amin và glycogen. Đừng bỏ qua bữa ăn phục hồi này.',
        ],
        bullets: [
          'Nạp tối thiểu 30–40g đạm chất lượng cao (ức gà, cá hồi, trứng, Whey).',
          'Bổ sung 50–60g tinh bột để lấp đầy glycogen cho buổi tập ngày hôm sau.',
          'Theo dõi tổng đạm cả ngày đạt 1.8–2.0g / kg cân nặng trong mục Dinh dưỡng.',
        ],
      ),
    ],
    practiceTipTitle: 'Gợi ý thực hành ngay',
    practiceTipBody:
        'Ghi lại bữa ăn trước và sau tập hôm nay để kiểm tra mức đạm (Protein) đạt mục tiêu 180g/ngày.',
    ctaLabel: 'Mở Dinh dưỡng hôm nay →',
    ctaRoute: '/member/features/nutrition',
    imageAsset: 'assets/images/gym_banner.png',
  ),
  ExploreArticleItem(
    id: 'progressive-overload-guide',
    type: ExploreArticleType.beginnerGuide,
    eyebrow: 'KIẾN THỨC TẬP LUYỆN',
    title: 'Nguyên tắc tăng tiến tải trọng (Progressive Overload)',
    shortDescription:
        'Cách ghi tạ và phục hồi hiệu quả để tăng cơ bền vững mỗi tuần.',
    categoryLabel: 'Kiến thức tập luyện',
    categoryColor: MetaGymTheme.brandOrange,
    readTimeLabel: '4 phút đọc',
    publishedDateLabel: '22/11/2026',
    authorInitials: 'LN',
    authorName: 'HLV Lê Hoàng Nam',
    sections: [
      ExploreArticleSection(
        heading: '1. Progressive Overload là gì?',
        paragraphs: [
          'Tăng tiến tải trọng là việc tăng dần áp lực lên cơ bắp theo thời gian — có thể tăng mức tạ (+2.5 kg), tăng số lần lặp (+1–2 reps) hoặc cải thiện tốc độ kiểm soát nhịp tạ (tempo).',
        ],
      ),
      ExploreArticleSection(
        heading: '2. Cách áp dụng an toàn mỗi tuần',
        paragraphs: [],
        bullets: [
          'Ghi lại mức tạ & số reps sau mỗi buổi trong Nhật ký tập luyện.',
          'Khi hoàn thành đủ 4 hiệp × 10 reps đúng kỹ thuật, tăng thêm 2.5 kg ở tuần kế tiếp.',
          'Đảm bảo ngủ đủ 7–8 tiếng và nạp đủ 1.8–2.0g đạm / kg cân nặng.',
        ],
      ),
    ],
    practiceTipTitle: 'Gợi ý thực hành ngay',
    practiceTipBody:
        'Mở Nhật ký tập luyện để lưu lại kỷ lục mức tạ (PR) buổi tập tối nay.',
    ctaLabel: 'Mở Nhật ký tập luyện →',
    ctaRoute: '/member/features/workouts',
    imageAsset: 'assets/images/gym_banner.png',
  ),
];

/// Trang danh sách bài viết kiến thức & dinh dưỡng đồng bộ Warm Smoked Glass.
class MemberExploreListPage extends StatelessWidget {
  const MemberExploreListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      MetaGymCircleIconButton(
                        svgAsset: MetaGymIcons.commonBack,
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'KIẾN THỨC & CẨM NANG',
                              style: TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tin tức & Bài viết',
                              style: TextStyle(
                                color: MetaGymTheme.textPrimary,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                    itemCount: kMemberExploreArticles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final article = kMemberExploreArticles[index];
                      return MetaGymGlassCard(
                        solid: false,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => MemberExploreArticleDetailPage(
                                article: article,
                              ),
                            ),
                          );
                        },
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: article.categoryColor.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: article.categoryColor.withValues(
                                        alpha: 0.42,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    article.categoryLabel,
                                    style: TextStyle(
                                      color: article.categoryColor,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${article.readTimeLabel} · ${article.publishedDateLabel}',
                                  style: const TextStyle(
                                    color: MetaGymTheme.textSecondary,
                                    fontSize: 11.5,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              article.title,
                              style: const TextStyle(
                                color: MetaGymTheme.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              article.shortDescription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD5CCBF),
                                fontSize: 12.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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

/// Màn hình 1.5 Chi tiết bài viết đồng bộ Warm Smoked Glass + nút Lưu bài viết.
class MemberExploreArticleDetailPage extends StatefulWidget {
  const MemberExploreArticleDetailPage({required this.article, super.key});

  final ExploreArticleItem article;

  @override
  State<MemberExploreArticleDetailPage> createState() =>
      _MemberExploreArticleDetailPageState();
}

class _MemberExploreArticleDetailPageState
    extends State<MemberExploreArticleDetailPage> {
  bool _bookmarked = false;

  void _toggleBookmark() {
    setState(() => _bookmarked = !_bookmarked);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2B2622),
          content: Text(
            _bookmarked ? 'Đã lưu bài viết vào danh sách đọc.' : 'Đã bỏ lưu bài viết.',
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  void _openCta() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(widget.article.ctaRoute);
      return;
    }
    Navigator.of(context).maybePop();
  }

  Widget _buildBulletText(String text) {
    const highlight = 'Nhật ký tập luyện';
    final idx = text.indexOf(highlight);
    if (idx < 0) {
      return Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD5CCBF),
          fontSize: 13,
          height: 1.55,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: Color(0xFFD5CCBF),
          fontSize: 13,
          height: 1.55,
        ),
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: highlight,
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (idx + highlight.length < text.length)
            TextSpan(text: text.substring(idx + highlight.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header chuẩn 1.5
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      MetaGymCircleIconButton(
                        svgAsset: MetaGymIcons.commonBack,
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.eyebrow,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Chi tiết bài viết',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MetaGymTheme.textPrimary,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: _bookmarked
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                color: MetaGymTheme.brandOrange.withValues(
                                  alpha: 0.22,
                                ),
                              )
                            : null,
                        child: MetaGymCircleIconButton(
                          svgAsset: MetaGymIcons.socialBookmark,
                          icon: _bookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          tooltip: _bookmarked ? 'Bỏ lưu bài viết' : 'Lưu bài',
                          onTap: _toggleBookmark,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 40),
                    children: [
                      // 1. Thẻ Hero tiêu đề + Tác giả (Warm Smoked Glass)
                      MetaGymGlassCard(
                        solid: false,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: article.categoryColor.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: article.categoryColor.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    article.categoryLabel,
                                    style: TextStyle(
                                      color: article.categoryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${article.readTimeLabel} · ${article.publishedDateLabel}',
                                  style: const TextStyle(
                                    color: MetaGymTheme.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    fontFeatures: MetaGymTheme.tabularFigures,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              article.title,
                              style: const TextStyle(
                                color: MetaGymTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF5B041),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    article.authorInitials,
                                    style: const TextStyle(
                                      color: Color(0xFF181B22),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'Biên soạn bởi ',
                                      style: const TextStyle(
                                        color: MetaGymTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: article.authorName,
                                          style: const TextStyle(
                                            color: MetaGymTheme.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 2. Thẻ Nội dung chi tiết + Gợi ý thực hành + Nút CTA
                      MetaGymGlassCard(
                        solid: false,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < article.sections.length; i++) ...[
                              if (i > 0) const SizedBox(height: 11),
                              Text(
                                article.sections[i].heading,
                                style: const TextStyle(
                                  color: MetaGymTheme.textPrimary,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.32,
                                ),
                              ),
                              const SizedBox(height: 5),
                              for (final p in article.sections[i].paragraphs)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Text(
                                    p,
                                    style: const TextStyle(
                                      color: Color(0xFFD5CCBF),
                                      fontSize: 13,
                                      height: 1.55,
                                    ),
                                  ),
                                ),
                              for (final b in article.sections[i].bullets)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '•  ',
                                        style: TextStyle(
                                          color: MetaGymTheme.brandOrange,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          height: 1.48,
                                        ),
                                      ),
                                      Expanded(child: _buildBulletText(b)),
                                    ],
                                  ),
                                ),
                            ],
                            const SizedBox(height: 9),

                            // Hộp Gợi ý thực hành ngay
                            MetaGymMetricPanel(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: MetaGymSvgIcon(
                                      MetaGymIcons.exerciseStepGuide,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          article.practiceTipTitle,
                                          style: const TextStyle(
                                            color: MetaGymTheme.brandOrange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          article.practiceTipBody,
                                          style: const TextStyle(
                                            color: Color(0xFFE0D9CE),
                                            fontSize: 12.2,
                                            height: 1.42,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 11),

                            // Nút CTA hành động chính
                            SizedBox(
                              height: 48,
                              child: FilledButton(
                                key: const Key('article-detail-cta'),
                                onPressed: _openCta,
                                style: FilledButton.styleFrom(
                                  backgroundColor: MetaGymTheme.brandOrange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  article.ctaLabel,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
