import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
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
    this.memberName,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final String id;
  final CoachTrainingService service;
  final String? memberId;
  final String? memberName;
  final bool useSolidGlassFallback;

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
    final saved = await MetaGymNavigation.pushOnce<String>(
      context,
      MetaGymPageRoute(
        builder: (_) => CoachPlanFormPage(
          memberId: widget.memberId ?? '',
          memberName: widget.memberName,
          useSolidGlassFallback: widget.useSolidGlassFallback,
          plan: plan,
          service: widget.service,
        ),
      ),
    );
    if (saved != null && mounted) await _load();
  }

  Future<void> _publish() async {
    if (_busy || _plan?.status != 'DRAFT') return;
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final confirmed = await MetaGymNavigation.showDialogOnce<bool>(
      context: context,
      barrierColor: colors.scrim,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isLight ? colors.surface : colors.overlayGlass,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
          side: BorderSide(color: colors.overlayGlassBorder, width: 1.1),
        ),
        title: Text(
          'Công bố giáo trình?',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Member sẽ thấy bản này; bản đang dùng chuyển vào lịch sử.',
          style: TextStyle(
            color: colors.textWarmMuted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: colors.textSecondary,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.primary,
              foregroundColor: MetaGymTheme.onPrimary,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              ),
            ),
            child: const Text('Xác nhận công bố'),
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

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors, {
    required bool canEdit,
  }) {
    final canPop = Navigator.of(context).canPop();
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    final memberTag = widget.memberName?.trim();
    final eyebrow = memberTag != null && memberTag.isNotEmpty
        ? 'GIÁO ÁN TẬP · ${memberTag.toUpperCase()}'
        : 'GIÁO ÁN TẬP LUYỆN';

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chi tiết giáo trình',
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
              ],
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 8),
            MetaGymCircleIconButton(
              key: const Key('plan-detail-header-edit'),
              svgAsset: MetaGymIcons.commonEdit,
              icon: Icons.edit_outlined,
              tooltip: 'Chỉnh sửa',
              onTap: _busy ? null : _edit,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final plan = _plan;
    final canEditActive =
        plan != null &&
        widget.service is CoachTrainingApi &&
        plan.status == 'ACTIVE';
    final canEditOrPublishDraft =
        plan != null &&
        widget.service is! CoachTrainingApi &&
        plan.status == 'DRAFT';
    final canEdit = canEditActive || canEditOrPublishDraft;
    final showBottomBar = canEdit || _actionError != null;
    final media = MediaQuery.paddingOf(context);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MetaGymBackground(useSolidFallback: widget.useSolidGlassFallback),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(context, colors, canEdit: canEdit),
                  Expanded(
                    child: plan == null && _error == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.primary,
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: RefreshIndicator(
                                  color: MetaGymTheme.primary,
                                  backgroundColor: colors.overlayGlass,
                                  onRefresh: _load,
                                  child: ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      gutter,
                                      4,
                                      gutter,
                                      showBottomBar ? 18 : media.bottom + 36,
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
                                      if (plan != null)
                                        TrainingPlanContent(
                                          plan: plan,
                                          useSolidGlassFallback:
                                              widget.useSolidGlassFallback,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (showBottomBar)
                                Container(
                                  decoration: BoxDecoration(
                                    color: isLight
                                        ? colors.surface
                                        : colors.overlayGlass,
                                    border: Border(
                                      top: BorderSide(
                                        color: colors.overlayGlassBorder,
                                      ),
                                    ),
                                  ),
                                  child: SafeArea(
                                    top: false,
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        gutter,
                                        12,
                                        gutter,
                                        16,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_actionError != null)
                                            CoachingErrorBanner(
                                              message: _actionError!,
                                            ),
                                          if (canEditActive)
                                            CoachingPrimaryButton(
                                              key: const Key(
                                                'plan-detail-edit-active-btn',
                                              ),
                                              label: 'Chỉnh sửa giáo trình',
                                              icon: Icons.edit_outlined,
                                              onPressed: _busy ? null : _edit,
                                            ),
                                          if (canEditOrPublishDraft)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child:
                                                      CoachingSecondaryButton(
                                                        label: 'Sửa bản nháp',
                                                        onPressed: _busy
                                                            ? null
                                                            : _edit,
                                                      ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: CoachingPrimaryButton(
                                                    label: 'Công bố',
                                                    loading: _busy,
                                                    onPressed: _busy
                                                        ? null
                                                        : _publish,
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
