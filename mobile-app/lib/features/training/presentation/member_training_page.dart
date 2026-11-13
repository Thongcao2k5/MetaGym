import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/training/data/member_training_service.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';
import 'package:meta_gym_app/features/training/presentation/training_plan_content.dart';
import 'package:meta_gym_app/features/training/presentation/gym_visits_page.dart';
import 'package:provider/provider.dart';

class MemberTrainingPage extends StatefulWidget {
  const MemberTrainingPage({this.service, this.bottomPadding, super.key});

  final MemberTrainingService? service;
  final double? bottomPadding;

  @override
  State<MemberTrainingPage> createState() => _MemberTrainingPageState();
}

class _MemberTrainingPageState extends State<MemberTrainingPage> {
  MemberTrainingService? _service;
  TrainingPlan? _active;
  List<TrainingPlan> _history = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberTrainingService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _active = null;
      _history = const [];
    });
    try {
      final active = await _service!.getActive();
      final history = await _service!.getHistory();
      if (!mounted) return;
      setState(() {
        _active = active?.status == 'ACTIVE' ? active : null;
        _history = history
            .where((plan) => plan.status == 'ARCHIVED' && plan.id != active?.id)
            .toList();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được giáo trình.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPlan(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _MemberTrainingDetailPage(id: id, service: _service!),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottomPadding =
        widget.bottomPadding ?? MetaGymBottomNav.contentBottomPadding(context);

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          'Giáo trình',
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            fontFamily: MetaGymTheme.fontFamily,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: MetaGymTheme.textSecondary,
              size: 22,
            ),
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading && _active == null && _history.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: MetaGymTheme.primary,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: MetaGymTheme.darkSurfaceRaised,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  MetaGymTheme.pageGutter,
                  12,
                  MetaGymTheme.pageGutter,
                  effectiveBottomPadding + 24,
                ),
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).push<void>(MaterialPageRoute(
                      builder: (_) => const GymVisitsPage())),
                    borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: MetaGymTheme.cardSurface,
                        border: Border.all(color: MetaGymTheme.cardBorder),
                        borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard)),
                      child: const Row(children: [
                        Icon(Icons.qr_code_scanner, color: MetaGymTheme.primary),
                        SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lịch sử đến gym', style: TextStyle(
                              color: MetaGymTheme.textPrimary, fontWeight: FontWeight.w600)),
                            SizedBox(height: 3),
                            Text('Xem ngày đã đến và quét QR tại quầy', style: TextStyle(
                              color: MetaGymTheme.textSecondary, fontSize: 12)),
                          ])),
                        Icon(Icons.chevron_right, color: MetaGymTheme.textSecondary),
                      ]),
                    ),
                  ),
                  if (_error != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0x1FF15B64),
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusCard,
                        ),
                        border: Border.all(color: const Color(0x4DF15B64)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: MetaGymTheme.dangerCoral,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: MetaGymTheme.fontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _load,
                            icon: const Icon(
                              Icons.replay_rounded,
                              size: 16,
                              color: MetaGymTheme.brandOrange,
                            ),
                            label: const Text(
                              'Thử lại',
                              style: TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontWeight: FontWeight.w600,
                                fontFamily: MetaGymTheme.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Section 1: Hiện hành
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: MetaGymTheme.brandOrange,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hiện hành',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: MetaGymTheme.darkTextPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                fontFamily: MetaGymTheme.fontFamily,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_active == null)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: MetaGymTheme.darkSurface,
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusCard,
                          ),
                          border: Border.all(
                            color: MetaGymTheme.darkCardBorderSubtle,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0x14A9C7E8),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x2EA9C7E8),
                                ),
                              ),
                              child: const Icon(
                                Icons.event_note_outlined,
                                color: MetaGymTheme.reflectionBlue,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Bạn chưa được giao giáo trình.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MetaGymTheme.darkTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: MetaGymTheme.fontFamily,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Huấn luyện viên của bạn sẽ sớm thiết lập và công bố kế hoạch tập luyện phù hợp.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: MetaGymTheme.darkTextTertiary,
                                fontSize: 13,
                                height: 1.4,
                                fontFamily: MetaGymTheme.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusCard,
                          ),
                          onTap: () => _openPlan(_active!.id),
                          child: Container(
                            padding: const EdgeInsets.all(
                              MetaGymTheme.cardPadding,
                            ),
                            decoration: BoxDecoration(
                              color: MetaGymTheme.darkSurface,
                              borderRadius: BorderRadius.circular(
                                MetaGymTheme.radiusCard,
                              ),
                              border: Border.all(
                                color: MetaGymTheme.darkCardBorderSubtle,
                              ),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  MetaGymTheme.darkSurfaceRaised,
                                  MetaGymTheme.darkSurface,
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x26FF5A36),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0x59FF5A36),
                                        ),
                                      ),
                                      child: const Text(
                                        'Đang áp dụng',
                                        style: TextStyle(
                                          color: MetaGymTheme.brandOrange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: MetaGymTheme.fontFamily,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      'Phiên bản ${_active!.version}',
                                      style: const TextStyle(
                                        color: MetaGymTheme.darkTextTertiary,
                                        fontSize: 12,
                                        fontFamily: MetaGymTheme.fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _active!.title,
                                  style: const TextStyle(
                                    color: MetaGymTheme.darkTextPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.015,
                                    fontFamily: MetaGymTheme.fontFamily,
                                  ),
                                ),
                                if (_active!.goal?.isNotEmpty == true) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.track_changes_rounded,
                                        size: 15,
                                        color: MetaGymTheme.reflectionBlue,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _active!.goal!,
                                          style: const TextStyle(
                                            color:
                                                MetaGymTheme.darkTextSecondary,
                                            fontSize: 13,
                                            fontFamily: MetaGymTheme.fontFamily,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x14A9C7E8),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0x24A9C7E8),
                                        ),
                                      ),
                                      child: Text(
                                        '${_active!.days.length} ngày tập / tuần',
                                        style: const TextStyle(
                                          color: MetaGymTheme.reflectionBlue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: MetaGymTheme.fontFamily,
                                        ),
                                      ),
                                    ),
                                    const Row(
                                      children: [
                                        Text(
                                          'Xem chi tiết',
                                          style: TextStyle(
                                            color: MetaGymTheme.brandOrange,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: MetaGymTheme.fontFamily,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: MetaGymTheme.brandOrange,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 28),

                    // Section 2: Lịch sử
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: MetaGymTheme.reflectionBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Lịch sử',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: MetaGymTheme.darkTextPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                fontFamily: MetaGymTheme.fontFamily,
                              ),
                        ),
                        if (_history.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x14A9C7E8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_history.length}',
                              style: const TextStyle(
                                color: MetaGymTheme.reflectionBlue,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: MetaGymTheme.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_history.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: MetaGymTheme.darkSurface,
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusCard,
                          ),
                          border: Border.all(
                            color: MetaGymTheme.darkCardBorderSubtle,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Chưa có giáo trình cũ.',
                            style: TextStyle(
                              color: MetaGymTheme.darkTextTertiary,
                              fontSize: 14,
                              fontFamily: MetaGymTheme.fontFamily,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final plan in _history)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openPlan(plan.id),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: MetaGymTheme.darkSurfaceMid,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: MetaGymTheme.darkCardBorderSubtle,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0x1F222B35),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: MetaGymTheme.darkBorderSubtle,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 20,
                                        color: MetaGymTheme.darkTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            plan.title,
                                            style: const TextStyle(
                                              color:
                                                  MetaGymTheme.darkTextPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              fontFamily:
                                                  MetaGymTheme.fontFamily,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${plan.statusLabel} · Phiên bản ${plan.version}',
                                            style: const TextStyle(
                                              color:
                                                  MetaGymTheme.darkTextTertiary,
                                              fontSize: 12.5,
                                              fontFamily:
                                                  MetaGymTheme.fontFamily,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: MetaGymTheme.darkTextTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                  SizedBox(height: effectiveBottomPadding),
                ],
              ),
            ),
    );
  }
}

class _MemberTrainingDetailPage extends StatefulWidget {
  const _MemberTrainingDetailPage({required this.id, required this.service});

  final String id;
  final MemberTrainingService service;

  @override
  State<_MemberTrainingDetailPage> createState() =>
      _MemberTrainingDetailPageState();
}

class _MemberTrainingDetailPageState extends State<_MemberTrainingDetailPage> {
  TrainingPlan? _plan;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _plan = null;
      _error = null;
    });
    try {
      final plan = await widget.service.getPlan(widget.id);
      if (!mounted) return;
      setState(() {
        if (plan.status == 'ACTIVE' || plan.status == 'ARCHIVED') {
          _plan = plan;
        } else {
          _error = 'Không tìm thấy giáo trình đã công bố.';
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được chi tiết giáo trình.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      appBar: AppBar(
        title: const Text(
          'Chi tiết giáo trình',
          style: TextStyle(
            color: MetaGymTheme.darkTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            fontFamily: MetaGymTheme.fontFamily,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: MetaGymTheme.darkTextPrimary,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: MetaGymTheme.primary,
                strokeWidth: 2.5,
              ),
            )
          : RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: MetaGymTheme.darkSurfaceRaised,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(MetaGymTheme.pageGutter),
                children: [
                  if (_error != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0x1FF15B64),
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusCard,
                        ),
                        border: Border.all(color: const Color(0x4DF15B64)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: MetaGymTheme.dangerCoral,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: MetaGymTheme.fontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _load,
                            child: const Text(
                              'Thử lại',
                              style: TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontWeight: FontWeight.w600,
                                fontFamily: MetaGymTheme.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_plan != null) TrainingPlanContent(plan: _plan!),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
