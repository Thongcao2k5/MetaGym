import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/calls/domain/call_log.dart';
import 'package:meta_gym_app/features/calls/presentation/live_call_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/domain/conversation.dart';
import 'package:meta_gym_app/features/messaging/presentation/chat_detail_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';

enum _CallFilter { all, voice, video, missed }

/// Màn hình **5.3 Cuộc gọi 1:1** cho Coach (tương thích Dark & Daylight Light).
class CoachCallsView extends StatefulWidget {
  const CoachCallsView({
    required this.currentUserId,
    this.service,
    this.bottomPadding,
    this.useSolidGlassFallback = false,
    super.key,
  });

  final String currentUserId;
  final CallsService? service;
  final double? bottomPadding;
  final bool useSolidGlassFallback;

  @override
  State<CoachCallsView> createState() => _CoachCallsViewState();
}

class _CoachCallsViewState extends State<CoachCallsView> {
  CallsService? _service;
  List<CallLog> _calls = const [];
  List<Conversation> _relationships = const [];
  _CallFilter _filter = _CallFilter.all;
  bool _loading = true;
  bool _busyStartingCall = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextService =
        widget.service ?? optionalProvider<CallsService>(context);
    if (!identical(_service, nextService)) {
      _service = nextService;
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant CoachCallsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.service != null && !identical(widget.service, _service)) {
      _service = widget.service;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        if (_calls.isEmpty) _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        service.getCalls(1),
        service.getActiveRelationships().catchError(
          (_) => const <Conversation>[],
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _calls = results[0] as List<CallLog>;
        _relationships = results[1] as List<Conversation>;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được lịch sử cuộc gọi.';
      });
    }
  }

  List<CallLog> get _filteredCalls {
    return _calls.where((call) {
      return switch (_filter) {
        _CallFilter.all => true,
        _CallFilter.voice => call.callType != 'VIDEO',
        _CallFilter.video => call.callType == 'VIDEO',
        _CallFilter.missed =>
          call.status == 'MISSED' || call.status == 'REJECTED',
      };
    }).toList();
  }

  int get _missedCount => _calls
      .where((c) => c.status == 'MISSED' || c.status == 'REJECTED')
      .length;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String _peerNameOfCall(CallLog call) {
    return call.peerNameFor(widget.currentUserId) ??
        (call.callerId == widget.currentUserId ? 'Hội viên' : 'Hội viên');
  }

  Future<void> _startCall({
    required String relationshipId,
    required String callType,
    required String peerName,
  }) async {
    final service = _service;
    if (_busyStartingCall || service == null) return;
    if (service is! CallsApi) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuộc gọi trực tiếp khả dụng khi kết nối máy chủ.'),
        ),
      );
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    if (LiveCallPage.isOpen(navigator)) return;
    setState(() => _busyStartingCall = true);
    try {
      final created = await service.createLiveCall(relationshipId, callType);
      if (!mounted) return;
      await LiveCallPage.show(
        navigator,
        api: service,
        call: created,
        currentUserId: widget.currentUserId,
        peerName: peerName,
      );
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể khởi tạo cuộc gọi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyStartingCall = false);
    }
  }

  Future<void> _openConversationForRelationship(
    String relationshipId,
    String peerName,
  ) async {
    Conversation? match;
    for (final c in _relationships) {
      if (c.relationshipId == relationshipId || c.id == relationshipId) {
        match = c;
        break;
      }
    }
    final messagingService =
        optionalProvider<MessagingService>(context) ??
        (() {
          final client = optionalProvider<ApiClient>(context);
          return client != null ? MessagingApi(client) : null;
        })();

    if (match == null && messagingService != null) {
      try {
        final list = await messagingService.getConversations(1);
        for (final c in list) {
          if (c.relationshipId == relationshipId || c.id == relationshipId) {
            match = c;
            break;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chưa tìm thấy phòng chat với $peerName.')),
      );
      return;
    }

    await MetaGymNavigation.pushOnce<void>(
      context,
      MetaGymPageRoute(
        builder: (_) => ConversationDetailPage(
          conversation: match!,
          service: messagingService,
          currentUserId: widget.currentUserId,
          picker: DeviceProgressPhotoPicker(),
          coachMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final media = MediaQuery.paddingOf(context);
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    final canPop =
        ModalRoute.of(context)?.canPop ?? Navigator.of(context).canPop();
    final filtered = _filteredCalls;

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
              child: RefreshIndicator(
                color: MetaGymTheme.primary,
                backgroundColor: colors.overlayGlass,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    8,
                    gutter,
                    widget.bottomPadding ?? (media.bottom + 36),
                  ),
                  children: [
                    MetaGymBrandHeader(
                      eyebrow: 'META GYM · CALLS',
                      title: 'Cuộc gọi 1:1',
                      subtitle: 'Thoại & video trực tiếp cùng học viên',
                      leading: canPop
                          ? MetaGymCircleIconButton(
                              svgAsset: MetaGymIcons.commonBack,
                              icon: Icons.arrow_back_ios_new_rounded,
                              tooltip: 'Quay lại',
                              onTap: () => Navigator.of(context).maybePop(),
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _buildOverviewHeroCard(colors),
                    const SizedBox(height: 14),
                    _buildFilterDock(colors, isLight),
                    const SizedBox(height: 12),
                    if (_relationships.isNotEmpty) ...[
                      _buildSectionTitle(
                        colors,
                        icon: Icons.bolt_rounded,
                        title: 'Gọi nhanh học viên (${_relationships.length})',
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _relationships.length; i++)
                        _buildQuickCallStudentCard(
                          colors,
                          conversation: _relationships[i],
                          paletteIndex: i + 1,
                        ),
                      const SizedBox(height: 10),
                    ],
                    _buildSectionTitle(
                      colors,
                      icon: Icons.history_rounded,
                      title: 'Lịch sử cuộc gọi (${filtered.length})',
                    ),
                    const SizedBox(height: 10),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.primary,
                          ),
                        ),
                      )
                    else if (_error != null)
                      MetaGymGlassCard(
                        solid: widget.useSolidGlassFallback,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _error!,
                              style: TextStyle(
                                color: colors.error,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            CoachingSecondaryButton(
                              label: 'Thử lại',
                              onPressed: _load,
                              expand: true,
                            ),
                          ],
                        ),
                      )
                    else if (filtered.isEmpty)
                      MetaGymGlassCard(
                        solid: widget.useSolidGlassFallback,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const MetaGymIcon(
                              MetaGymIcons.emptyCalls,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _calls.isEmpty
                                  ? 'Chưa có lịch sử cuộc gọi 1:1.'
                                  : 'Không có cuộc gọi phù hợp bộ lọc.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nhấn nút Thoại hoặc Video trên hồ sơ học viên để kết nối trực tiếp.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (var i = 0; i < filtered.length; i++)
                        _buildCallHistoryCard(
                          colors,
                          call: filtered[i],
                          paletteIndex: i + 1,
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewHeroCard(MetaGymColors colors) {
    return MetaGymHeroGlassCard(
      useSolidFallback: widget.useSolidGlassFallback,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TỔNG QUAN LIÊN LẠC',
                      style: TextStyle(
                        color: colors.primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kênh 1:1 học viên',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const CoachingPill(
                label: 'SẴN SÀNG',
                tone: CoachingPillTone.green,
                icon: Icons.circle,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: MetaGymMetricPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cuộc gọi tuần này',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_calls.length}',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 22,
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
                        'Cuộc gọi nhỡ',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_missedCount',
                        style: TextStyle(
                          color: _missedCount > 0
                              ? colors.error
                              : colors.textPrimary,
                          fontSize: 22,
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
        ],
      ),
    );
  }

  Widget _buildQuickCallStudentCard(
    MetaGymColors colors, {
    required Conversation conversation,
    required int paletteIndex,
  }) {
    final name = conversation.displayNameFor(widget.currentUserId);
    final relId = conversation.relationshipId ?? conversation.id;
    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CoachingAvatar(
            fullName: name,
            size: 42,
            round: true,
            paletteIndex: paletteIndex,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Học viên PT 1:1 · Kết nối trực tiếp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MetaGymCircleIconButton(
            svgAsset: MetaGymIcons.callAudioBadge,
            icon: Icons.call_outlined,
            tooltip: 'Gọi thoại $name',
            onTap: _busyStartingCall
                ? null
                : () => _startCall(
                    relationshipId: relId,
                    callType: 'VOICE',
                    peerName: name,
                  ),
          ),
          const SizedBox(width: 6),
          MetaGymCircleIconButton(
            svgAsset: MetaGymIcons.callVideoBadge,
            icon: Icons.videocam_outlined,
            tooltip: 'Gọi video $name',
            onTap: _busyStartingCall
                ? null
                : () => _startCall(
                    relationshipId: relId,
                    callType: 'VIDEO',
                    peerName: name,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDock(MetaGymColors colors, bool isLight) {
    final filters = [
      (_CallFilter.all, 'Tất cả'),
      (_CallFilter.voice, 'Thoại'),
      (_CallFilter.video, 'Video'),
      (_CallFilter.missed, 'Gọi nhỡ'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final item in filters)
          _CallFilterChip(
            label: item.$2,
            active: _filter == item.$1,
            colors: colors,
            isLight: isLight,
            onTap: () => setState(() => _filter = item.$1),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(
    MetaGymColors colors, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: colors.reflection),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallHistoryCard(
    MetaGymColors colors, {
    required CallLog call,
    required int paletteIndex,
  }) {
    final peerName = _peerNameOfCall(call);
    final isVideo = call.callType == 'VIDEO';
    final isOutgoing = call.callerId == widget.currentUserId;
    final tone = switch (call.status) {
      'ENDED' || 'ANSWERED' => CoachingPillTone.green,
      'MISSED' || 'REJECTED' || 'FAILED' => CoachingPillTone.coral,
      'RINGING' || 'CREATED' => CoachingPillTone.amber,
      _ => CoachingPillTone.neutral,
    };
    final durationLabel = call.durationSeconds > 0
        ? _formatDuration(call.durationSeconds)
        : null;

    return MetaGymGlassCard(
      solid: widget.useSolidGlassFallback,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachingAvatar(
                fullName: peerName,
                size: 44,
                round: true,
                paletteIndex: paletteIndex,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CoachingPill(label: call.statusLabel, tone: tone),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isVideo
                              ? Icons.videocam_outlined
                              : (isOutgoing
                                    ? Icons.call_made_rounded
                                    : Icons.call_received_rounded),
                          size: 14,
                          color: isVideo
                              ? colors.reflection
                              : colors.primaryText,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            [
                              isVideo ? 'Cuộc gọi video' : 'Cuộc gọi thoại',
                              isOutgoing ? 'Gọi đi' : 'Gọi đến',
                              ?durationLabel,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12.5,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: colors.metricPanelBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.metricPanelBorder),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    formatVietnamTime(call.initiatedAt),
                    style: TextStyle(
                      color: colors.textWarmMuted,
                      fontSize: 12,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ),
                if (call.failureReason != null &&
                    call.failureReason!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      call.failureReason!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _openConversationForRelationship(
                      call.relationshipId,
                      peerName,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Mở tin nhắn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _busyStartingCall
                        ? null
                        : () => _startCall(
                            relationshipId: call.relationshipId,
                            callType: isVideo ? 'VIDEO' : 'VOICE',
                            peerName: peerName,
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.primary,
                      foregroundColor: MetaGymTheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: Icon(
                      isVideo ? Icons.videocam_outlined : Icons.call_outlined,
                      size: 17,
                    ),
                    label: Text(
                      isVideo ? 'Gọi lại video' : 'Gọi lại thoại',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallFilterChip extends StatelessWidget {
  const _CallFilterChip({
    required this.label,
    required this.active,
    required this.colors,
    required this.isLight,
    required this.onTap,
  });

  final String label;
  final bool active;
  final MetaGymColors colors;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IntrinsicWidth(
              child: Center(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: active
                        ? colors.chipActiveBg
                        : (isLight ? colors.surface : colors.liquidGlass),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? MetaGymTheme.primary
                          : (isLight
                                ? colors.border
                                : colors.liquidGlassBorder),
                      width: active ? 1.2 : 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: active
                          ? (isLight ? colors.chipActiveText : Colors.white)
                          : colors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
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
