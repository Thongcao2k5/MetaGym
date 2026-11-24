import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_outcome_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_selection_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/coaching/presentation/early_termination_widgets.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_health_declaration_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_outcome_consent_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/termination_reason_dialog.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_page.dart';
import 'package:meta_gym_app/features/training/presentation/member_training_page.dart';

/// Màn hình **5.6a Coach & Lịch hẹn (Đã có Coach)** & **5.6b (Chưa có Coach)**
/// đồng bộ `tab5-profile.js` (`member-coaching`, `member-coaching-empty`)
/// và chuẩn Warm Smoked Liquid Glass (Dark + Light Daylight Studio).
class MemberCoachingPage extends StatefulWidget {
  const MemberCoachingPage({this.service, super.key});

  final MemberCoachingService? service;

  @override
  State<MemberCoachingPage> createState() => _MemberCoachingPageState();
}

class _MemberCoachingPageState extends State<MemberCoachingPage> {
  MemberCoachingService? _service;
  bool _initialized = false;
  List<MemberCoachRelationship> _history = const [];
  List<CoachRecord> _entitlements = const [];
  List<CoachRecord> _holds = const [];
  List<CoachOutcomeCase> _outcomes = const [];
  List<CoachTerminationRequest> _terminationRequests = const [];
  Map<String, String> _coachNames = const {};
  MemberCoachRelationship? _current;
  CoachLockChoiceResult? _coachLockChoice;
  final TextEditingController _coachLockNoteController =
      TextEditingController();
  String? _error;
  String? _actionError;
  bool _loading = true;
  bool _openingChat = false;
  bool _submittingLockChoice = false;
  bool _submittingTermination = false;

  @override
  void dispose() {
    _coachLockNoteController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final provided =
        widget.service ?? optionalProvider<MemberCoachingService>(context);
    if (provided != null) {
      _service = provided;
    } else {
      final api = optionalProvider<ApiClient>(context);
      if (api != null) {
        _service = MemberCoachingApi(api);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_service != null) {
        _load();
      } else {
        setState(() => _loading = false);
      }
    });
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final current = await service.getCurrentRelationship();
      final history = await service.getRelationshipHistory();
      List<CoachTerminationRequest> terminationRequests;
      try {
        terminationRequests = await service.getEarlyTerminationRequests();
      } catch (_) {
        terminationRequests = const [];
      }
      Map<String, String> coachNames;
      try {
        coachNames = await service.getCoachNames();
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
        _terminationRequests = terminationRequests;
        _coachNames = coachNames;
        _entitlements = entitlements;
        _holds = holds;
        _outcomes = outcomes;
        if (current == null || !current.isCoachLocked) {
          _coachLockChoice = null;
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được quan hệ Coach.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitCoachLockChoice(String choice) async {
    final service = _service;
    if (_submittingLockChoice || service == null) return;
    setState(() {
      _submittingLockChoice = true;
      _actionError = null;
    });
    try {
      final result = await service.submitCoachLockChoice(
        choice: choice,
        note: _coachLockNoteController.text,
      );
      if (!mounted) return;
      setState(() => _coachLockChoice = result);
      showCoachingSnackBar(
        context,
        'Đã ghi nhận lựa chọn: ${result.choiceLabel}',
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _actionError = 'Không gửi được lựa chọn xử lý sự cố Coach.',
        );
      }
    } finally {
      if (mounted) setState(() => _submittingLockChoice = false);
    }
  }

  Future<void> _requestEarlyTermination(String relationshipId) async {
    final service = _service;
    if (_submittingTermination || service == null) return;
    final reason = await MetaGymNavigation.showDialogOnce<String>(
      context: context,
      builder: (_) =>
          const TerminationReasonDialog(confirmLabel: 'Gửi yêu cầu'),
    );
    if (reason == null || !mounted) return;
    setState(() {
      _submittingTermination = true;
      _actionError = null;
    });
    try {
      final created = await service.requestEarlyTermination(
        relationshipId,
        reason,
      );
      if (!mounted) return;
      setState(() {
        _terminationRequests = [
          created,
          ..._terminationRequests.where((item) => item.id != created.id),
        ];
      });
      showCoachingSnackBar(
        context,
        'Đã gửi yêu cầu kết thúc sớm (thời hạn phản hồi 72 giờ).',
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Không gửi được yêu cầu kết thúc sớm.');
      }
    } finally {
      if (mounted) setState(() => _submittingTermination = false);
    }
  }

  Future<void> _respondEarlyTermination(
    CoachTerminationRequest request,
    String decision,
    String? reason,
  ) async {
    final service = _service;
    if (_submittingTermination || service == null) return;
    setState(() {
      _submittingTermination = true;
      _actionError = null;
    });
    try {
      final updated = await service.respondEarlyTermination(
        request.id,
        decision: decision,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _terminationRequests = [
          updated,
          ..._terminationRequests.where((item) => item.id != updated.id),
        ];
      });
      if (decision == 'ACCEPT') {
        await _load();
      }
      if (!mounted) return;
      final message = switch (decision) {
        'ACCEPT' => 'Đã chấp nhận kết thúc sớm quan hệ Coach.',
        'REJECT' => 'Đã từ chối và chuyển yêu cầu sang Admin phân xử.',
        _ => 'Đã rút yêu cầu kết thúc sớm.',
      };
      showCoachingSnackBar(context, message);
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Không xử lý được phản hồi yêu cầu.');
      }
    } finally {
      if (mounted) setState(() => _submittingTermination = false);
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
    if (messaging == null || userId == null) {
      setState(
        () => _actionError =
            'Chưa thể mở cuộc trò chuyện lúc này. Vui lòng thử lại sau.',
      );
      return;
    }
    setState(() {
      _openingChat = true;
      _actionError = null;
    });
    try {
      final conversation = await messaging.startConversation(coachId: coachId);
      if (!mounted) return;
      await MetaGymNavigation.pushOnce<void>(
        context,
        MetaGymPageRoute(
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
    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(builder: (_) => const MemberOutcomeConsentPage()),
    );
    if (mounted) await _load();
  }

  Widget _buildHeader(BuildContext context, MetaGymColors colors) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COACHING 1:1',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Coach & Lịch hẹn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedActionsCard(
    MetaGymColors colors, {
    required MemberCoachRelationship current,
    required bool hasApiClient,
  }) {
    final items = <_CoachingActionItem>[
      if (current.status != 'PAUSED') ...[
        _CoachingActionItem(
          svgAsset: MetaGymIcons.actionCurriculum,
          title: 'Giáo trình',
          subtitle: 'Tập luyện và dinh dưỡng',
          onTap: () => MetaGymNavigation.pushOnce<void>(
            context,
            MetaGymPageRoute(builder: (_) => const MemberTrainingPage()),
          ),
        ),
        _CoachingActionItem(
          svgAsset: MetaGymIcons.commChat,
          title: 'Nhắn Coach',
          subtitle: 'Trao đổi trực tiếp',
          onTap: _openingChat ? null : () => _openChat(current.coachId),
        ),
        if (hasApiClient)
          _CoachingActionItem(
            svgAsset: MetaGymIcons.coachPkg1on1,
            title: 'Gói Coach',
            subtitle: 'Xem quyền lợi và thời hạn',
            onTap: () => MetaGymNavigation.pushOnce<void>(
              context,
              MetaGymPageRoute(
                builder: (_) => CoachOffersPage(coachId: current.coachId),
              ),
            ),
          ),
      ] else ...[
        _CoachingActionItem(
          svgAsset: MetaGymIcons.actionCurriculum,
          title: 'Xem giáo trình',
          subtitle: current.isMemberLocked
              ? 'Tài khoản đang tạm khóa'
              : current.isCoachLocked
              ? 'Tạm ngưng khi Coach bị khóa'
              : 'Đang tạm khóa',
          onTap: () => MetaGymNavigation.pushOnce<void>(
            context,
            MetaGymPageRoute(builder: (_) => const MemberTrainingPage()),
          ),
        ),
        _CoachingActionItem(
          svgAsset: MetaGymIcons.commChat,
          title: 'Nhắn Coach',
          subtitle: current.isCoachLocked
              ? 'Xem lịch sử · Không gửi được khi Coach bị khóa'
              : current.isMemberLocked
              ? 'Xem lịch sử tin nhắn'
              : 'Trao đổi trực tiếp',
          onTap: _openingChat ? null : () => _openChat(current.coachId),
        ),
      ],
      if (hasApiClient || _outcomes.isNotEmpty)
        _CoachingActionItem(
          svgAsset: MetaGymIcons.outcomeConsentBadge,
          title: 'Duyệt thành quả của bạn',
          subtitle: _outcomes.isEmpty
              ? 'Quản lý chia sẻ kết quả tập luyện'
              : _outcomes.any((item) => item.status == 'PENDING_MEMBER')
              ? '${_outcomes.where((item) => item.status == 'PENDING_MEMBER').length} thành quả đang chờ bạn duyệt công khai'
              : '${_outcomes.length} thành quả từ Coach · quản lý ẩn danh / thu hồi',
          onTap: _openOutcomeConsent,
        ),
    ];

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: colors.metricPanelBorder.withValues(alpha: 0.45),
              ),
            _CoachingActionTile(item: items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, MetaGymColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaGymHeroGlassCard(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                  ),
                ),
                alignment: Alignment.center,
                child: const MetaGymIcon(
                  MetaGymIcons.emptyCoach,
                  size: MetaGymIconSize.lg,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Chưa có Coach',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Xem hồ sơ, lịch làm việc và các gói huấn luyện trước khi chọn Coach đồng hành cho mình.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textWarmMuted,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.primary,
                    foregroundColor: MetaGymTheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                    ),
                  ),
                  onPressed: () => MetaGymNavigation.pushOnce<void>(
                    context,
                    MetaGymPageRoute(
                      builder: (_) => const CoachSelectionPage(),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Khám phá Coach',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        MetaGymGlassCard(
          solid: false,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bắt đầu tập 1:1 trong 3 bước',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _OnboardingStepRow(
                stepNumber: '1',
                highlighted: true,
                title: 'Khai báo thể trạng',
                subtitle: 'Cập nhật chiều cao, cân nặng & chấn thương',
                onTap: () => MetaGymNavigation.pushOnce<void>(
                  context,
                  MetaGymPageRoute(
                    builder: (_) => const MemberHealthDeclarationPage(),
                  ),
                ),
              ),
              Divider(
                height: 16,
                thickness: 1,
                color: colors.metricPanelBorder.withValues(alpha: 0.45),
              ),
              _OnboardingStepRow(
                stepNumber: '2',
                highlighted: false,
                title: 'Chọn Coach & Gói tập',
                subtitle: 'So sánh chuyên môn, đánh giá & lịch rảnh',
                onTap: () => MetaGymNavigation.pushOnce<void>(
                  context,
                  MetaGymPageRoute(builder: (_) => const CoachSelectionPage()),
                ),
              ),
              Divider(
                height: 16,
                thickness: 1,
                color: colors.metricPanelBorder.withValues(alpha: 0.45),
              ),
              const _OnboardingStepRow(
                stepNumber: '3',
                highlighted: false,
                title: 'Đặt lịch buổi tập 90 phút',
                subtitle: 'Nhận giáo trình & thực đơn cá nhân hóa',
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final current = _current;
    final hasApiClient = optionalProvider<ApiClient>(context) != null;
    final activePackage = _entitlements
        .where((e) => e['status'] == 'ACTIVE')
        .firstOrNull;
    final queuedPackage = _entitlements
        .where((e) => e['status'] == 'QUEUED')
        .firstOrNull;
    final pendingHold = _holds.where((h) => h['status'] == 'HELD').firstOrNull;
    final openTermination = current == null
        ? null
        : _terminationRequests
              .where((item) => item.relationshipId == current.id && item.isOpen)
              .firstOrNull;
    final canRequestTermination =
        current != null &&
        openTermination == null &&
        (current.status == 'ACTIVE' || current.isMembershipExpired);
    final previousRelationships = _history
        .where((item) => item.id != current?.id)
        .toList();

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, colors),
                Expanded(
                  child: _loading && _history.isEmpty && current == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: colors.overlayGlass,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              MediaQuery.paddingOf(context).bottom + 28,
                            ),
                            children: [
                              if (_error != null) ...[
                                CoachingErrorBanner(message: _error!),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton.icon(
                                    onPressed: _load,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: MetaGymTheme.primary,
                                      foregroundColor: MetaGymTheme.onPrimary,
                                      minimumSize: const Size(120, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Thử lại',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
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
                                      if (current.isMembershipExpired) {
                                        MetaGymNavigation.pushOnce<void>(
                                          context,
                                          MetaGymPageRoute(
                                            builder: (_) =>
                                                const MembershipPage(),
                                          ),
                                        );
                                      } else if (current.status == 'ACTIVE') {
                                        MetaGymNavigation.pushOnce<void>(
                                          context,
                                          MetaGymPageRoute(
                                            builder: (_) =>
                                                const CoachBookingPage(),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  if (current.isCoachLocked)
                                    _CoachLockChoiceCard(
                                      choiceResult: _coachLockChoice,
                                      noteController: _coachLockNoteController,
                                      submitting: _submittingLockChoice,
                                      onSelectChoice: _submitCoachLockChoice,
                                    ),
                                  if (openTermination != null)
                                    EarlyTerminationCard(
                                      request: openTermination,
                                      viewerRole: 'MEMBER',
                                      busy: _submittingTermination,
                                      onRespond: (decision, reason) =>
                                          _respondEarlyTermination(
                                            openTermination,
                                            decision,
                                            reason,
                                          ),
                                    ),
                                  if (queuedPackage != null)
                                    MetaGymGlassCard(
                                      solid: false,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: MetaGymTheme.brandOrange
                                                  .withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              border: Border.all(
                                                color: MetaGymTheme.brandOrange
                                                    .withValues(alpha: 0.42),
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: const MetaGymIcon(
                                              MetaGymIcons.membershipScheduled,
                                              size: MetaGymIconSize.sm,
                                              excludeFromSemantics: true,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Gói tiếp theo: ${queuedPackage['planName']}',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: colors.textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Đã mua (${queuedPackage['totalSessions']} buổi) · chờ kích hoạt sau gói hiện tại',
                                                  style: TextStyle(
                                                    color: colors.textWarmMuted,
                                                    fontSize: 12,
                                                    fontFeatures: MetaGymTheme
                                                        .tabularFigures,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  _buildGroupedActionsCard(
                                    colors,
                                    current: current,
                                    hasApiClient: hasApiClient,
                                  ),
                                ] else if (pendingHold != null) ...[
                                  MetaGymHeroGlassCard(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const CoachingPill(
                                          label: 'Chờ thanh toán',
                                          tone: CoachingPillTone.amber,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Đã giữ suất với Coach',
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Hoàn tất thanh toán mô phỏng cho gói ${pendingHold['planName']} trong thời gian giữ suất để kích hoạt quyền lợi.',
                                          style: TextStyle(
                                            color: colors.textWarmMuted,
                                            fontSize: 13,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        CoachingPrimaryButton(
                                          label: 'Tiếp tục thanh toán',
                                          onPressed: () =>
                                              MetaGymNavigation.pushOnce<void>(
                                                context,
                                                MetaGymPageRoute(
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
                                  ),
                                  if (_outcomes.isNotEmpty)
                                    MetaGymGlassCard(
                                      solid: false,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 4,
                                      ),
                                      child: _CoachingActionTile(
                                        item: _CoachingActionItem(
                                          svgAsset:
                                              MetaGymIcons.outcomeConsentBadge,
                                          title: 'Duyệt thành quả của bạn',
                                          subtitle:
                                              '${_outcomes.length} thành quả từ Coach · quản lý ẩn danh / thu hồi',
                                          onTap: _openOutcomeConsent,
                                        ),
                                      ),
                                    ),
                                ] else ...[
                                  _buildEmptyState(context, colors),
                                  if (_outcomes.isNotEmpty)
                                    MetaGymGlassCard(
                                      solid: false,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 4,
                                      ),
                                      child: _CoachingActionTile(
                                        item: _CoachingActionItem(
                                          svgAsset:
                                              MetaGymIcons.outcomeConsentBadge,
                                          title: 'Duyệt thành quả của bạn',
                                          subtitle:
                                              _outcomes.any(
                                                (item) =>
                                                    item.status ==
                                                    'PENDING_MEMBER',
                                              )
                                              ? '${_outcomes.where((item) => item.status == 'PENDING_MEMBER').length} thành quả đang chờ bạn duyệt công khai'
                                              : '${_outcomes.length} thành quả từ Coach · quản lý ẩn danh / thu hồi',
                                          onTap: _openOutcomeConsent,
                                        ),
                                      ),
                                    ),
                                ],
                                if (canRequestTermination)
                                  MetaGymGlassCard(
                                    solid: false,
                                    key: const Key(
                                      'member-early-termination-btn',
                                    ),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13,
                                    ),
                                    onTap: _submittingTermination
                                        ? null
                                        : () => _requestEarlyTermination(
                                            current.id,
                                          ),
                                    child: Center(
                                      child: Text(
                                        'Yêu cầu kết thúc sớm gói Coach',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.error,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (previousRelationships.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 16,
                                      bottom: 10,
                                    ),
                                    child: Text(
                                      'Lịch sử quan hệ',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  for (final item in previousRelationships)
                                    MetaGymGlassCard(
                                      solid: false,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          CoachingAvatar(
                                            fullName: _coachLabel(item),
                                            avatarUrl: item.coachAvatarUrl,
                                            size: 40,
                                            round: true,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _coachLabel(item),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: colors.textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.statusLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: colors.textWarmMuted,
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
          ),
        ],
      ),
    );
  }
}

class _CoachingActionItem {
  const _CoachingActionItem({
    required this.svgAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String svgAsset;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class _CoachingActionTile extends StatelessWidget {
  const _CoachingActionTile({required this.item});

  final _CoachingActionItem item;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymTap(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              MetaGymIcon(
                item.svgAsset,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textWarmMuted,
                        fontSize: 12,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStepRow extends StatelessWidget {
  const _OnboardingStepRow({
    required this.stepNumber,
    required this.highlighted,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String stepNumber;
  final bool highlighted;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final badgeBg = highlighted
        ? MetaGymTheme.brandOrange.withValues(alpha: isLight ? 0.14 : 0.20)
        : (isLight ? colors.metricPanelBg : const Color(0x2E8E95A5));
    final badgeFg = highlighted ? colors.primaryText : colors.textSecondary;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                stepNumber,
                style: TextStyle(
                  color: badgeFg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textWarmMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return content;
    return MetaGymTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
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

  String _formatCompactDate(String? raw) {
    final full = formatVietnamDate(raw);
    final parts = full.split('/');
    if (parts.length == 3 && parts[2].length == 4) {
      return '${parts[0]}/${parts[1]}/${parts[2].substring(2)}';
    }
    return full;
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isPaused = relationship.isPaused;
    final isCoachLocked = relationship.isCoachLocked;
    final isMemberLocked = relationship.isMemberLocked;
    final isMembershipExpired = relationship.isMembershipExpired;
    final remaining = activePackage?['remainingSessions'];
    final total = activePackage?['totalSessions'];
    final endsOn = activePackage?['endsOn'] as String?;
    final frozenAtRaw = activePackage?['frozenAt'] as String?;
    final isFrozen = frozenAtRaw != null && frozenAtRaw.trim().isNotEmpty;
    final frozenDaysTotal =
        (activePackage?['frozenDaysTotal'] as num?)?.toInt() ?? 0;

    final statusTone = isMemberLocked
        ? CoachingPillTone.coral
        : isPaused
        ? CoachingPillTone.amber
        : CoachingPillTone.green;

    final pausedDescription = isCoachLocked
        ? (isFrozen
              ? 'Quan hệ tạm ngưng do tài khoản Coach đang bị khóa. Gói Coach đang được đóng băng từ ${formatVietnamDate(frozenAtRaw)} cho đến khi Coach mở khóa hoặc được hỗ trợ chuyển/hoàn gói.'
              : 'Quan hệ tạm ngưng do tài khoản Coach đang bị khóa. Thời hạn gói Coach được đóng băng trong lúc chờ hỗ trợ khi gói Gym còn hiệu lực.')
        : isMemberLocked
        ? 'Quan hệ tạm ngưng do tài khoản của bạn đang bị khóa. Thời hạn gói Gym và gói Coach vẫn tiếp tục tính như bình thường; vui lòng liên hệ quản trị viên để được hỗ trợ.'
        : 'Giáo trình và buổi tương lai được giữ lại. Bạn cần gia hạn gói Gym để tiếp tục đặt lịch; thời hạn gói Coach vẫn chạy.';

    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CoachingAvatar(
                fullName: coachName,
                avatarUrl: relationship.coachAvatarUrl,
                size: 46,
                round: true,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coachName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Coach cá nhân',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textWarmMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isPaused && !isFrozen) ...[
                const SizedBox(width: 8),
                CoachingPill(label: relationship.statusLabel, tone: statusTone),
              ],
            ],
          ),
          if (isPaused || isFrozen) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                CoachingPill(label: relationship.statusLabel, tone: statusTone),
                if (isFrozen)
                  const CoachingPill(
                    key: Key('coaching-frozen-pill'),
                    label: 'Đang đóng băng',
                    tone: CoachingPillTone.info,
                    icon: Icons.ac_unit_rounded,
                  ),
              ],
            ),
          ],
          if (isPaused) ...[
            const SizedBox(height: 12),
            Text(
              pausedDescription,
              style: TextStyle(
                color: colors.textWarmMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (isFrozen || (isCoachLocked && activePackage != null)) ...[
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: MetaGymMetricPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buổi còn lại',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              remaining != null && total != null
                                  ? '$remaining / $total buổi'
                                  : 'Đã bảo lưu',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetaGymMetricPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFrozen ? 'Đóng băng từ' : 'Hết hạn',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isFrozen
                                  ? formatVietnamDate(frozenAtRaw)
                                  : (endsOn != null
                                        ? formatVietnamDate(endsOn)
                                        : '--'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isFrozen
                                    ? colors.info
                                    : colors.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isMembershipExpired) ...[
              const SizedBox(height: 14),
              CoachingPrimaryButton(
                label: 'Gia hạn gói Gym',
                onPressed: onPrimaryAction,
              ),
            ],
          ] else ...[
            const SizedBox(height: 11),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: MetaGymMetricPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buổi PT còn lại',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            remaining != null && total != null
                                ? '$remaining / $total'
                                : 'Đang hiệu lực',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetaGymMetricPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hết hạn gói',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            endsOn != null ? _formatCompactDate(endsOn) : '--',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                          if (frozenDaysTotal > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              '+$frozenDaysTotal ngày bù đóng băng',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.info,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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

class _CoachLockChoiceCard extends StatelessWidget {
  const _CoachLockChoiceCard({
    required this.choiceResult,
    required this.noteController,
    required this.submitting,
    required this.onSelectChoice,
  });

  final CoachLockChoiceResult? choiceResult;
  final TextEditingController noteController;
  final bool submitting;
  final ValueChanged<String> onSelectChoice;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final selected = choiceResult?.memberChoice;

    return MetaGymGlassCard(
      solid: false,
      key: const Key('coach-lock-choice-card'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: colors.warning.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.warning.withValues(alpha: 0.45),
                  ),
                ),
                alignment: Alignment.center,
                child: const MetaGymIcon(
                  MetaGymIcons.coachingFreeze,
                  size: MetaGymIconSize.sm,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chọn phương án xử lý khóa Coach',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Thời hạn gói Coach hiện đang tạm đóng băng (gói Gym vẫn chạy bình thường). Bạn có thể chờ Coach mở khóa hoặc yêu cầu Admin hoàn mô phỏng / chuyển Coach khác.',
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (choiceResult != null) ...[
            const SizedBox(height: 10),
            CoachingPill(
              key: const Key('coach-lock-choice-status-pill'),
              label: 'Đã chọn: ${choiceResult!.choiceLabel}',
              tone: selected == 'REFUND'
                  ? CoachingPillTone.coral
                  : CoachingPillTone.info,
              icon: Icons.check_circle_outline_rounded,
            ),
            if (choiceResult!.memberChoiceNote?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                'Ghi chú đã gửi: ${choiceResult!.memberChoiceNote}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ],
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('coach-lock-choice-note'),
            controller: noteController,
            enabled: !submitting,
            cursorColor: MetaGymTheme.brandOrange,
            maxLength: 500,
            maxLines: 2,
            style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              labelText: 'Ghi chú cho Admin (không bắt buộc)',
              labelStyle: TextStyle(color: colors.textSecondary),
              counterStyle: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
              ),
              filled: true,
              fillColor: colors.metricPanelBg,
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const Key('coach-lock-wait-btn'),
              onPressed: submitting ? null : () => onSelectChoice('WAIT'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                backgroundColor: selected == 'WAIT'
                    ? colors.info.withValues(alpha: 0.18)
                    : colors.metricPanelBg,
                side: BorderSide(
                  color: selected == 'WAIT'
                      ? colors.info
                      : colors.metricPanelBorder,
                  width: selected == 'WAIT' ? 1.4 : 1,
                ),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text(
                'Chờ Coach mở khóa (WAIT)',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('coach-lock-refund-btn'),
              onPressed: submitting ? null : () => onSelectChoice('REFUND'),
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.primary,
                foregroundColor: MetaGymTheme.onPrimary,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text(
                'Yêu cầu hoàn mô phỏng / chuyển Coach (REFUND)',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
