import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_outcome_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/coaching/presentation/early_termination_widgets.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:meta_gym_app/features/training/presentation/meal_plans_page.dart';

class CoachMemberDetailPage extends StatefulWidget {
  const CoachMemberDetailPage({
    required this.memberId,
    required this.service,
    super.key,
  });

  final String memberId;
  final CoachMembersService service;

  @override
  State<CoachMemberDetailPage> createState() => _CoachMemberDetailPageState();
}

class _CoachMemberDetailPageState extends State<CoachMemberDetailPage> {
  CoachMemberDetail? _member;
  List<CoachTerminationRequest> _requests = const [];
  List<CoachOutcomeCase> _outcomes = const [];
  String? _error;
  String? _actionError;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _member = null;
      _requests = const [];
      _outcomes = const [];
      _error = null;
      _actionError = null;
    });
    try {
      final member = await widget.service.getMember(widget.memberId);
      final requests = await widget.service.getTerminationRequests();
      List<CoachOutcomeCase> outcomes = const [];
      if (mounted) {
        final apiClient = optionalProvider<ApiClient>(context);
        if (apiClient != null) {
          try {
            outcomes = await CoachOutcomeApi(apiClient)
                .getCoachMemberOutcomes(widget.memberId);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() {
        _member = member;
        _requests = requests;
        _outcomes = outcomes;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hồ sơ hội viên.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestTermination() async {
    final member = _member;
    if (_busy || member == null) return;
    final reason = await MetaGymNavigation.showDialogOnce<String>(
      context: context,
      builder: (_) => const _TerminationRequestDialog(),
    );
    if (reason == null ||
        !mounted ||
        _member?.relationshipId != member.relationshipId) {
      return;
    }
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await widget.service.requestTermination(member.relationshipId, reason);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if (error.statusCode == 404 || error.statusCode == 403) {
            _member = null;
            _requests = const [];
            _error = error.message;
          } else {
            _actionError = error.message;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _actionError = 'Không gửi được yêu cầu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respondTermination(
    CoachTerminationRequest request,
    String decision,
    String? reason,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await widget.service.respondTermination(
        request.id,
        decision: decision,
        reason: reason,
      );
      if (!mounted) return;
      if (decision == 'ACCEPT') {
        showCoachingSnackBar(context, 'Đã chấp nhận kết thúc sớm quan hệ.');
        await Navigator.of(context).maybePop();
        return;
      }
      await _load();
      if (!mounted) return;
      showCoachingSnackBar(
        context,
        decision == 'REJECT'
            ? 'Đã từ chối và chuyển yêu cầu sang Admin phân xử.'
            : 'Đã rút yêu cầu ngừng phụ trách.',
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          if (error.statusCode == 404 || error.statusCode == 403) {
            _member = null;
            _requests = const [];
            _error = error.message;
          } else {
            _actionError = error.message;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Không xử lý được phản hồi yêu cầu.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitOutcome() async {
    final apiClient = optionalProvider<ApiClient>(context);
    if (_busy || apiClient == null) return;
    final api = CoachOutcomeApi(apiClient);
    final created = await MetaGymNavigation.showDialogOnce<CoachOutcomeCase>(
      context: context,
      builder: (_) => _CreateOutcomeDialog(
        memberId: widget.memberId,
        api: api,
        picker: DeviceProgressPhotoPicker(),
      ),
    );
    if (created != null && mounted) {
      await _load();
      if (mounted) {
        showCoachingSnackBar(
          context,
          'Đã gửi thành quả để học viên duyệt công khai',
        );
      }
    }
  }

  Future<void> _deleteOutcome(CoachOutcomeCase outcome) async {
    final apiClient = optionalProvider<ApiClient>(context);
    if (_busy || apiClient == null) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await CoachOutcomeApi(apiClient).deleteCoachOutcome(outcome.id);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) setState(() => _actionError = 'Không xóa được thành quả.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openMemberTraining(CoachMemberDetail member) {
    final trainingService = optionalProvider<CoachTrainingService>(context);
    final apiClient = optionalProvider<ApiClient>(context);
    final resolvedService =
        trainingService ??
        (apiClient != null ? CoachTrainingApi(apiClient) : null);
    if (resolvedService != null) {
      MetaGymNavigation.pushOnce<void>(
        context,
        MetaGymPageRoute(
          builder: (_) =>
              CoachMemberPlansPage(member: member, service: resolvedService),
        ),
      );
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push<void>('/coach/features/training');
      return;
    }
    showCoachingSnackBar(
      context,
      'Mục Giáo trình khả dụng khi kết nối tài khoản Coach.',
    );
  }

  void _openMemberMealPlan(CoachMemberDetail member) {
    final apiClient = optionalProvider<ApiClient>(context);
    if (apiClient != null) {
      MetaGymNavigation.pushOnce<void>(
        context,
        MetaGymPageRoute(
          builder: (_) => MealPlansPage(
            memberId: member.memberId,
            memberName: member.memberFullName,
            editable: member.status == 'ACTIVE',
            apiClient: apiClient,
          ),
        ),
      );
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push<void>('/coach/features/nutrition');
      return;
    }
    showCoachingSnackBar(context, 'Mục Thực đơn khả dụng khi kết nối máy chủ.');
  }

  void _openMemberSessions(CoachMemberDetail member) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push<void>('/coach/features/sessions');
      return;
    }
    final apiClient = optionalProvider<ApiClient>(context);
    final userId = optionalProvider<SessionController>(context)?.user?.id;
    MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) =>
            CoachSessionsPage(coachId: userId, apiClient: apiClient),
      ),
    );
  }

  Future<void> _openMemberMessages(CoachMemberDetail member) async {
    final navigator = Navigator.of(context);
    final router = GoRouter.maybeOf(context);
    final userId = optionalProvider<SessionController>(context)?.user?.id ?? '';
    final messagingService =
        optionalProvider<MessagingService>(context) ??
        (() {
          final api = optionalProvider<ApiClient>(context);
          return api != null ? MessagingApi(api) : null;
        })();
    if (userId.isNotEmpty && messagingService != null) {
      try {
        final conversation = await messagingService.startConversation(
          memberId: member.memberId,
        );
        if (!mounted) return;
        await navigator.push<void>(
          MetaGymPageRoute(
            builder: (_) => ConversationDetailPage(
              conversation: conversation,
              service: messagingService,
              currentUserId: userId,
              picker: DeviceProgressPhotoPicker(),
              coachMode: true,
            ),
          ),
        );
        return;
      } catch (_) {
        if (!mounted) return;
      }
    }
    if (!mounted) return;
    if (userId.isNotEmpty) {
      await navigator.push<void>(
        MetaGymPageRoute(
          builder: (_) =>
              ConversationsPage(currentUserId: userId, coachMode: true),
        ),
      );
      return;
    }
    if (router != null) {
      await router.push<void>('/coach/features/messages');
      return;
    }
    showCoachingSnackBar(
      context,
      'Mục Tin nhắn khả dụng khi đăng nhập phiên Coach.',
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors,
    CoachMemberDetail? member,
  ) {
    final canPop = Navigator.of(context).canPop();
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (canPop) ...[
            _MemberDetailCircleButton(
              svgAsset: MetaGymIcons.commonBack,
              testIcon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              onTap: _busy ? null : () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HỒ SƠ HỘI VIÊN',
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
                  'Hồ sơ hội viên',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                if (member != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    member.memberFullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (member != null) ...[
            const SizedBox(width: 6),
            _MemberDetailCircleButton(
              svgAsset: MetaGymIcons.commChat,
              testIcon: Icons.chat_bubble_outline_rounded,
              tooltip: 'Nhắn tin hội viên',
              onTap: _busy ? null : () => _openMemberMessages(member),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    final member = _member;
    final hasApiClient = optionalProvider<ApiClient>(context) != null;
    final openTermination = member == null
        ? null
        : _requests
              .where(
                (request) =>
                    request.relationshipId == member.relationshipId &&
                    request.isOpen,
              )
              .firstOrNull;
    final canRequestTermination =
        member != null &&
        openTermination == null &&
        (member.status == 'ACTIVE' ||
            (member.status == 'PAUSED' &&
                (member.pauseReason == null ||
                    member.pauseReason == 'MEMBERSHIP_EXPIRED')));
    final showHealth =
        member != null &&
        member.status == 'ACTIVE' &&
        (member.healthDeclarationCompletedAt != null ||
            member.healthNotes?.isNotEmpty == true ||
            member.injuryNotes?.isNotEmpty == true ||
            member.heightCm != null ||
            member.weightKg != null ||
            member.bodyFatPercent != null);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: MetaGymBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, colors, member),
                Expanded(
                  child: _loading && member == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: MetaGymTheme.brandOrange,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Đang tải hồ sơ hội viên...',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: colors.overlayGlass,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              4,
                              gutter,
                              MediaQuery.paddingOf(context).bottom + 28,
                            ),
                            children: [
                              if (_error != null) ...[
                                CoachingErrorBanner(message: _error!),
                                CoachingSecondaryButton(
                                  label: 'Thử lại',
                                  expand: true,
                                  onPressed: _load,
                                ),
                              ],
                              if (member != null) ...[
                                _MemberHeroCard(
                                  member: member,
                                  onOpenTraining: () =>
                                      _openMemberTraining(member),
                                  onOpenNutrition: () =>
                                      _openMemberMealPlan(member),
                                  onOpenSessions: () =>
                                      _openMemberSessions(member),
                                  onOpenChat: () => _openMemberMessages(member),
                                ),
                                if (showHealth)
                                  _HealthDeclarationCard(member: member),
                                if (openTermination != null)
                                  EarlyTerminationCard(
                                    request: openTermination,
                                    viewerRole: 'COACH',
                                    busy: _busy,
                                    onRespond: (decision, reason) =>
                                        _respondTermination(
                                          openTermination,
                                          decision,
                                          reason,
                                        ),
                                  )
                                else if (canRequestTermination)
                                  MetaGymGlassCard(
                                    solid: false,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    borderColor: colors.error.withValues(
                                      alpha: 0.42,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        CoachingSecondaryButton(
                                          label: 'Xin ngừng phụ trách',
                                          expand: true,
                                          isDanger: true,
                                          onPressed: _busy
                                              ? null
                                              : _requestTermination,
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_actionError != null) ...[
                                  CoachingErrorBanner(message: _actionError!),
                                ],
                                if (hasApiClient &&
                                    member.status == 'ACTIVE') ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      bottom: 12,
                                    ),
                                    child: Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const MetaGymIcon(
                                              MetaGymIcons.outcomeConsentBadge,
                                              size: MetaGymIconSize.xs,
                                              excludeFromSemantics: true,
                                            ),
                                            const SizedBox(width: 7),
                                            Text(
                                              'Thành quả học viên',
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        FilledButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : _submitOutcome,
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                MetaGymTheme.primary,
                                            foregroundColor:
                                                MetaGymTheme.onPrimary,
                                            minimumSize: const Size(48, 48),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    MetaGymTheme.radiusInput,
                                                  ),
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Gửi thành quả'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_outcomes.isEmpty)
                                    MetaGymGlassCard(
                                      solid: false,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          const MetaGymIcon(
                                            MetaGymIcons.outcomeConsentBadge,
                                            size: MetaGymIconSize.sm,
                                            excludeFromSemantics: true,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Chưa có thành quả nào được gửi cho học viên này.',
                                              style: TextStyle(
                                                color: colors.textWarmMuted,
                                                fontSize: 13,
                                                height: 1.45,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    for (final outcome in _outcomes)
                                      CoachOutcomeCard(
                                        outcome: outcome,
                                        statusBadge: CoachingPill(
                                          label: outcome.statusLabel,
                                          tone: switch (outcome.status) {
                                            'APPROVED' =>
                                              CoachingPillTone.green,
                                            'PENDING_MEMBER' =>
                                              CoachingPillTone.amber,
                                            'DECLINED' =>
                                              CoachingPillTone.coral,
                                            _ => CoachingPillTone.neutral,
                                          },
                                        ),
                                        footer: Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: _busy
                                                ? null
                                                : () => _deleteOutcome(outcome),
                                            style: TextButton.styleFrom(
                                              foregroundColor: colors.error,
                                              minimumSize: const Size(48, 48),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('Xóa thành quả'),
                                          ),
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

class _MemberHeroCard extends StatelessWidget {
  const _MemberHeroCard({
    required this.member,
    required this.onOpenTraining,
    required this.onOpenNutrition,
    required this.onOpenSessions,
    required this.onOpenChat,
  });

  final CoachMemberDetail member;
  final VoidCallback onOpenTraining;
  final VoidCallback onOpenNutrition;
  final VoidCallback onOpenSessions;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isActive = member.status == 'ACTIVE';
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachingAvatar(
                fullName: member.memberFullName,
                size: 52,
                round: true,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.memberFullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CoachingPill(
                          label: member.statusLabel,
                          tone: isActive
                              ? CoachingPillTone.green
                              : CoachingPillTone.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      member.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          if (member.fitnessGoal?.isNotEmpty == true) ...[
            Divider(
              color: colors.metricPanelBorder.withValues(alpha: 0.45),
              height: 22,
            ),
            Text(
              'Mục tiêu: ${member.fitnessGoal}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
          if (isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeroActionButton(
                    label: 'Giáo trình',
                    onTap: onOpenTraining,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroActionButton(
                    label: 'Thực đơn',
                    onTap: onOpenNutrition,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _HeroActionButton(
                    label: 'Lịch dạy',
                    onTap: onOpenSessions,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroActionButton(
                    label: 'Nhắn tin',
                    primary: true,
                    onTap: onOpenChat,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    if (primary) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: MetaGymTheme.brandOrange,
          foregroundColor: MetaGymTheme.onPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        backgroundColor: colors.metricPanelBg,
        side: BorderSide(color: colors.metricPanelBorder),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _HealthDeclarationCard extends StatelessWidget {
  const _HealthDeclarationCard({required this.member});

  final CoachMemberDetail member;

  double? get _computedBmi {
    final h = member.heightCm;
    final w = member.weightKg;
    if (h == null || w == null || h <= 0 || w <= 0) return null;
    final meters = h / 100;
    return w / (meters * meters);
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final bmi = _computedBmi;
    final hasBodyMetrics =
        member.heightCm != null ||
        member.weightKg != null ||
        member.bodyFatPercent != null;

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MetaGymIcon(
                MetaGymIcons.healthShield,
                size: MetaGymIconSize.xs,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Khai báo thể trạng & Y tế',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (bmi != null) ...[
                const SizedBox(width: 8),
                CoachingPill(
                  label: 'BMI ${bmi.toStringAsFixed(1)}',
                  tone: CoachingPillTone.green,
                ),
              ],
            ],
          ),
          if (hasBodyMetrics) ...[
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: MetaGymMetricPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                      child: _BodyMetricCell(
                        label: 'Chiều cao',
                        value: member.heightCm != null
                            ? '${member.heightCm!.toStringAsFixed(1)} cm'
                            : '—',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetaGymMetricPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                      child: _BodyMetricCell(
                        label: 'Cân nặng',
                        value: member.weightKg != null
                            ? '${member.weightKg!.toStringAsFixed(1)} kg'
                            : '—',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetaGymMetricPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 9,
                      ),
                      child: _BodyMetricCell(
                        label: 'Tỷ lệ mỡ',
                        value: member.bodyFatPercent != null
                            ? '${member.bodyFatPercent!.toStringAsFixed(1)}%'
                            : '—',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Divider(
            color: colors.metricPanelBorder.withValues(alpha: 0.45),
            height: 20,
          ),
          _HealthInfoLine(
            text:
                'Bệnh nền: ${member.healthNotes?.isNotEmpty == true ? member.healthNotes : 'Không'}',
          ),
          if (member.injuryNotes?.isNotEmpty == true)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.metricPanelBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MetaGymIcon(
                    MetaGymIcons.healthInjury,
                    size: MetaGymIconSize.xs,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lưu ý chấn thương',
                          style: TextStyle(
                            color: colors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chấn thương: ${member.injuryNotes}',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const _HealthInfoLine(text: 'Chấn thương: Không'),
        ],
      ),
    );
  }
}

class _BodyMetricCell extends StatelessWidget {
  const _BodyMetricCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    );
  }
}

class _HealthInfoLine extends StatelessWidget {
  const _HealthInfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: colors.textWarmMuted,
          fontSize: 13.5,
          height: 1.45,
          fontFeatures: MetaGymTheme.tabularFigures,
        ),
      ),
    );
  }
}

class _MemberDetailCircleButton extends StatelessWidget {
  const _MemberDetailCircleButton({
    required this.svgAsset,
    required this.testIcon,
    required this.tooltip,
    required this.onTap,
  });

  final String svgAsset;
  final IconData testIcon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: MetaGymTap(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
              highlightColor: MetaGymTheme.brandOrange.withValues(alpha: 0.10),
              focusColor: colors.focus.withValues(alpha: 0.22),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.circleButtonBg,
                    gradient: isLight
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFFFF), Color(0xFFE5ECF5)],
                          )
                        : null,
                    border: Border.all(
                      color: colors.circleButtonBorder,
                      width: 1,
                    ),
                    boxShadow: isLight
                        ? const [
                            BoxShadow(
                              color: Color(0x1A0F172A),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MetaGymIcon(
                        svgAsset,
                        size: MetaGymIconSize.md,
                        excludeFromSemantics: true,
                      ),
                      ExcludeSemantics(
                        child: Icon(
                          testIcon,
                          size: 20,
                          color: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _adaptiveInputDecoration(
  MetaGymColors colors, {
  required String label,
  String? errorText,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
    counterStyle: TextStyle(color: colors.textSecondary, fontSize: 11.5),
    filled: true,
    fillColor: colors.metricPanelBg,
    errorText: errorText,
    errorStyle: TextStyle(color: colors.error),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: colors.error, width: 1.5),
    ),
  );
}

class _CreateOutcomeDialog extends StatefulWidget {
  const _CreateOutcomeDialog({
    required this.memberId,
    required this.api,
    required this.picker,
  });

  final String memberId;
  final CoachOutcomeApi api;
  final ProgressPhotoPicker picker;

  @override
  State<_CreateOutcomeDialog> createState() => _CreateOutcomeDialogState();
}

class _CreateOutcomeDialogState extends State<_CreateOutcomeDialog> {
  final _goal = TextEditingController();
  final _weeks = TextEditingController(text: '12');
  final _beforeWeight = TextEditingController();
  final _afterWeight = TextEditingController();
  final _beforeFat = TextEditingController();
  final _afterFat = TextEditingController();
  SelectedProgressImage? _beforePhoto;
  SelectedProgressImage? _afterPhoto;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _goal,
      _weeks,
      _beforeWeight,
      _afterWeight,
      _beforeFat,
      _afterFat,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parseNumber(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  Future<void> _pickPhoto(bool isBefore) async {
    try {
      final selected = await widget.picker.pick();
      if (selected == null || !mounted) return;
      final validation = validateProgressImage(selected);
      if (validation != null) {
        setState(() => _error = validation);
        return;
      }
      setState(() {
        _error = null;
        if (isBefore) {
          _beforePhoto = selected;
        } else {
          _afterPhoto = selected;
        }
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không chọn được ảnh.');
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final goal = _goal.text.trim();
    final weeks = int.tryParse(_weeks.text.trim());
    final bw = _parseNumber(_beforeWeight.text);
    final aw = _parseNumber(_afterWeight.text);
    final bf = _beforeFat.text.trim().isEmpty
        ? null
        : _parseNumber(_beforeFat.text);
    final af = _afterFat.text.trim().isEmpty
        ? null
        : _parseNumber(_afterFat.text);
    if (goal.isEmpty ||
        weeks == null ||
        weeks <= 0 ||
        bw == null ||
        bw <= 0 ||
        aw == null ||
        aw <= 0) {
      setState(
        () => _error = 'Hãy nhập đủ mục tiêu, số tuần và cân nặng trước/sau.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? beforeMediaId;
      String? afterMediaId;
      if (_beforePhoto != null) {
        beforeMediaId = await widget.api.uploadOutcomePhoto(_beforePhoto!);
      }
      if (_afterPhoto != null) {
        afterMediaId = await widget.api.uploadOutcomePhoto(_afterPhoto!);
      }
      final created = await widget.api.submitOutcome(
        widget.memberId,
        goal: goal,
        durationWeeks: weeks,
        beforeWeightKg: bw,
        afterWeightKg: aw,
        beforeBodyFatPercent: bf,
        afterBodyFatPercent: af,
        beforeMediaId: beforeMediaId,
        afterMediaId: afterMediaId,
      );
      if (mounted) Navigator.pop(context, created);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không gửi được thành quả.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return AlertDialog(
      backgroundColor: colors.overlayGlass,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
        side: BorderSide(color: colors.liquidGlassBorder, width: 1.1),
      ),
      title: Text(
        'Gửi thành quả học viên',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('outcome-goal'),
              controller: _goal,
              cursorColor: MetaGymTheme.brandOrange,
              style: TextStyle(color: colors.textPrimary),
              decoration: _adaptiveInputDecoration(
                colors,
                label: 'Mục tiêu tập luyện',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('outcome-weeks'),
              controller: _weeks,
              cursorColor: MetaGymTheme.brandOrange,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: colors.textPrimary,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
              decoration: _adaptiveInputDecoration(
                colors,
                label: 'Số tuần đồng hành',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('outcome-before-weight'),
                    controller: _beforeWeight,
                    cursorColor: MetaGymTheme.brandOrange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _adaptiveInputDecoration(
                      colors,
                      label: 'Trước (kg)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('outcome-after-weight'),
                    controller: _afterWeight,
                    cursorColor: MetaGymTheme.brandOrange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _adaptiveInputDecoration(
                      colors,
                      label: 'Sau (kg)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('outcome-before-fat'),
                    controller: _beforeFat,
                    cursorColor: MetaGymTheme.brandOrange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _adaptiveInputDecoration(
                      colors,
                      label: '% mỡ trước · tùy chọn',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('outcome-after-fat'),
                    controller: _afterFat,
                    cursorColor: MetaGymTheme.brandOrange,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                    decoration: _adaptiveInputDecoration(
                      colors,
                      label: '% mỡ sau · tùy chọn',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _pickPhoto(true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      backgroundColor: colors.metricPanelBg,
                      minimumSize: const Size(48, 48),
                      side: BorderSide(
                        color: _beforePhoto != null
                            ? colors.success
                            : colors.metricPanelBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                      ),
                    ),
                    child: Text(
                      _beforePhoto == null ? 'Ảnh trước' : 'Đã chọn trước',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _pickPhoto(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      backgroundColor: colors.metricPanelBg,
                      minimumSize: const Size(48, 48),
                      side: BorderSide(
                        color: _afterPhoto != null
                            ? colors.success
                            : colors.metricPanelBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                      ),
                    ),
                    child: Text(
                      _afterPhoto == null ? 'Ảnh sau' : 'Đã chọn sau',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              CoachingErrorBanner(message: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: colors.textWarmMuted,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.primary,
            foregroundColor: MetaGymTheme.onPrimary,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          child: Text(_saving ? 'Đang gửi...' : 'Gửi học viên duyệt'),
        ),
      ],
    );
  }
}

class _TerminationRequestDialog extends StatefulWidget {
  const _TerminationRequestDialog();

  @override
  State<_TerminationRequestDialog> createState() =>
      _TerminationRequestDialogState();
}

class _TerminationRequestDialogState extends State<_TerminationRequestDialog> {
  final _reason = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return AlertDialog(
      backgroundColor: colors.overlayGlass,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
        side: BorderSide(color: colors.liquidGlassBorder, width: 1.1),
      ),
      title: Text(
        'Xin ngừng phụ trách?',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        key: const Key('termination-request-reason'),
        controller: _reason,
        cursorColor: MetaGymTheme.brandOrange,
        maxLength: 1000,
        maxLines: 3,
        style: TextStyle(color: colors.textPrimary),
        decoration: _adaptiveInputDecoration(
          colors,
          label: 'Lý do',
          errorText: _invalid ? 'Vui lòng nhập lý do.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: colors.textWarmMuted,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _reason.text.trim();
            if (reason.isEmpty) {
              setState(() => _invalid = true);
              return;
            }
            Navigator.pop(context, reason);
          },
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.primary,
            foregroundColor: MetaGymTheme.onPrimary,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          child: const Text('Gửi yêu cầu'),
        ),
      ],
    );
  }
}
