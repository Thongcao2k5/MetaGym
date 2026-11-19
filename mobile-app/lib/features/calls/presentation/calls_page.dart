import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/domain/call_log.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:provider/provider.dart';

class CallsPage extends StatefulWidget {
  const CallsPage({this.service, required this.currentUserId, super.key});
  final CallsService? service;
  final String currentUserId;

  @override
  State<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends State<CallsPage> {
  CallsService? _service;
  List<CallLog> _calls = const [];
  List<Conversation> _relationships = const [];
  String? _selectedRelationship;
  String _callType = 'VOICE';
  bool _loading = true;
  bool _saving = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CallsService>();
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
      final calls = await _service!.getCalls(1);
      final relationships = await _service!.getActiveRelationships();
      if (mounted) {
        setState(() {
          _calls = calls;
          _relationships = relationships;
          _selectedRelationship =
              relationships.any(
                (item) => item.relationshipId == _selectedRelationship,
              )
              ? _selectedRelationship
              : relationships.firstOrNull?.relationshipId;
          _page = 1;
          _hasMore = calls.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch sử gọi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final calls = await _service!.getCalls(_page + 1);
      if (mounted) {
        setState(() {
          _calls = [..._calls, ...calls];
          _page++;
          _hasMore = calls.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải thêm được cuộc gọi.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _create() async {
    final relationshipId = _selectedRelationship;
    if (_saving || relationshipId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final call = await _service!.create(relationshipId, _callType);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CallDetailPage(
            service: _service!,
            call: call,
            currentUserId: widget.currentUserId,
          ),
        ),
      );
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tạo được cuộc gọi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            'Lịch sử cuộc gọi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: coachingWarmTextPrimary,
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
                  onTap: _loading ? null : _load,
                ),
              ),
            ),
          ],
          backgroundColor: Colors.transparent,
          foregroundColor: coachingWarmTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: coachingWarmOverlaySurface,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        media.top + kToolbarHeight + 12,
                        16,
                        media.bottom + 24,
                      ),
                      children: [
                        MetaGymGlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: MetaGymTheme.reflectionBlue.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  color: MetaGymTheme.reflectionBlue,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Đây chỉ là bản ghi thử API. Ứng dụng chưa tích hợp RTC, '
                                  'nên không thể kết nối cuộc gọi thoại/video thật.',
                                  style: TextStyle(
                                    color: coachingWarmTextSecondary,
                                    fontSize: 12.5,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          CoachingSecondaryButton(
                            label: 'Thử lại',
                            expand: true,
                            onPressed: _calls.isEmpty ? _load : _loadMore,
                          ),
                          const SizedBox(height: 14),
                        ],
                        MetaGymGlassCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          child: _relationships.isEmpty
                              ? Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: coachingWarmNestedSurface,
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: coachingWarmInputBorder,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.person_off_outlined,
                                        color: coachingWarmTextSecondary,
                                        size: 19,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Chưa có quan hệ hoạt động để tạo cuộc gọi.',
                                        style: TextStyle(
                                          color: coachingWarmTextSecondary,
                                          fontSize: 13.5,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Khởi tạo cuộc gọi thử',
                                      style: TextStyle(
                                        color: coachingWarmTextPrimary,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedRelationship,
                                      isExpanded: true,
                                      dropdownColor: coachingWarmOverlaySurface,
                                      style: const TextStyle(
                                        color: coachingWarmTextPrimary,
                                        fontSize: 14,
                                      ),
                                      decoration: coachingInputDecoration(
                                        label: 'Quan hệ',
                                        prefixIcon: Icons.link_rounded,
                                      ),
                                      items: [
                                        for (final item in _relationships)
                                          DropdownMenuItem(
                                            value: item.relationshipId,
                                            child: Text(
                                              'Quan hệ ${item.relationshipId}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                      onChanged: (value) => setState(
                                        () => _selectedRelationship = value,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      initialValue: _callType,
                                      isExpanded: true,
                                      dropdownColor: coachingWarmOverlaySurface,
                                      style: const TextStyle(
                                        color: coachingWarmTextPrimary,
                                        fontSize: 14,
                                      ),
                                      decoration: coachingInputDecoration(
                                        label: 'Loại cuộc gọi',
                                        prefixIcon: Icons.call_outlined,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'VOICE',
                                          child: Text(
                                            'Thoại',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'VIDEO',
                                          child: Text(
                                            'Video',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) => setState(
                                        () => _callType = value ?? 'VOICE',
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    CoachingPrimaryButton(
                                      label: _saving
                                          ? 'Đang tạo…'
                                          : 'Tạo bản ghi cuộc gọi',
                                      icon: Icons.call_outlined,
                                      loading: _saving,
                                      onPressed: _saving ? null : _create,
                                    ),
                                  ],
                                ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Lịch sử gần đây',
                            style: TextStyle(
                              color: coachingWarmTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_calls.isEmpty && _error == null)
                          const MetaGymGlassCard(
                            padding: EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history_toggle_off_rounded,
                                  color: coachingWarmTextSecondary,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Chưa có cuộc gọi nào.',
                                    style: TextStyle(
                                      color: coachingWarmTextSecondary,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        for (final call in _calls)
                          MetaGymGlassCard(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CallDetailPage(
                                    service: _service!,
                                    call: call,
                                    currentUserId: widget.currentUserId,
                                  ),
                                ),
                              );
                              if (mounted) _load();
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: MetaGymTheme.brandOrange.withValues(
                                      alpha: 0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: MetaGymTheme.brandOrange
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Icon(
                                    call.callType == 'VIDEO'
                                        ? Icons.videocam_outlined
                                        : Icons.call_outlined,
                                    color: MetaGymTheme.brandOrange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${call.typeLabel} · ${call.statusLabel}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: coachingWarmTextPrimary,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        call.initiatedAt,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: coachingWarmTextSecondary,
                                          fontSize: 12,
                                          fontFeatures:
                                              MetaGymTheme.tabularFigures,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: coachingWarmTextSecondary,
                                ),
                              ],
                            ),
                          ),
                        if (_hasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: CoachingSecondaryButton(
                              label: _loadingMore ? 'Đang tải…' : 'Tải thêm',
                              expand: true,
                              onPressed: _loadingMore ? null : _loadMore,
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

class CallDetailPage extends StatefulWidget {
  const CallDetailPage({
    required this.service,
    required this.call,
    required this.currentUserId,
    super.key,
  });
  final CallsService service;
  final CallLog call;
  final String currentUserId;
  @override
  State<CallDetailPage> createState() => _CallDetailPageState();
}

class _CallDetailPageState extends State<CallDetailPage> {
  late CallLog _call = widget.call;
  bool _saving = false;
  String? _error;

  CoachingPillTone _toneForStatus(String status) => switch (status) {
    'ANSWERED' || 'ENDED' => CoachingPillTone.green,
    'MISSED' || 'REJECTED' || 'FAILED' => CoachingPillTone.coral,
    _ => CoachingPillTone.amber,
  };

  Future<void> _update(String status, {String? failureReason}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.service.updateStatus(
        _call.id,
        status,
        failureReason: failureReason,
      );
      if (mounted) setState(() => _call = result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không cập nhật được cuộc gọi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiver = _call.receiverId == widget.currentUserId;
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
            'Trạng thái cuộc gọi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: coachingWarmTextPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: coachingWarmTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                media.top + kToolbarHeight + 12,
                16,
                media.bottom + 24,
              ),
              children: [
                MetaGymHeroGlassCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: MetaGymTheme.brandOrange.withValues(
                            alpha: 0.16,
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _call.callType == 'VIDEO'
                              ? Icons.videocam_outlined
                              : Icons.call_outlined,
                          color: MetaGymTheme.brandOrange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _call.typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: coachingWarmTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CoachingPill(
                        label: _call.statusLabel,
                        tone: _toneForStatus(_call.status),
                      ),
                    ],
                  ),
                ),
                MetaGymGlassCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chỉ hiển thị metadata. Chưa có RTC để kết nối âm thanh/video.',
                        style: TextStyle(
                          color: coachingWarmTextSecondary,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                      const Divider(color: coachingWarmDivider, height: 22),
                      _CallMetaRow(
                        label: 'Quan hệ',
                        value: _call.relationshipId,
                      ),
                      const SizedBox(height: 10),
                      _CallMetaRow(
                        label: 'Thời điểm tạo',
                        value: _call.initiatedAt,
                      ),
                      if (_call.endedAt != null) ...[
                        const SizedBox(height: 10),
                        _CallMetaRow(label: 'Kết thúc', value: _call.endedAt!),
                      ],
                      if (_call.failureReason != null) ...[
                        const SizedBox(height: 10),
                        _CallMetaRow(
                          label: 'Lý do',
                          value: _call.failureReason!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null) CoachingErrorBanner(message: _error!),
                if (_call.status == 'CREATED' || _call.status == 'RINGING') ...[
                  if (_call.status == 'CREATED') ...[
                    CoachingSecondaryButton(
                      label: 'Đánh dấu đổ chuông',
                      expand: true,
                      onPressed: _saving ? null : () => _update('RINGING'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (receiver) ...[
                    CoachingSecondaryButton(
                      label: 'Đánh dấu từ chối',
                      expand: true,
                      onPressed: _saving ? null : () => _update('REJECTED'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (receiver && _call.status == 'RINGING') ...[
                    CoachingSecondaryButton(
                      label: 'Đánh dấu bắt máy',
                      expand: true,
                      onPressed: _saving ? null : () => _update('ANSWERED'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  CoachingSecondaryButton(
                    label: 'Đánh dấu nhỡ',
                    expand: true,
                    onPressed: _saving ? null : () => _update('MISSED'),
                  ),
                  const SizedBox(height: 10),
                  CoachingSecondaryButton(
                    label: 'Đánh dấu lỗi kết nối',
                    expand: true,
                    onPressed: _saving
                        ? null
                        : () => _update(
                            'FAILED',
                            failureReason: 'Ứng dụng chưa tích hợp RTC',
                          ),
                  ),
                ],
                if (_call.status == 'ANSWERED')
                  CoachingPrimaryButton(
                    label: 'Đánh dấu kết thúc',
                    onPressed: _saving ? null : () => _update('ENDED'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallMetaRow extends StatelessWidget {
  const _CallMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(
              color: coachingWarmTextSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: coachingWarmTextPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ),
      ],
    );
  }
}
