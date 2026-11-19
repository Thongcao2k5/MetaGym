import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/training/data/coach_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/coach_plan_form_page.dart';
import 'package:meta_gym_app/features/training/presentation/training_plan_content.dart';

class CoachPlanDetailPage extends StatefulWidget {
  const CoachPlanDetailPage({
    required this.id,
    required this.service,
    this.memberId,
    super.key,
  });

  final String id;
  final CoachTrainingService service;
  final String? memberId;

  @override
  State<CoachPlanDetailPage> createState() => _CoachPlanDetailPageState();
}

class _CoachPlanDetailPageState extends State<CoachPlanDetailPage> {
  TrainingPlan? _plan;
  String? _error;
  String? _actionError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _plan = null;
      _error = null;
    });
    try {
      final plan = await widget.service.getPlan(widget.id);
      if (mounted) setState(() => _plan = plan);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được giáo trình.');
    }
  }

  Future<void> _edit() async {
    final plan = _plan;
    if (plan == null ||
        (widget.service is CoachTrainingApi
            ? plan.status != 'ACTIVE'
            : plan.status != 'DRAFT')) {
      return;
    }
    final saved = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CoachPlanFormPage(
          memberId: widget.memberId ?? '',
          plan: plan,
          service: widget.service,
        ),
      ),
    );
    if (saved != null && mounted) await _load();
  }

  Future<void> _publish() async {
    if (_busy || _plan?.status != 'DRAFT') return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB8040609),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: coachingWarmOverlaySurface,
        surfaceTintColor: Colors.transparent,
        shape: coachingDialogShape,
        title: const Text(
          'Công bố giáo trình?',
          style: TextStyle(
            color: coachingWarmTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Member sẽ thấy bản này; bản đang dùng chuyển vào lịch sử.',
          style: TextStyle(
            color: coachingWarmTextSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: coachingWarmTextSecondary,
              minimumSize: const Size(48, 44),
            ),
            child: const Text('Quay lại'),
          ),
          CoachingCompactAccentButton(
            label: 'Xác nhận công bố',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _plan?.status != 'DRAFT') return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await widget.service.publish(widget.id);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _actionError = error.code == 'PUBLICATION_NOT_ALLOWED'
              ? 'Không thể công bố: bản nháp đã thay đổi hoặc quan hệ Coach–Member không còn hoạt động.'
              : error.message,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Không công bố được giáo trình.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final canEditActive =
        plan != null &&
        widget.service is CoachTrainingApi &&
        plan.status == 'ACTIVE';
    final canEditOrPublishDraft =
        plan != null &&
        widget.service is! CoachTrainingApi &&
        plan.status == 'DRAFT';
    final showBottomBar =
        canEditActive || canEditOrPublishDraft || _actionError != null;
    final media = MediaQuery.paddingOf(context);
    final canPop = Navigator.of(context).canPop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.scaffoldBackground,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 72,
          leading: canPop
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MetaGymCircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                )
              : null,
          titleSpacing: canPop ? 8 : 16,
          title: const Text(
            'Chi tiết giáo trình',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: MetaGymCircleIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Tải lại',
                  onTap: _busy ? null : _load,
                ),
              ),
            ),
          ],
          backgroundColor: Colors.transparent,
          foregroundColor: MetaGymTheme.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            if (plan == null && _error == null)
              const Center(
                child: CircularProgressIndicator(color: MetaGymTheme.primary),
              )
            else
              Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      color: MetaGymTheme.primary,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          media.top + kToolbarHeight + 12,
                          16,
                          showBottomBar ? 16 : media.bottom + 24,
                        ),
                        children: [
                          if (_error != null) ...[
                            CoachingErrorBanner(message: _error!),
                            CoachingSecondaryButton(
                              label: 'Thử lại',
                              onPressed: _load,
                              expand: true,
                            ),
                          ],
                          if (plan != null) TrainingPlanContent(plan: plan),
                        ],
                      ),
                    ),
                  ),
                  if (showBottomBar)
                    Container(
                      decoration: const BoxDecoration(
                        color: coachingWarmOverlaySurface,
                        border: Border(
                          top: BorderSide(color: coachingWarmDivider),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_actionError != null)
                                CoachingErrorBanner(message: _actionError!),
                              if (canEditActive)
                                CoachingPrimaryButton(
                                  label: 'Sửa giáo trình',
                                  icon: Icons.edit_outlined,
                                  onPressed: _busy ? null : _edit,
                                ),
                              if (canEditOrPublishDraft)
                                Row(
                                  children: [
                                    Expanded(
                                      child: CoachingSecondaryButton(
                                        label: 'Sửa bản nháp',
                                        onPressed: _busy ? null : _edit,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CoachingPrimaryButton(
                                        label: 'Công bố',
                                        loading: _busy,
                                        onPressed: _busy ? null : _publish,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
