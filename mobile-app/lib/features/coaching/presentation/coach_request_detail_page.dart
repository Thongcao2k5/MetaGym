import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_requests_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_request_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';

class CoachRequestDetailPage extends StatefulWidget {
  const CoachRequestDetailPage({
    required this.requestId,
    required this.service,
    super.key,
  });

  final String requestId;
  final CoachRequestsService service;

  @override
  State<CoachRequestDetailPage> createState() => _CoachRequestDetailPageState();
}

class _CoachRequestDetailPageState extends State<CoachRequestDetailPage> {
  final _reason = TextEditingController();
  CoachIncomingRequest? _request;
  String? _loadError;
  String? _decisionError;
  bool _reasonRequired = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _request = null;
      _loadError = null;
    });
    try {
      final request = await widget.service.getRequest(widget.requestId);
      if (mounted) setState(() => _request = request);
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Không tải được chi tiết yêu cầu.');
      }
    }
  }

  Future<void> _decide(String decision) async {
    if (_busy || _request?.status != 'PENDING') return;
    final reason = _reason.text.trim();
    if (decision == 'REJECTED' && reason.isEmpty) {
      setState(() => _reasonRequired = true);
      return;
    }
    setState(() {
      _busy = true;
      _decisionError = null;
      _reasonRequired = false;
    });
    try {
      await widget.service.decide(
        widget.requestId,
        decision,
        reason: decision == 'REJECTED' ? reason : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _decisionError = error.message);
    } catch (_) {
      if (mounted) setState(() => _decisionError = 'Không xử lý được yêu cầu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final request = _request;

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leadingWidth: canPop ? 68 : null,
        leading: canPop
            ? Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(
                  child: Tooltip(
                    message: 'Back',
                    child: MetaGymCircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Quay lại',
                      onTap: _busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              )
            : null,
        title: const Text(
          'Chi tiết yêu cầu',
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
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: MetaGymTheme.textPrimary),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: request == null && _loadError == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: MetaGymTheme.cardSurface,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        if (_loadError != null) ...[
                          CoachingErrorBanner(message: _loadError!),
                          CoachingSecondaryButton(
                            label: 'Thử lại',
                            expand: true,
                            onPressed: _load,
                          ),
                        ],
                        if (request != null) ...[
                          _RequestHeroCard(request: request),
                          if (request.message?.isNotEmpty == true ||
                              request.rejectionReason?.isNotEmpty == true ||
                              request.decidedAt != null)
                            _RequestNotesCard(request: request),
                          if (request.status == 'PENDING')
                            CoachingGraphiteCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Phản hồi yêu cầu',
                                    style: TextStyle(
                                      color: MetaGymTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Chấp nhận để bắt đầu phụ trách học viên, hoặc nhập lý do rõ ràng nếu cần từ chối.',
                                    style: TextStyle(
                                      color: MetaGymTheme.textSecondary,
                                      fontSize: 13,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    key: const Key('rejection-reason'),
                                    controller: _reason,
                                    enabled: !_busy,
                                    maxLength: 1000,
                                    maxLines: 3,
                                    style: const TextStyle(
                                      color: MetaGymTheme.textPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Lý do từ chối',
                                      labelStyle: const TextStyle(
                                        color: MetaGymTheme.textSecondary,
                                      ),
                                      hintText: 'Ví dụ: Lịch huấn luyện tuần này đã kín',
                                      hintStyle: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 13,
                                      ),
                                      counterStyle: const TextStyle(
                                        color: MetaGymTheme.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                      filled: true,
                                      fillColor: MetaGymTheme.elevatedSurface,
                                      errorText: _reasonRequired
                                          ? 'Vui lòng nhập lý do.'
                                          : null,
                                      errorStyle: const TextStyle(
                                        color: MetaGymTheme.dangerCoral,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          MetaGymTheme.radiusInput,
                                        ),
                                        borderSide: const BorderSide(
                                          color: MetaGymTheme.darkBorderStrong,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          MetaGymTheme.radiusInput,
                                        ),
                                        borderSide: const BorderSide(
                                          color: MetaGymTheme.darkBorderStrong,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          MetaGymTheme.radiusInput,
                                        ),
                                        borderSide: const BorderSide(
                                          color: MetaGymTheme.focusBlue,
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          MetaGymTheme.radiusInput,
                                        ),
                                        borderSide: const BorderSide(
                                          color: MetaGymTheme.dangerCoral,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_decisionError != null) ...[
                                    const SizedBox(height: 10),
                                    CoachingErrorBanner(
                                      message: _decisionError!,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CoachingSecondaryButton(
                                          label: 'Từ chối',
                                          expand: true,
                                          onPressed: _busy
                                              ? null
                                              : () => _decide('REJECTED'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: CoachingPrimaryButton(
                                          label: 'Chấp nhận',
                                          loading: _busy,
                                          onPressed: _busy
                                              ? null
                                              : () => _decide('ACCEPTED'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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

class _RequestHeroCard extends StatelessWidget {
  const _RequestHeroCard({required this.request});

  final CoachIncomingRequest request;

  @override
  Widget build(BuildContext context) {
    final tone = switch (request.status) {
      'PENDING' => CoachingPillTone.amber,
      'ACCEPTED' => CoachingPillTone.green,
      'REJECTED' => CoachingPillTone.coral,
      _ => CoachingPillTone.neutral,
    };

    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CoachingAvatar(fullName: request.memberId, size: 54, round: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hội viên ${request.memberId}',
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    CoachingPill(label: request.statusLabel, tone: tone),
                    if (request.requestedAt != null)
                      Text(
                        'Gửi lúc ${formatVietnamTime(request.requestedAt)}',
                        style: const TextStyle(
                          color: Color(0xFFBEC3CB),
                          fontSize: 12,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestNotesCard extends StatelessWidget {
  const _RequestNotesCard({required this.request});

  final CoachIncomingRequest request;

  @override
  Widget build(BuildContext context) {
    final hasMessage = request.message?.isNotEmpty == true;
    final hasRejection = request.rejectionReason?.isNotEmpty == true;

    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin yêu cầu',
            style: TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasMessage) ...[
            const SizedBox(height: 10),
            Text(
              'Lời nhắn: ${request.message}',
              style: const TextStyle(
                color: Color(0xFFE3E7EE),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (hasRejection) ...[
            if (hasMessage)
              const Divider(color: Color(0x1FD4E4FF), height: 20)
            else
              const SizedBox(height: 10),
            Text(
              'Lý do từ chối: ${request.rejectionReason}',
              style: const TextStyle(
                color: Color(0xFFFFB2B6),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (request.decidedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Thời gian xử lý: ${formatVietnamTime(request.decidedAt)}',
              style: const TextStyle(
                color: MetaGymTheme.textSecondary,
                fontSize: 12.5,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
