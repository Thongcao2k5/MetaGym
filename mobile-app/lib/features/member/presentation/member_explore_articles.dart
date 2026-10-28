import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:provider/provider.dart';

enum ExploreArticleType {
  gymIntroduction,
  beginnerGuide,
}

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

/// Hai bài biên tập mẫu phục vụ MVP cho mục "Khám phá" ở Khung 3 trên Home Member.
/// Ghi chú: Ảnh minh họa đang dùng asset có sẵn (`assets/images/gym_banner.png`),
/// cần thay bằng ảnh chụp thực tế của phòng tập/bài viết trước khi phát hành chính thức.
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
        'Ảnh minh họa mẫu (assets/images/gym_banner.png) — cần thay bằng ảnh chụp thực tế không gian Meta Gym trước khi phát hành.',
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
        'Ảnh minh họa mẫu (assets/images/gym_banner.png) — cần thay bằng ảnh biên tập chuyên đề hướng dẫn tập luyện trước khi phát hành.',
  ),
];

/// Trang danh sách bài viết khi bấm "Xem thêm" từ mục Khám phá ở Khung 3.
class MemberExploreListPage extends StatelessWidget {
  const MemberExploreListPage({super.key});

  static const Color _bgDark = Color(0xFF11151C);
  static const Color _cardBg = Color(0xFF1E2633);
  static const Color _cardBorder = Color(0x1FFFFFFF);
  static const Color _titleColor = Color(0xFFF3F6FA);
  static const Color _subColor = Color(0xFF94A3B8);
  static const Color _coralLight = Color(0xFFFF7E58);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        foregroundColor: Colors.white,
        title: const Text('Khám phá'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kMemberExploreArticles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final article = kMemberExploreArticles[index];
          return Material(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => MemberExploreArticleDetailPage(
                      article: article,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: Image.asset(
                          article.imageAsset,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFF293444),
                            child: const Icon(
                              Icons.article_outlined,
                              color: _coralLight,
                            ),
                          ),
                        ),
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
                              color: _coralLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.title,
                            style: const TextStyle(
                              color: _titleColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            article.shortDescription,
                            style: const TextStyle(
                              color: _subColor,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _subColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Trang chi tiết bài viết "Khám phá".
/// - Với bài "Khám phá phòng tập Meta Gym": tải dữ liệu xác thực từ `CatalogService`
///   (tên, địa chỉ, mô tả, giờ mở cửa, nội quy, danh sách thiết bị đang hoạt động) và
///   `CoachSelectionService` (danh sách PT thực tế từ hệ thống). Tuyệt đối không bịa
///   tên, ảnh hay thành tích của PT khi chưa có dữ liệu xác thực.
/// - Với bài "Hướng dẫn tập luyện cho người mới": hiển thị nội dung hướng dẫn biên tập đầy đủ.
class MemberExploreArticleDetailPage extends StatefulWidget {
  const MemberExploreArticleDetailPage({
    required this.article,
    super.key,
  });

  final ExploreArticleItem article;

  @override
  State<MemberExploreArticleDetailPage> createState() =>
      _MemberExploreArticleDetailPageState();
}

class _MemberExploreArticleDetailPageState
    extends State<MemberExploreArticleDetailPage> {
  static const Color _bgDark = Color(0xFF11151C);
  static const Color _cardBg = Color(0xFF1E2633);
  static const Color _cardBorder = Color(0x1FFFFFFF);
  static const Color _titleColor = Color(0xFFF3F6FA);
  static const Color _bodyColor = Color(0xFFCBD5E1);
  static const Color _subColor = Color(0xFF94A3B8);
  static const Color _coralPrimary = Color(0xFFFF5E3A);
  static const Color _coralLight = Color(0xFFFF7E58);

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
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        foregroundColor: Colors.white,
        title: Text(
          article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: Image.asset(
                article.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFF293444),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: _coralLight,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A222E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33F59E0B)),
            ),
            child: Text(
              article.illustrationNotice,
              style: const TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${article.categoryLabel} · ${article.readTimeLabel}',
            style: const TextStyle(
              color: _coralLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            article.title,
            style: const TextStyle(
              color: _titleColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            article.shortDescription,
            style: const TextStyle(
              color: _bodyColor,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          if (article.type == ExploreArticleType.gymIntroduction)
            _buildGymIntroductionBody(context)
          else
            _buildBeginnerGuideBody(),
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
            child: Center(child: CircularProgressIndicator()),
          ),
        _buildDetailSection(
          title: '1. Không gian & Địa chỉ',
          children: [
            Text(
              gym != null
                  ? 'Tên cơ sở: ${gym.name}'
                  : 'Tên cơ sở: Meta Gym (Đang chờ đồng bộ dữ liệu cơ sở)',
              style: const TextStyle(
                color: _titleColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              gym != null && gym.address.trim().isNotEmpty
                  ? 'Địa chỉ: ${gym.address}'
                  : 'Địa chỉ: Chưa có dữ liệu địa chỉ xác thực từ hệ thống.',
              style: const TextStyle(
                color: _bodyColor,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            if (gym?.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                gym!.description!,
                style: const TextStyle(
                  color: _bodyColor,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              const Text(
                'Không gian được bố trí theo từng khu vực tập luyện chuyên biệt để hội viên thuận tiện di chuyển, khởi động và thực hành kỹ thuật an toàn.',
                style: TextStyle(
                  color: _bodyColor,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
            if (gym?.phone?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                'Liên hệ: ${gym!.phone}',
                style: const TextStyle(color: _subColor, fontSize: 13),
              ),
            ],
            if (gym?.email?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                'Email: ${gym!.email}',
                style: const TextStyle(color: _subColor, fontSize: 13),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          title: '2. Giờ mở cửa',
          children: [
            if (gym != null && gym.openingHours.isNotEmpty)
              for (final entry in gym.openingHours.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${entry.key}: ${entry.value}',
                    style: const TextStyle(
                      color: _bodyColor,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                )
            else
              const Text(
                'Chưa có dữ liệu giờ mở cửa xác thực trên hệ thống. Vui lòng kiểm tra trực tiếp tại trang Phòng gym và thiết bị.',
                style: TextStyle(
                  color: _subColor,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          title: '3. Thiết bị luyện tập',
          children: [
            if (_equipment.isNotEmpty) ...[
              Text(
                'Hiện có ${_equipment.length} thiết bị đang hoạt động trên danh mục xác thực:',
                style: const TextStyle(
                  color: _bodyColor,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in _equipment.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${item.name}${item.category != null ? ' (${item.category})' : ''}',
                    style: const TextStyle(
                      color: _titleColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ] else
              const Text(
                'Danh mục thiết bị chi tiết cùng hướng dẫn sử dụng và lưu ý an toàn được cập nhật trực tiếp tại mục Phòng gym và thiết bị.',
                style: TextStyle(
                  color: _bodyColor,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/member/features/gym'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _coralLight,
                  side: const BorderSide(color: _coralPrimary),
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.fitness_center_rounded, size: 18),
                label: const Text('Mở danh mục Phòng gym & thiết bị'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          title: '4. Đội ngũ Huấn luyện viên (PT)',
          children: [
            if (_coaches.isNotEmpty) ...[
              Text(
                'Danh sách Coach đang hoạt động trên hệ thống (${_coaches.length}):',
                style: const TextStyle(
                  color: _bodyColor,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              for (final coach in _coaches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ${coach.fullName}'
                        '${coach.experienceYears != null ? ' · ${coach.experienceYears} năm kinh nghiệm' : ''}',
                        style: const TextStyle(
                          color: _titleColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (coach.specialties.isNotEmpty)
                        Text(
                          '  Chuyên môn: ${coach.specialties.join(', ')}',
                          style: const TextStyle(
                            color: _subColor,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
            ] else
              const Text(
                'Thông tin hồ sơ, chuyên môn và số chỗ trống của từng Huấn luyện viên được hiển thị minh bạch theo dữ liệu thực tế tại trang Chọn Coach.',
                style: TextStyle(
                  color: _bodyColor,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/member/features/coaching'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _coralLight,
                  side: const BorderSide(color: _coralPrimary),
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: const Text('Xem danh sách Coach thực tế'),
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
          title: '1. Khởi động kỹ 8–10 phút trước mỗi buổi tập',
          children: const [
            Text(
              'Bắt đầu bằng 5 phút làm nóng toàn thân (đi bộ nhanh, xoay khớp vai, hông, cổ chân) và 1–2 hiệp khởi động nhẹ với chính bài tập chính trong ngày để cơ bắp và hệ thần kinh sẵn sàng.',
              style: TextStyle(
                color: _bodyColor,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          title: '2. Ưu tiên kỹ thuật chuẩn trước khi tăng mức tạ',
          children: const [
            Text(
              'Trong 2–4 tuần đầu tiên, hãy chọn mức tạ mà bạn kiểm soát được trọn vẹn biên độ chuyển động từ 10–12 lần mỗi hiệp. Giữ nhịp thở đều (thở ra khi phát lực, hít vào khi hạ tạ) và đọc kỹ hướng dẫn an toàn của từng thiết bị.',
              style: TextStyle(
                color: _bodyColor,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          title: '3. Phân bổ lịch tập 3 buổi/tuần hợp lý',
          children: const [
            Text(
              'Người mới nên bắt đầu với 3 buổi/tuần cách ngày (ví dụ Thứ 2 – Thứ 4 – Thứ 6) để cơ bắp có 48 giờ phục hồi. Mỗi buổi chỉ cần 4–6 bài tập cơ bản tác động vào các nhóm cơ lớn (Ngực, Lưng, Chân, Vai, Core).',
              style: TextStyle(
                color: _bodyColor,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDetailSection(
          title: '4. Ghi nhật ký tập luyện và ăn uống đều đặn',
          children: const [
            Text(
              'Sau mỗi buổi tập và bữa ăn, hãy ghi lại thời lượng, số bài hoàn thành và các bữa ăn trong mục "Nhật ký của bạn". Việc theo dõi đều đặn giúp bạn và Coach dễ dàng điều chỉnh khối lượng vận động phù hợp nhất.',
              style: TextStyle(
                color: _bodyColor,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
