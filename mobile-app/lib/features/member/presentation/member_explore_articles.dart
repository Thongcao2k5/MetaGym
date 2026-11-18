import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:provider/provider.dart';

enum ExploreArticleType { gymIntroduction, beginnerGuide }

class ExploreArticleItem {
  const ExploreArticleItem({
    required this.id,
    required this.type,
    required this.title,
    required this.shortDescription,
    required this.categoryLabel,
    required this.readTimeLabel,
    required this.imageAsset,
    required this.illustrationNotice,
  });

  final String id;
  final ExploreArticleType type;
  final String title;
  final String shortDescription;
  final String categoryLabel;
  final String readTimeLabel;
  final String imageAsset;
  final String illustrationNotice;
}

/// Hai bài biên tập chuyên đề phục vụ mục "Khám phá Meta Gym" trên Trang chủ Hội viên.
const List<ExploreArticleItem> kMemberExploreArticles = [
  ExploreArticleItem(
    id: 'explore-meta-gym',
    type: ExploreArticleType.gymIntroduction,
    title: 'Khám phá phòng tập Meta Gym',
    shortDescription:
        'Không gian tập luyện, danh mục thiết bị, đội ngũ PT và giờ mở cửa.',
    categoryLabel: 'Cơ sở & Thiết bị',
    readTimeLabel: '3 phút đọc',
    imageAsset: 'assets/images/gym_banner.png',
    illustrationNotice:
        'Thông tin cơ sở, thiết bị và đội ngũ PT bên dưới được đồng bộ trực tiếp từ dữ liệu xác thực của hệ thống.',
  ),
  ExploreArticleItem(
    id: 'beginner-training-guide',
    type: ExploreArticleType.beginnerGuide,
    title: 'Hướng dẫn tập luyện cho người mới',
    shortDescription:
        'Nguyên tắc khởi động, chọn mức tạ an toàn và xây dựng lịch tập tuần đầu.',
    categoryLabel: 'Cẩm nang người mới',
    readTimeLabel: '4 phút đọc',
    imageAsset: 'assets/images/gym_banner.png',
    illustrationNotice:
        'Áp dụng quy trình 4 bước dưới đây để làm quen thiết bị an toàn và tối ưu hiệu quả trong 4 tuần đầu tiên.',
  ),
];

/// Trang danh sách chuyên đề khi bấm từ mục "Khám phá Meta Gym" trên Trang chủ.
/// Đồng bộ chuẩn Futuristic Performance Glass / Warm Smoked Glass (80/20 rule).
class MemberExploreListPage extends StatelessWidget {
  const MemberExploreListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFFF7F9FC),
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: MetaGymCircleIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Quay lại',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        titleSpacing: 8,
        title: const Text(
          'Khám phá Meta Gym',
          style: TextStyle(
            color: Color(0xFFF7F9FC),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            padding: EdgeInsets.fromLTRB(
              MetaGymTheme.pageGutter,
              MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
              MetaGymTheme.pageGutter,
              MediaQuery.paddingOf(context).bottom + 28,
            ),
            children: [
              MetaGymHeroGlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0x24FF5E36),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x4DFF5E36)),
                      ),
                      child: const Icon(
                        Icons.explore_outlined,
                        color: MetaGymTheme.brandOrange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cẩm nang & Không gian tập luyện',
                            style: TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tìm hiểu tiện ích phòng tập, chuẩn bị kỹ thuật và lộ trình khởi đầu an toàn.',
                            style: TextStyle(
                              color: Color(0xFFC8C2BC),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < kMemberExploreArticles.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _ExploreArticleCard(
                  article: kMemberExploreArticles[i],
                  showThumbnail: i == 0,
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => MemberExploreArticleDetailPage(
                          article: kMemberExploreArticles[i],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ExploreArticleCard extends StatelessWidget {
  const _ExploreArticleCard({
    required this.article,
    required this.showThumbnail,
    required this.onTap,
  });

  final ExploreArticleItem article;
  final bool showThumbnail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MetaGymGlassCard(
      padding: EdgeInsets.zero,
      child: ColoredBox(
        color: const Color(0xA0211E1C),
        child: InkWell(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showThumbnail)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: Image.asset(
                        article.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFF282320),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            color: MetaGymTheme.brandOrange,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0x24A9C7E8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x4DA9C7E8)),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: MetaGymTheme.reflectionBlue,
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${article.categoryLabel} · ${article.readTimeLabel}',
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.title,
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.shortDescription,
                        style: const TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFC8C2BC),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Trang chi tiết bài viết "Khám phá" đồng bộ chuẩn Futuristic Performance Glass.
/// Tóm tắt gọn thông tin cơ sở, số lượng thiết bị & đội ngũ Coach xác thực,
/// kết nối trực tiếp tới `GymEquipmentPage` và `CoachSelectionPage` mà không lặp lại nguyên trang.
class MemberExploreArticleDetailPage extends StatefulWidget {
  const MemberExploreArticleDetailPage({required this.article, super.key});

  final ExploreArticleItem article;

  @override
  State<MemberExploreArticleDetailPage> createState() =>
      _MemberExploreArticleDetailPageState();
}

class _MemberExploreArticleDetailPageState
    extends State<MemberExploreArticleDetailPage> {
  GymProfile? _gymProfile;
  List<CatalogItem> _equipment = const [];
  List<CoachProfile> _coaches = const [];
  bool _loadingGymData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.article.type == ExploreArticleType.gymIntroduction &&
        !_loadingGymData &&
        _gymProfile == null) {
      _loadVerifiedGymInfo();
    }
  }

  Future<void> _loadVerifiedGymInfo() async {
    setState(() => _loadingGymData = true);
    CatalogService? catalogService;
    CoachSelectionService? coachService;
    try {
      catalogService = context.read<CatalogService>();
    } catch (_) {}
    try {
      coachService = context.read<CoachSelectionService>();
    } catch (_) {}

    GymProfile? profile;
    List<CatalogItem> equipment = const [];
    List<CoachProfile> coaches = const [];

    if (catalogService != null) {
      try {
        profile = await catalogService.getGymProfile();
      } catch (_) {}
      try {
        final rawEquipment = await catalogService.getEquipment();
        equipment = rawEquipment
            .where((item) => item.status == 'ACTIVE')
            .toList();
      } catch (_) {}
    }

    if (coachService != null) {
      try {
        coaches = await coachService.getCoaches();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _gymProfile = profile;
      _equipment = equipment;
      _coaches = coaches;
      _loadingGymData = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFFF7F9FC),
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: MetaGymCircleIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Quay lại',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        titleSpacing: 8,
        title: Text(
          article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF7F9FC),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            padding: EdgeInsets.fromLTRB(
              MetaGymTheme.pageGutter,
              MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
              MetaGymTheme.pageGutter,
              MediaQuery.paddingOf(context).bottom + 32,
            ),
            children: [
              MetaGymHeroGlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 156,
                        width: double.infinity,
                        child: Image.asset(
                          article.imageAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFF282320),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.fitness_center_rounded,
                              color: MetaGymTheme.brandOrange,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x24FF5E36),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x4DFF5E36)),
                      ),
                      child: Text(
                        '${article.categoryLabel} · ${article.readTimeLabel}',
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      style: const TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.shortDescription,
                      style: const TextStyle(
                        color: Color(0xFFC8C2BC),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: MetaGymTheme.reflectionBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            article.illustrationNotice,
                            style: const TextStyle(
                              color: Color(0xFFC8C2BC),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (article.type == ExploreArticleType.gymIntroduction)
                _buildGymIntroductionBody(context)
              else
                _buildBeginnerGuideBody(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGymIntroductionBody(BuildContext context) {
    final gym = _gymProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loadingGymData)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: MetaGymTheme.brandOrange),
            ),
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetaGymMetricPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.fitness_center_rounded,
                            color: MetaGymTheme.brandOrange,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Thiết bị hoạt động',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFC8C2BC),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _equipment.isEmpty ? 'Sẵn sàng' : '${_equipment.length}',
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Kèm hướng dẫn & lưu ý an toàn',
                        style: TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetaGymMetricPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            color: MetaGymTheme.coachAvatarBackground,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Đội ngũ Coach',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFC8C2BC),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _coaches.isEmpty ? '1:1 PT' : '${_coaches.length}',
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Lịch 90 phút & giáo trình riêng',
                        style: TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          icon: Icons.location_on_outlined,
          iconColor: MetaGymTheme.brandOrange,
          title: 'Không gian & Giờ hoạt động',
          children: [
            Text(
              gym != null ? gym.name : 'Meta Gym Studio',
              style: const TextStyle(
                color: Color(0xFFF7F9FC),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              gym != null && gym.address.trim().isNotEmpty
                  ? 'Địa chỉ: ${gym.address}'
                  : 'Không gian được phân khu theo nhóm cơ, khu Free Weight, máy khối và khu khởi động chức năng.',
              style: const TextStyle(
                color: Color(0xFFC8C2BC),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            if (gym != null && gym.openingHours.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final entry in gym.openingHours.entries.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${entry.key}: ${entry.value}',
                    style: const TextStyle(
                      color: Color(0xFFC8C2BC),
                      fontSize: 13.5,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          icon: Icons.fitness_center_rounded,
          iconColor: MetaGymTheme.reflectionBlue,
          title: 'Tra cứu thiết bị & Đội ngũ PT',
          children: [
            const Text(
              'Tra cứu nhanh cách dùng từng máy, nhóm cơ tác động hoặc xem hồ sơ chuyên môn của các Huấn luyện viên đang mở nhận học viên.',
              style: TextStyle(
                color: Color(0xFFC8C2BC),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/member/features/gym'),
                style: FilledButton.styleFrom(
                  backgroundColor: MetaGymTheme.brandOrange,
                  foregroundColor: MetaGymTheme.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusInput,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Mở danh mục Phòng gym & thiết bị',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/member/features/coaching'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF7F9FC),
                  side: const BorderSide(color: Color(0xA3A79D92)),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusInput,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.person_search_rounded,
                  color: MetaGymTheme.coachAvatarBackground,
                  size: 18,
                ),
                label: const Text(
                  'Xem danh sách Coach thực tế',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBeginnerGuideBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailSection(
          icon: Icons.bolt_rounded,
          iconColor: MetaGymTheme.brandOrange,
          title: '1. Khởi động kỹ 8–10 phút trước mỗi buổi tập',
          children: const [
            Text(
              'Bắt đầu bằng 5 phút làm nóng toàn thân (đi bộ nhanh, xoay khớp vai, hông, cổ chân) và 1–2 hiệp khởi động nhẹ với chính bài tập chính trong ngày để cơ bắp và hệ thần kinh sẵn sàng.',
              style: TextStyle(
                color: Color(0xFFC8C2BC),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          icon: Icons.verified_user_outlined,
          iconColor: MetaGymTheme.success,
          title: '2. Ưu tiên kỹ thuật chuẩn trước khi tăng mức tạ',
          children: const [
            Text(
              'Trong 2–4 tuần đầu tiên, hãy chọn mức tạ mà bạn kiểm soát được trọn vẹn biên độ chuyển động từ 10–12 lần mỗi hiệp. Giữ nhịp thở đều (thở ra khi phát lực, hít vào khi hạ tạ) và đọc kỹ hướng dẫn an toàn của từng thiết bị.',
              style: TextStyle(
                color: Color(0xFFC8C2BC),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          icon: Icons.calendar_today_rounded,
          iconColor: MetaGymTheme.reflectionBlue,
          title: '3. Phân bổ lịch tập 3 buổi/tuần hợp lý',
          children: const [
            Text(
              'Người mới nên bắt đầu với 3 buổi/tuần cách ngày (ví dụ Thứ 2 – Thứ 4 – Thứ 6) để cơ bắp có 48 giờ phục hồi. Mỗi buổi chỉ cần 4–6 bài tập cơ bản tác động vào các nhóm cơ lớn (Ngực, Lưng, Chân, Vai, Core).',
              style: TextStyle(
                color: Color(0xFFC8C2BC),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          icon: Icons.edit_calendar_rounded,
          iconColor: MetaGymTheme.coachAvatarBackground,
          title: '4. Ghi nhật ký tập luyện và ăn uống đều đặn',
          children: const [
            Text(
              'Sau mỗi buổi tập, hãy lưu lại thành tích, ảnh tiến trình và chỉ số cơ thể trong mục Nhật ký tập luyện để bạn và Coach dễ dàng theo dõi tiến độ.',
              style: TextStyle(
                color: Color(0xFFC8C2BC),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return MetaGymGlassCard(
      padding: EdgeInsets.zero,
      child: ColoredBox(
        color: const Color(0xA0211E1C),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 19, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
