import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/domain/call_log.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:provider/provider.dart';

AppBar _buildCallsAppBar(BuildContext context, String title) {
  final palette = MetaGymTheme.paletteOf(context);
  return AppBar(
    automaticallyImplyLeading: false,
    leadingWidth: 72,
    leading: Navigator.of(context).canPop()
        ? Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MetaGymCircleIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Quay lại',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          )
        : null,
    titleSpacing: Navigator.of(context).canPop() ? 8 : 16,
    title: Text(
      title,
      style: TextStyle(
        color: palette.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  );
}

InputDecoration _warmCallsInputDecoration(
  BuildContext context,
  String label,
) {
  final palette = MetaGymTheme.paletteOf(context);
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: palette.textSecondary),
    filled: true,
    fillColor: palette.metricPanelBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: palette.metricPanelBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: BorderSide(color: palette.metricPanelBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
      borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.4),
    ),
  );
}

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
      await MetaGymNavigation.pushOnce(
        context,
        MetaGymPageRoute<void>(
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
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: _buildCallsAppBar(context, 'Lịch sử cuộc gọi'),
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
                  backgroundColor: isLight
                      ? palette.surfaceSolid
                      : const Color(0xFF282320),
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, topInset, 16, 32),
                    children: [
                      MetaGymGlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: palette.reflection,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Đây chỉ là bản ghi thử API. Ứng dụng chưa tích hợp RTC, '
                                'nên không thể kết nối cuộc gọi thoại/video thật.',
                                style: TextStyle(
                                  color: palette.textWarmMuted,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isLight
                                ? palette.error.withValues(alpha: 0.10)
                                : const Color(0xFF24161A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isLight
                                  ? palette.error.withValues(alpha: 0.45)
                                  : const Color(0xFF642B32),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: palette.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: isLight
                                        ? palette.error
                                        : const Color(0xFFFFB2B6),
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.primaryText,
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: _calls.isEmpty ? _load : _loadMore,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_relationships.isEmpty)
                        MetaGymGlassCard(
                          padding: const EdgeInsets.all(16),
                          child: ListTile(
                            leading: Icon(
                              Icons.link_off_rounded,
                              color: palette.textWarmMuted,
                            ),
                            title: Text(
                              'Chưa có quan hệ hoạt động để tạo cuộc gọi.',
                              style: TextStyle(color: palette.textWarmMuted),
                            ),
                          ),
                        )
                      else
                        MetaGymGlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRelationship,
                                dropdownColor: isLight
                                    ? palette.surfaceSolid
                                    : const Color(0xFF2B2622),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                ),
                                decoration: _warmCallsInputDecoration(
                                  context,
                                  'Quan hệ',
                                ),
                                items: [
                                  for (final item in _relationships)
                                    DropdownMenuItem(
                                      value: item.relationshipId,
                                      child: Text(
                                        'Quan hệ ${item.relationshipId}',
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
                                dropdownColor: isLight
                                    ? palette.surfaceSolid
                                    : const Color(0xFF2B2622),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                ),
                                decoration: _warmCallsInputDecoration(
                                  context,
                                  'Loại cuộc gọi',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'VOICE',
                                    child: Text('Thoại'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'VIDEO',
                                    child: Text('Video'),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _callType = value ?? 'VOICE',
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: MetaGymTheme.brandOrange,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      MetaGymTheme.radiusInput,
                                    ),
                                  ),
                                ),
                                onPressed: _saving ? null : _create,
                                child: Text(
                                  _saving
                                      ? 'Đang tạo…'
                                      : 'Tạo bản ghi cuộc gọi',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_calls.isEmpty && _error == null)
                        MetaGymGlassCard(
                          padding: const EdgeInsets.all(16),
                          child: ListTile(
                            leading: Icon(
                              Icons.call_outlined,
                              color: palette.primaryText,
                            ),
                            title: Text(
                              'Chưa có cuộc gọi nào.',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      for (final call in _calls)
                        MetaGymGlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: palette.metricPanelBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: palette.metricPanelBorder,
                                ),
                              ),
                              child: Icon(
                                call.callType == 'VIDEO'
                                    ? Icons.videocam_outlined
                                    : Icons.call_outlined,
                                color: palette.primaryText,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              '${call.typeLabel} · ${call.statusLabel}',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              call.initiatedAt,
                              style: TextStyle(
                                color: palette.textWarmMuted,
                                fontSize: 12.5,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: palette.textWarmMuted,
                            ),
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
                          ),
                        ),
                      if (_hasMore)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: palette.primaryText,
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _loadingMore ? null : _loadMore,
                          child: Text(_loadingMore ? 'Đang tải…' : 'Tải thêm'),
                        ),
                    ],
                  ),
                ),
        ],
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

  Widget _warmActionOutlinedButton(
    BuildContext context, {
    required String label,
    required VoidCallback? onPressed,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          backgroundColor: isLight
              ? palette.surfaceSolid
              : const Color(0xA82B2622),
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(
            color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
            width: 1.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final receiver = _call.receiverId == widget.currentUserId;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: _buildCallsAppBar(context, 'Trạng thái cuộc gọi'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 32),
            children: [
              MetaGymGlassCard(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Chỉ hiển thị metadata. Chưa có RTC để kết nối âm thanh/video.',
                  style: TextStyle(
                    color: palette.textWarmMuted,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MetaGymGlassCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        _call.typeLabel,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _call.statusLabel,
                        style: TextStyle(color: palette.primaryText),
                      ),
                    ),
                    ListTile(
                      title: Text(
                        'Quan hệ',
                        style: TextStyle(color: palette.textPrimary),
                      ),
                      subtitle: Text(
                        _call.relationshipId,
                        style: TextStyle(color: palette.textWarmMuted),
                      ),
                    ),
                    ListTile(
                      title: Text(
                        'Thời điểm tạo',
                        style: TextStyle(color: palette.textPrimary),
                      ),
                      subtitle: Text(
                        _call.initiatedAt,
                        style: TextStyle(
                          color: palette.textWarmMuted,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                    if (_call.endedAt != null)
                      ListTile(
                        title: Text(
                          'Kết thúc',
                          style: TextStyle(color: palette.textPrimary),
                        ),
                        subtitle: Text(
                          _call.endedAt!,
                          style: TextStyle(
                            color: palette.textWarmMuted,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ),
                    if (_call.failureReason != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _call.failureReason!,
                            style: TextStyle(
                              color: isLight
                                  ? palette.error
                                  : const Color(0xFFFFB2B6),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLight
                        ? palette.error.withValues(alpha: 0.10)
                        : const Color(0xFF24161A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isLight
                          ? palette.error.withValues(alpha: 0.45)
                          : const Color(0xFF642B32),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: isLight ? palette.error : const Color(0xFFFFB2B6),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (_call.status == 'CREATED' || _call.status == 'RINGING') ...[
                if (_call.status == 'CREATED')
                  _warmActionOutlinedButton(
                    context,
                    label: 'Đánh dấu đổ chuông',
                    onPressed: _saving ? null : () => _update('RINGING'),
                  ),
                if (receiver)
                  _warmActionOutlinedButton(
                    context,
                    label: 'Đánh dấu từ chối',
                    onPressed: _saving ? null : () => _update('REJECTED'),
                  ),
                if (receiver && _call.status == 'RINGING')
                  _warmActionOutlinedButton(
                    context,
                    label: 'Đánh dấu bắt máy',
                    onPressed: _saving ? null : () => _update('ANSWERED'),
                  ),
                _warmActionOutlinedButton(
                  context,
                  label: 'Đánh dấu nhỡ',
                  onPressed: _saving ? null : () => _update('MISSED'),
                ),
                _warmActionOutlinedButton(
                  context,
                  label: 'Đánh dấu lỗi kết nối',
                  onPressed: _saving
                      ? null
                      : () => _update(
                          'FAILED',
                          failureReason: 'Ứng dụng chưa tích hợp RTC',
                        ),
                ),
              ],
              if (_call.status == 'ANSWERED')
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MetaGymTheme.brandOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        MetaGymTheme.radiusInput,
                      ),
                    ),
                  ),
                  onPressed: _saving ? null : () => _update('ENDED'),
                  child: const Text(
                    'Đánh dấu kết thúc',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
