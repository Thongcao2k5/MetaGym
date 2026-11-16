import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_outcome_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_outcome_consent_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';
import 'package:provider/provider.dart';

class MemberCoachingPage extends StatefulWidget {
  const MemberCoachingPage({this.service, super.key});

  final MemberCoachingService? service;

  @override
  State<MemberCoachingPage> createState() => _MemberCoachingPageState();
}

class _MemberCoachingPageState extends State<MemberCoachingPage> {
  MemberCoachingService? _service;
  List<MemberCoachRelationship> _history = const [];
  List<CoachRecord> _entitlements = const [];
  List<CoachRecord> _holds = const [];
  List<CoachOutcomeCase> _outcomes = const [];
  Map<String, String> _coachNames = const {};
  MemberCoachRelationship? _current;
  String? _error;
  String? _actionError;
  bool _loading = true;
  bool _openingChat = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? MemberCoachingApi(context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final current = await _service!.getCurrentRelationship();
      final history = await _service!.getRelationshipHistory();
      Map<String, String> coachNames;
      try {
        coachNames = await _service!.getCoachNames();
      } catch (_) {
        coachNames = const {};
      }
      List<CoachRecord> entitlements = const [];
      List<CoachRecord> holds = const [];
      List<CoachOutcomeCase> outcomes = const [];
      if (mounted) {
        final apiClient = optionalProvider<ApiClient>(context);
        if (apiClient != null) {
          final v2 = CoachV2Api(apiClient);
          try {
            entitlements = await v2.list('/coach-entitlements');
          } catch (_) {}
          try {
            holds = await v2.list('/coach-payment-holds');
          } catch (_) {}
          try {
            outcomes = await CoachOutcomeApi(apiClient).getMemberOutcomes();
          } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() {
        _current = current;
        _history = history;
        _coachNames = coachNames;
        _entitlements = entitlements;
        _holds = holds;
        _outcomes = outcomes;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được quan hệ Coach.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _coachLabel(MemberCoachRelationship rel) =>
      rel.coachName?.isNotEmpty == true
      ? rel.coachName!
      : (_coachNames[rel.coachId] ?? 'Coach');

  Future<void> _openChat(String coachId) async {
    if (_openingChat) return;
    final messaging = optionalProvider<MessagingService>(context);
    final userId = optionalProvider<SessionController>(context)?.user?.id;
    if (messaging == null || userId == null) return;
    setState(() {
      _openingChat = true;
      _actionError = null;
    });
    try {
      final conversation = await messaging.startConversation(coachId: coachId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ConversationDetailPage(
            conversation: conversation,
            service: messaging,
            currentUserId: userId,
            picker: DeviceProgressPhotoPicker(),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Không mở được cuộc trò chuyện.');
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<void> _openOutcomeConsent() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const MemberOutcomeConsentPage()),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final hasApiClient = optionalProvider<ApiClient>(context) != null;
    final activePackage = _entitlements
        .where((e) => e['status'] == 'ACTIVE')
        .firstOrNull;
    final queuedPackage = _entitlements
        .where((e) => e['status'] == 'QUEUED')
        .firstOrNull;
    final pendingHold = _holds.where((h) => h['status'] == 'HELD').firstOrNull;
    final previousRelationships = _history
        .where((item) => item.id != current?.id)
        .toList();

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Coach của tôi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
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
            child: _loading && _history.isEmpty && current == null
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
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          TextButton(
                            onPressed: _load,
                            style: TextButton.styleFrom(
                              foregroundColor: MetaGymTheme.brandOrange,
                            ),
                            child: const Text('Thử lại'),
                          ),
                        ] else ...[
                          if (_actionError != null)
                            CoachingErrorBanner(message: _actionError!),
                          if (current != null) ...[
                            _CurrentCoachHero(
                              relationship: current,
                              coachName: _coachLabel(current),
                              activePackage: activePackage,
                              onPrimaryAction: () {
                                if (current.status == 'PAUSED' &&
                                    current.pauseReason != 'COACH_LOCKED') {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => const MembershipPage(),
                                    ),
                                  );
                                } else {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => const CoachBookingPage(),
                                    ),
                                  );
                                }
                              },
                            ),
                            if (queuedPackage != null)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      color: MetaGymTheme.brandOrange,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Gói tiếp theo: ${queuedPackage['planName']}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Đã mua (${queuedPackage['totalSessions']} buổi) · chờ kích hoạt sau gói hiện tại',
                                            style: const TextStyle(
                                              color: MetaGymTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (current.status != 'PAUSED') ...[
                              const Padding(
                                padding: EdgeInsets.only(top: 6, bottom: 10),
                                child: Text(
                                  'Cùng Coach của bạn',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _ActionRow(
                                icon: Icons.fitness_center_rounded,
                                title: 'Giáo trình',
                                subtitle: 'Tập luyện và dinh dưỡng',
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => const MemberTrainingPage(),
                                  ),
                                ),
                              ),
                              _ActionRow(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'Nhắn Coach',
                                subtitle: 'Trao đổi trực tiếp',
                                onTap: _openingChat
                                    ? null
                                    : () => _openChat(current.coachId),
                              ),
                              if (hasApiClient)
                                _ActionRow(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'Gói Coach',
                                  subtitle: 'Xem quyền lợi và thời hạn',
                                  onTap: () => Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => CoachOffersPage(
                                        coachId: current.coachId,
                                      ),
                                    ),
                                  ),
                                ),
                            ] else ...[
                              _ActionRow(
                                icon: Icons.fitness_center_rounded,
                                title: 'Xem giáo trình',
                                subtitle: 'Đang tạm khóa',
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => const MemberTrainingPage(),
                                  ),
                                ),
                              ),
                              _ActionRow(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'Nhắn Coach',
                                subtitle: 'Trao đổi trực tiếp',
                                onTap: _openingChat
                                    ? null
                                    : () => _openChat(current.coachId),
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Quan hệ tự động kết thúc khi dùng hết số buổi hoặc hết thời hạn gói Coach.',
                                style: TextStyle(
                                  color: MetaGymTheme.textSecondary,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ] else if (pendingHold != null)
                            MetaGymHeroGlassCard(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CoachingPill(
                                    label: 'Chờ thanh toán',
                                    tone: CoachingPillTone.amber,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Đã giữ suất với Coach',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Hoàn tất thanh toán mô phỏng cho gói ${pendingHold['planName']} trong thời gian giữ suất để kích hoạt quyền lợi.',
                                    style: const TextStyle(
                                      color: Color(0xFFD5D8DF),
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  CoachingPrimaryButton(
                                    label: 'Tiếp tục thanh toán',
                                    onPressed: () => Navigator.of(context)
                                        .push<void>(
                                          MaterialPageRoute(
                                            builder: (_) => CoachOffersPage(
                                              coachId:
                                                  pendingHold['coachId']
                                                      as String,
                                            ),
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            )
                          else
                            MetaGymHeroGlassCard(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xFFFF9779),
                                    size: 34,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Chưa có Coach',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Xem hồ sơ, lịch làm việc và các gói huấn luyện trước khi chọn Coach cho mình.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFC3C6CC),
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  CoachingPrimaryButton(
                                    label: 'Khám phá Coach',
                                    onPressed: () => Navigator.of(context)
                                        .push<void>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const CoachSelectionPage(),
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          if (_outcomes.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _ActionRow(
                              icon: Icons.verified_outlined,
                              title: 'Duyệt thành quả học viên',
                              subtitle:
                                  _outcomes.any(
                                    (item) => item.status == 'PENDING_MEMBER',
                                  )
                                  ? '${_outcomes.where((item) => item.status == 'PENDING_MEMBER').length} thành quả đang chờ bạn duyệt công khai'
                                  : '${_outcomes.length} thành quả từ Coach · quản lý ẩn danh / thu hồi',
                              onTap: _openOutcomeConsent,
                            ),
                          ],
                          if (previousRelationships.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.only(top: 12, bottom: 10),
                              child: Text(
                                'Lịch sử quan hệ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            for (final item in previousRelationships)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.badge_outlined,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _coachLabel(item),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.statusLabel,
                                            style: const TextStyle(
                                              color: MetaGymTheme.textSecondary,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
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

class _CurrentCoachHero extends StatelessWidget {
  const _CurrentCoachHero({
    required this.relationship,
    required this.coachName,
    required this.activePackage,
    required this.onPrimaryAction,
  });

  final MemberCoachRelationship relationship;
  final String coachName;
  final CoachRecord? activePackage;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final isPaused = relationship.status == 'PAUSED';
    final isCoachLocked =
        isPaused && relationship.pauseReason == 'COACH_LOCKED';
    final remaining = activePackage?['remainingSessions'];
    final total = activePackage?['totalSessions'];
    final endsOn = activePackage?['endsOn'] as String?;

    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachingPill(
            label: relationship.statusLabel,
            tone: isPaused ? CoachingPillTone.amber : CoachingPillTone.green,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CoachingAvatar(
                fullName: coachName,
                avatarUrl: relationship.coachAvatarUrl,
                size: 46,
                round: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coachName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Coach cá nhân',
                      style: TextStyle(
                        color: MetaGymTheme.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPaused) ...[
            const SizedBox(height: 14),
            Text(
              isCoachLocked
                  ? 'Quan hệ tạm khóa theo trạng thái tài khoản Coach. Thời hạn gói Coach được đóng băng trong lúc chờ hỗ trợ.'
                  : 'Giáo trình và buổi tương lai được giữ lại. Bạn cần gia hạn gói Gym để tiếp tục đặt lịch; thời hạn gói Coach vẫn chạy.',
              style: const TextStyle(
                color: Color(0xFFD9DDE4),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            if (!isCoachLocked)
              CoachingPrimaryButton(
                label: 'Gia hạn gói Gym',
                onPressed: onPrimaryAction,
              ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x26FFFFFF))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gói đang dùng',
                          style: TextStyle(
                            color: Color(0xFFBEC3CB),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          remaining != null && total != null
                              ? '$remaining / $total buổi'
                              : 'Đang hiệu lực',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0x26FFFFFF))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hết hạn',
                          style: TextStyle(
                            color: Color(0xFFBEC3CB),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          endsOn != null ? formatVietnamDate(endsOn) : '--',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            CoachingPrimaryButton(
              label: 'Xem lịch với Coach',
              onPressed: onPrimaryAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: MetaGymTheme.primary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: MetaGymTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white54,
            size: 20,
          ),
        ],
      ),
    );
  }
}
