import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_outcome_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:provider/provider.dart';

class CoachDetailPage extends StatefulWidget {
  const CoachDetailPage({
    required this.coachId,
    required this.service,
    this.messagingService,
    this.currentUserId,
    super.key,
  });

  final String coachId;
  final CoachSelectionService service;
  final MessagingService? messagingService;
  final String? currentUserId;

  @override
  State<CoachDetailPage> createState() => _CoachDetailPageState();
}

class _CoachDetailPageState extends State<CoachDetailPage> {
  CoachProfile? _coach;
  List<CoachRecord> _workDays = const [];
  List<CoachOutcomeCase> _outcomes = const [];
  String? _loadError;
  String? _chatError;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
    });
    try {
      final coach = await widget.service.getCoach(widget.coachId);
      List<CoachRecord> workDays = const [];
      List<CoachOutcomeCase> outcomes = const [];
      if (mounted) {
        final apiClient = optionalProvider<ApiClient>(context);
        if (apiClient != null) {
          try {
            final schedule = await CoachV2Api(apiClient)
                .get('/coaches/${widget.coachId}/work-slots');
            workDays = (schedule['days'] as List? ?? const [])
                .cast<CoachRecord>();
          } catch (_) {
            // Work slots are informational here; offers & checkout verify again.
          }
          try {
            outcomes = await CoachOutcomeApi(apiClient)
                .getPublicOutcomes(widget.coachId);
          } catch (_) {
            // Outcomes remain empty when not loaded or unavailable in fixture mode.
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _coach = coach;
        _workDays = workDays;
        _outcomes = outcomes;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Không tải được chi tiết Coach.');
      }
    }
  }

  Future<void> _openChat() async {
    if (_openingChat) return;
    final messaging =
        widget.messagingService ?? context.read<MessagingService>();
    final currentUserId =
        widget.currentUserId ?? context.read<SessionController>().user!.id;
    setState(() {
      _openingChat = true;
      _chatError = null;
    });
    try {
      final conversation = await messaging.startConversation(
        coachId: widget.coachId,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ConversationDetailPage(
            conversation: conversation,
            service: messaging,
            currentUserId: currentUserId,
            picker: DeviceProgressPhotoPicker(),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _chatError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _chatError = 'Không mở được cuộc trò chuyện.');
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  String _weekdayName(int weekday) => switch (weekday) {
    1 => 'Thứ Hai',
    2 => 'Thứ Ba',
    3 => 'Thứ Tư',
    4 => 'Thứ Năm',
    5 => 'Thứ Sáu',
    6 => 'Thứ Bảy',
    7 => 'Chủ Nhật',
    _ => 'Thứ $weekday',
  };

  @override
  Widget build(BuildContext context) {
    final coach = _coach;
    final hasApiClient = optionalProvider<ApiClient>(context) != null;

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Chi tiết Coach',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: MetaGymCircleIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: 'Nhắn Coach',
              onTap: _openingChat ? null : _openChat,
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: coach == null && _loadError == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: const Color(0xFF181B22),
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        if (_loadError != null) ...[
                          CoachingErrorBanner(message: _loadError!),
                          TextButton(
                            onPressed: _load,
                            style: TextButton.styleFrom(
                              foregroundColor: MetaGymTheme.brandOrange,
                            ),
                            child: const Text('Thử lại'),
                          ),
                        ],
                        if (coach != null) ...[
                          MetaGymHeroGlassCard(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CoachingAvatar(
                                      fullName: coach.fullName,
                                      avatarUrl: coach.avatarUrl,
                                      size: 60,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            coach.fullName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 19,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (coach.specialties.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              coach.specialties.join(' · '),
                                              style: const TextStyle(
                                                color:
                                                    MetaGymTheme.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          CoachingPill(
                                            label: coach.availableSlots > 0
                                                ? 'Còn ${coach.availableSlots} suất'
                                                : 'Đã hết suất',
                                            tone: coach.availableSlots > 0
                                                ? CoachingPillTone.green
                                                : CoachingPillTone.amber,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (coach.biography?.isNotEmpty == true) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    coach.biography!,
                                    style: const TextStyle(
                                      color: Color(0xFFE0E1E4),
                                      fontSize: 13.5,
                                      height: 1.55,
                                    ),
                                  ),
                                ],
                                if (coach.experienceYears != null ||
                                    coach.qualifications?.isNotEmpty ==
                                        true) ...[
                                  const SizedBox(height: 14),
                                  const Divider(
                                    color: Color(0x26FFFFFF),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (coach.experienceYears != null)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${coach.experienceYears} năm',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Kinh nghiệm huấn luyện',
                                                style: TextStyle(
                                                  color: Color(0xFFC4C8CE),
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (coach.experienceYears != null &&
                                          coach.qualifications?.isNotEmpty ==
                                              true)
                                        Container(
                                          width: 1,
                                          height: 34,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          color: const Color(0x26FFFFFF),
                                        ),
                                      if (coach.qualifications?.isNotEmpty ==
                                          true)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                coach.qualifications!,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Bằng cấp / chứng chỉ',
                                                style: TextStyle(
                                                  color: Color(0xFFC4C8CE),
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          CoachingGraphiteCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            child: Theme(
                              data: Theme.of(context)
                                  .copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                iconColor: Colors.white70,
                                collapsedIconColor: Colors.white70,
                                leading: const Icon(
                                  Icons.calendar_month_outlined,
                                  color: MetaGymTheme.reflectionBlue,
                                  size: 20,
                                ),
                                title: const Text(
                                  'Xem lịch làm việc',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                children: [
                                  if (_workDays.isEmpty &&
                                      coach.availabilityNote?.isNotEmpty !=
                                          true)
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Coach chưa cấu hình lịch cố định.',
                                        style: TextStyle(
                                          color: MetaGymTheme.textSecondary,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  if (_workDays.isNotEmpty)
                                    SizedBox(
                                      height: 64,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _workDays.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(width: 8),
                                        itemBuilder: (_, index) {
                                          final day = _workDays[index];
                                          final starts =
                                              (day['starts'] as List? ??
                                                      const [])
                                                  .cast<String>();
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  MetaGymTheme.elevatedSurface,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    MetaGymTheme.radiusInput,
                                                  ),
                                              border: Border.all(
                                                color: MetaGymTheme
                                                    .darkBorderStrong,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  _weekdayName(
                                                    day['weekday'] as int,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  starts.take(2).join(' · '),
                                                  style: const TextStyle(
                                                    color: Color(0xFFB8BCC5),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  if (coach.availabilityNote?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        coach.availabilityNote!,
                                        style: const TextStyle(
                                          color: Color(0xFFBFC4CD),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Khung giờ để tham khảo; hệ thống kiểm tra suất khi thanh toán.',
                                      style: TextStyle(
                                        color: MetaGymTheme.textSecondary,
                                        fontSize: 11.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (hasApiClient) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 18, bottom: 10),
                              child: Text(
                                'Thành quả học viên',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_outcomes.isEmpty)
                              const CoachingGraphiteCard(
                                margin: EdgeInsets.only(bottom: 6),
                                padding: EdgeInsets.all(14),
                                child: Text(
                                  'Chưa có thành quả được học viên đồng ý công khai.',
                                  style: TextStyle(
                                    color: MetaGymTheme.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              )
                            else
                              for (final item in _outcomes)
                                CoachOutcomeCard(outcome: item),
                          ],
                          if (_chatError != null) ...[
                            const SizedBox(height: 12),
                            CoachingErrorBanner(message: _chatError!),
                          ],
                          const SizedBox(height: 18),
                          if (hasApiClient)
                            CoachingPrimaryButton(
                              label: 'Xem các gói Coach',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CoachOffersPage(coachId: widget.coachId),
                                ),
                              ),
                            )
                          else
                            const CoachingGraphiteCard(
                              padding: EdgeInsets.all(14),
                              child: Text(
                                'Vào mục Chọn gói Coach khi kết nối máy chủ để xem giá và thuê Coach.',
                                style: TextStyle(
                                  color: MetaGymTheme.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
