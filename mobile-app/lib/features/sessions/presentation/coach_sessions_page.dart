import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_member_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/sessions/data/coach_sessions_service.dart';
import 'package:meta_gym_app/features/sessions/domain/training_session.dart';
import 'package:provider/provider.dart';

enum _CoachSessionTab { all, scheduled, history }

class CoachSessionsPage extends StatefulWidget {
  const CoachSessionsPage({
    this.service,
    this.membersService,
    this.coachBooking,
    super.key,
  });

  final CoachSessionsService? service;
  final CoachMembersService? membersService;
  final Widget? coachBooking;

  @override
  State<CoachSessionsPage> createState() => _CoachSessionsPageState();
}

class _CoachSessionsPageState extends State<CoachSessionsPage> {
  CoachSessionsService? _service;
  CoachMembersService? _membersService;
  List<CoachMemberSummary> _members = const [];
  List<TrainingSession> _sessions = const [];
  bool _loading = true;
  String? _error;
  _CoachSessionTab _currentTab = _CoachSessionTab.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachSessionsService>();
    _membersService =
        widget.membersService ?? context.read<CoachMembersService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sessions = const [];
    });
    try {
      final members = await _membersService!.getMembers();
      final sessions = await _service!.getAll();
      if (mounted) {
        setState(() {
          _members = members;
          _sessions = sessions;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch buổi tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openCoachBooking() {
    final booking = widget.coachBooking;
    if (booking == null) return;
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => booking));
  }

  Future<void> _edit([TrainingSession? session]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SessionFormPage(
          service: _service!,
          session: session,
          members: _members.where((m) => m.status == 'ACTIVE').toList(),
        ),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _changeStatus(TrainingSession session, String status) async {
    String? reason;
    if (status == 'CANCELLED') {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _CancellationDialog(),
      );
      if (reason == null || !mounted) return;
    } else {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xF0241F1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xA3A79D92), width: 1.1),
          ),
          title: const Text(
            'Đổi trạng thái',
            style: TextStyle(
              color: Color(0xFFF7F9FC),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          content: Text(
            status == 'COMPLETED'
                ? 'Đánh dấu hoàn thành?'
                : 'Đánh dấu hội viên vắng?',
            style: const TextStyle(
              color: Color(0xFFE4DAD1),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 48),
                foregroundColor: const Color(0xFFC8C2BC),
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.primary,
                foregroundColor: MetaGymTheme.onPrimary,
                minimumSize: const Size(96, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (submitted != true || !mounted) return;
    }
    try {
      await _service!.update(session.id, {
        'status': status,
        if (status == 'CANCELLED') 'cancellationReason': reason,
      });
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showCoachingSnackBar(context, 'Không cập nhật được buổi tập.');
      }
    }
  }

  List<TrainingSession> _filteredSessions() {
    return _sessions.where((session) {
      return switch (_currentTab) {
        _CoachSessionTab.all => true,
        _CoachSessionTab.scheduled => session.status == 'SCHEDULED',
        _CoachSessionTab.history => session.status != 'SCHEDULED',
      };
    }).toList();
  }

  String _memberName(String? id) {
    for (final member in _members) {
      if (member.memberId == id) return member.memberFullName;
    }
    return 'Hội viên';
  }

  CoachingPill _buildStatusPill(TrainingSession session) {
    return switch (session.status) {
      'SCHEDULED' => const CoachingPill(
        label: 'Đã lên lịch',
        tone: CoachingPillTone.coral,
      ),
      'COMPLETED' => const CoachingPill(
        label: 'Hoàn thành',
        tone: CoachingPillTone.green,
      ),
      'MEMBER_ABSENT' => const CoachingPill(
        label: 'Hội viên vắng',
        tone: CoachingPillTone.amber,
      ),
      'CANCELLED' => const CoachingPill(
        label: 'Đã hủy',
        tone: CoachingPillTone.neutral,
      ),
      _ => CoachingPill(
        label: session.statusLabel,
        tone: CoachingPillTone.neutral,
      ),
    };
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          if (Navigator.of(context).canPop()) ...[
            MetaGymCircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 10),
          ],
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quản lý buổi tập',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Buổi tập 1:1 & điểm danh',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFC8C2BC),
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (widget.coachBooking != null) ...[
            const SizedBox(width: 8),
            MetaGymCircleIconButton(
              icon: Icons.event_available_outlined,
              tooltip: 'Lịch Coach',
              onTap: _openCoachBooking,
            ),
          ],
          const SizedBox(width: 6),
          MetaGymCircleIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Tải lại',
            onTap: _loading ? null : _load,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xB8211E1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x9A8C8176), width: 1.1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SessionTabButton(
              label: 'Tất cả',
              active: _currentTab == _CoachSessionTab.all,
              onTap: () => setState(() => _currentTab = _CoachSessionTab.all),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SessionTabButton(
              label: 'Đã lên lịch',
              active: _currentTab == _CoachSessionTab.scheduled,
              onTap: () =>
                  setState(() => _currentTab = _CoachSessionTab.scheduled),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SessionTabButton(
              label: 'Lịch sử',
              active: _currentTab == _CoachSessionTab.history,
              onTap: () =>
                  setState(() => _currentTab = _CoachSessionTab.history),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingHeroCard() {
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MetaGymTheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: MetaGymTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch làm việc & Buổi hẹn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Cấu hình lịch làm việc tuần, khóa giờ và xem buổi hẹn',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFC8C2BC),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CoachingPrimaryButton(
            label: 'Quản lý lịch làm việc Coach',
            icon: Icons.arrow_forward_rounded,
            onPressed: _openCoachBooking,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(TrainingSession session) {
    final memberName = _memberName(session.memberId);
    final canEdit =
        widget.coachBooking == null && session.status == 'SCHEDULED';
    final reason = session.cancellationReason?.trim();
    final notes = session.notes?.trim();

    final cardContent = Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoachingAvatar(fullName: memberName, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$memberName · ${formatSessionLocalTime(session.scheduledStartAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC8C2BC),
                        fontSize: 12.5,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusPill(session),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x80211E1C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x9A8C8176)),
              ),
              child: Text(
                notes,
                style: const TextStyle(
                  color: Color(0xFFE4DAD1),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Lý do hủy: $reason',
              style: const TextStyle(
                color: Color(0xFFFFB2B6),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0x26FFF5E9), height: 1),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF173B2C),
                    foregroundColor: const Color(0xFF59E59A),
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF216F4B)),
                    ),
                  ),
                  onPressed: () => _changeStatus(session, 'COMPLETED'),
                  child: const Text(
                    'Hoàn thành',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF45311D),
                    foregroundColor: const Color(0xFFFFC573),
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF815423)),
                    ),
                  ),
                  onPressed: () => _changeStatus(session, 'MEMBER_ABSENT'),
                  child: const Text(
                    'Vắng mặt',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0x80211E1C),
                    foregroundColor: MetaGymTheme.dangerCoral,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    side: BorderSide(
                      color: MetaGymTheme.dangerCoral.withValues(alpha: 0.55),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _changeStatus(session, 'CANCELLED'),
                  child: const Text(
                    'Hủy buổi',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return MetaGymGlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: canEdit
          ? InkWell(
              onTap: () => _edit(session),
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
              child: cardContent,
            )
          : cardContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleSessions = _filteredSessions();
    final canCreate =
        widget.coachBooking == null &&
        !_loading &&
        _members.any((m) => m.status == 'ACTIVE');

    return Scaffold(
      backgroundColor: MetaGymTheme.paletteOf(context).canvas,
      floatingActionButton: !canCreate
          ? null
          : FloatingActionButton.extended(
              backgroundColor: MetaGymTheme.primary,
              foregroundColor: MetaGymTheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Tạo buổi tập',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  child: _buildSegmentedTabs(),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.primary,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.primary,
                          backgroundColor: const Color(0xFF2B2622),
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              MediaQuery.paddingOf(context).bottom + 96,
                            ),
                            children: [
                              if (widget.coachBooking != null)
                                _buildBookingHeroCard(),
                              if (_error != null) ...[
                                CoachingErrorBanner(message: _error!),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: CoachingSecondaryButton(
                                    label: 'Thử lại',
                                    onPressed: _load,
                                  ),
                                ),
                              ] else if (visibleSessions.isEmpty) ...[
                                MetaGymGlassCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 30,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: const Color(0x80211E1C),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0x9A8C8176),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.event_busy_rounded,
                                          color: Color(0xFFC8C2BC),
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _sessions.isEmpty
                                            ? 'Chưa có buổi tập nào.'
                                            : 'Không có buổi tập ở mục này.',
                                        style: const TextStyle(
                                          color: Color(0xFFF7F9FC),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _sessions.isEmpty
                                            ? 'Các buổi tập mới với học viên sẽ hiển thị tại đây.'
                                            : 'Chuyển sang tab Tất cả để xem toàn bộ lịch buổi tập.',
                                        style: const TextStyle(
                                          color: Color(0xFFC8C2BC),
                                          fontSize: 12.5,
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.fitness_center_rounded,
                                        color: MetaGymTheme.primary,
                                        size: 17,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Danh sách buổi tập',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Color(0xFFF7F9FC),
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${visibleSessions.length} buổi',
                                        style: const TextStyle(
                                          color: Color(0xFFC8C2BC),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          fontFeatures:
                                              MetaGymTheme.tabularFigures,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                for (final session in visibleSessions)
                                  _buildSessionCard(session),
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

class _SessionTabButton extends StatelessWidget {
  const _SessionTabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFF472C22) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: active
                  ? Border.all(color: MetaGymTheme.brandOrange, width: 1.2)
                  : null,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFFC8C2BC),
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CancellationDialog extends StatefulWidget {
  const _CancellationDialog();

  @override
  State<_CancellationDialog> createState() => _CancellationDialogState();
}

class _CancellationDialogState extends State<_CancellationDialog> {
  final _reason = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xF0241F1B),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xA3A79D92), width: 1.1),
    ),
    title: const Text(
      'Hủy buổi tập',
      style: TextStyle(
        color: Color(0xFFF7F9FC),
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
    ),
    content: TextField(
      controller: _reason,
      key: const Key('session-cancellation-reason'),
      maxLength: 2000,
      maxLines: 3,
      style: const TextStyle(color: Color(0xFFF7F9FC)),
      decoration: InputDecoration(
        labelText: 'Lý do hủy',
        labelStyle: const TextStyle(color: Color(0xFFC8C2BC)),
        filled: true,
        fillColor: const Color(0x99211E1C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
          borderSide: const BorderSide(color: Color(0x9A8C8176)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
          borderSide: const BorderSide(color: Color(0x9A8C8176)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
          borderSide: const BorderSide(
            color: MetaGymTheme.brandOrange,
            width: 1.5,
          ),
        ),
        errorText: _invalid ? 'Vui lòng nhập lý do hủy.' : null,
      ),
    ),
    actions: [
      TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: const Color(0xFFC8C2BC),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: MetaGymTheme.primary,
          foregroundColor: MetaGymTheme.onPrimary,
          minimumSize: const Size(112, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          final reason = _reason.text.trim();
          if (reason.isEmpty) {
            setState(() => _invalid = true);
            return;
          }
          Navigator.pop(context, reason);
        },
        child: const Text('Xác nhận hủy'),
      ),
    ],
  );
}

class _SessionFormPage extends StatefulWidget {
  const _SessionFormPage({
    required this.service,
    required this.members,
    this.session,
  });

  final CoachSessionsService service;
  final List<CoachMemberSummary> members;
  final TrainingSession? session;

  @override
  State<_SessionFormPage> createState() => _SessionFormPageState();
}

class _SessionFormPageState extends State<_SessionFormPage> {
  final _title = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _notes = TextEditingController();
  String? _memberId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _memberId =
        session?.memberId ??
        (widget.members.isEmpty ? null : widget.members.first.memberId);
    if (session != null) {
      _title.text = session.title;
      _start.text = formatSessionLocalTime(session.scheduledStartAt);
      _end.text = session.scheduledEndAt == null
          ? ''
          : formatSessionLocalTime(session.scheduledEndAt!);
      _notes.text = session.notes ?? '';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _start.dispose();
    _end.dispose();
    _notes.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFFC8C2BC)),
      hintStyle: const TextStyle(color: Color(0xFF9C948D)),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 19, color: const Color(0xFFC8C2BC)),
      filled: true,
      fillColor: const Color(0x99211E1C),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: Color(0x9A8C8176)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: Color(0x9A8C8176)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(
          color: MetaGymTheme.brandOrange,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
        borderSide: const BorderSide(color: MetaGymTheme.dangerCoral),
      ),
    );
  }

  Future<void> _save() async {
    final start = parseSessionLocalTime(_start.text);
    final end = _end.text.trim().isEmpty
        ? null
        : parseSessionLocalTime(_end.text);
    String? validation;
    if (_memberId == null ||
        _title.text.trim().isEmpty ||
        start == null ||
        (_end.text.trim().isNotEmpty && end == null)) {
      validation = 'Nhập tên và thời gian hợp lệ (dd/MM/yyyy HH:mm).';
    } else if (end != null && !end.isAfter(start)) {
      validation = 'Giờ kết thúc phải sau giờ bắt đầu.';
    }
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, Object?>{
      if (widget.session == null) 'memberId': _memberId,
      'title': _title.text.trim(),
      'scheduledStartAt': start!.toUtc().toIso8601String(),
      'scheduledEndAt': end?.toUtc().toIso8601String(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    try {
      if (widget.session case final session?) {
        await widget.service.update(session.id, payload);
      } else {
        await widget.service.create(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được buổi tập.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = widget.session == null;
    return Scaffold(
      backgroundColor: MetaGymTheme.paletteOf(context).canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      MetaGymCircleIconButton(
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
                              isCreate ? 'Tạo buổi tập' : 'Sửa buổi tập',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Thiết lập lịch tập & ghi chú cho học viên',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFC8C2BC),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      MediaQuery.paddingOf(context).bottom + 28,
                    ),
                    children: [
                      MetaGymGlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isCreate) ...[
                              DropdownButtonFormField<String>(
                                initialValue: _memberId,
                                dropdownColor: const Color(0xF0241F1B),
                                style: const TextStyle(
                                  color: Color(0xFFF7F9FC),
                                  fontSize: 14,
                                ),
                                decoration: _fieldDecoration(
                                  label: 'Hội viên',
                                  icon: Icons.person_outline_rounded,
                                ),
                                items: widget.members
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m.memberId,
                                        child: Text(
                                          m.memberFullName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _memberId = value),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextField(
                              key: const Key('session-title'),
                              controller: _title,
                              maxLength: 150,
                              style: const TextStyle(
                                color: MetaGymTheme.textPrimary,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Tên buổi tập',
                                hint: 'VD: Tập chân & Core',
                                icon: Icons.fitness_center_rounded,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const Key('session-start'),
                              controller: _start,
                              keyboardType: TextInputType.datetime,
                              style: const TextStyle(
                                color: MetaGymTheme.textPrimary,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Bắt đầu (dd/MM/yyyy HH:mm)',
                                hint: '24/10/2026 08:00',
                                icon: Icons.schedule_rounded,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              key: const Key('session-end'),
                              controller: _end,
                              keyboardType: TextInputType.datetime,
                              style: const TextStyle(
                                color: MetaGymTheme.textPrimary,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Kết thúc (tùy chọn)',
                                hint: '24/10/2026 09:00',
                                icon: Icons.timer_off_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _notes,
                              maxLength: 5000,
                              maxLines: 3,
                              style: const TextStyle(
                                color: MetaGymTheme.textPrimary,
                              ),
                              decoration: _fieldDecoration(
                                label: 'Ghi chú',
                                hint:
                                    'Yêu cầu khởi động hoặc lưu ý chấn thương…',
                                icon: Icons.notes_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) CoachingErrorBanner(message: _error!),
                      CoachingPrimaryButton(
                        label: _saving ? 'Đang lưu…' : 'Lưu',
                        icon: Icons.check_rounded,
                        onPressed: _saving ? null : _save,
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

DateTime? parseSessionLocalTime(String input) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4}) (\d{2}):(\d{2})$')
      .firstMatch(input.trim());
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final time = DateTime(year, month, day, hour, minute);
  if (time.year != year ||
      time.month != month ||
      time.day != day ||
      time.hour != hour ||
      time.minute != minute) {
    return null;
  }
  return time;
}
