import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/member_coaching_service.dart';
import 'package:meta_gym_app/features/coaching/domain/member_coaching_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/termination_reason_dialog.dart';
import 'package:provider/provider.dart';

class MemberCoachingPage extends StatefulWidget {
  const MemberCoachingPage({this.service, super.key});

  final MemberCoachingService? service;

  @override
  State<MemberCoachingPage> createState() => _MemberCoachingPageState();
}

class _MemberCoachingPageState extends State<MemberCoachingPage> {
  MemberCoachingService? _service;
  List<MemberCoachRequest> _requests = const [];
  List<MemberCoachRelationship> _history = const [];
  Map<String, String> _coachNames = const {};
  MemberCoachRelationship? _current;
  String? _error;
  String? _actionError;
  bool _loading = true;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? MemberCoachingApi(context.read<ApiClient>());
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
      final requests = await _service!.getRequests();
      final current = await _service!.getCurrentRelationship();
      final history = await _service!.getRelationshipHistory();
      Map<String, String> coachNames;
      try {
        coachNames = await _service!.getCoachNames();
      } catch (_) {
        coachNames = const {};
      }
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _current = current;
        _history = history;
        _coachNames = coachNames;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được quan hệ Coach.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _coachLabel(String coachId) =>
      _coachNames[coachId] ?? 'Coach: $coachId';

  Future<void> _cancel(MemberCoachRequest request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await _service!.cancelRequest(request.id);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) setState(() => _actionError = 'Không hủy được yêu cầu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _terminate() async {
    if (_busy || _current == null) return;
    final relationshipId = _current!.id;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const TerminationReasonDialog(),
    );
    if (reason == null || !mounted || _current?.id != relationshipId) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await _service!.terminateRelationship(relationshipId, reason);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _actionError = 'Không kết thúc được quan hệ.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((item) => item.status == 'PENDING');
    final previousRequests = _requests.where(
      (item) => item.status != 'PENDING',
    );
    final previousRelationships = _history.where(
      (item) => item.id != _current?.id,
    );

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: [
          if (_current != null && context.read<ApiClient?>() != null)
            IconButton(tooltip: 'Xem gói Coach', icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () {
                final coachId = _current!.coachId;
                Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => CoachOffersPage(coachId: coachId)));
              }),
        ],
        title: const Text(
          'Coach của tôi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child:
                _loading &&
                    _requests.isEmpty &&
                    _history.isEmpty &&
                    _current == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      children: [
                        if (_error != null) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0x33FF453A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0x66FF453A),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFFF6961),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFFFF857D),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _load,
                            style: TextButton.styleFrom(
                              foregroundColor: MetaGymTheme.brandOrange,
                            ),
                            child: const Text('Thử lại'),
                          ),
                        ] else ...[
                          if (_actionError != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF453A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0x66FF453A),
                                ),
                              ),
                              child: Text(
                                _actionError!,
                                style: const TextStyle(
                                  color: Color(0xFFFF857D),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, top: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: MetaGymTheme.brandOrange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Yêu cầu đang chờ',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (pending.isEmpty)
                            MetaGymGlassCard(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'Không có yêu cầu đang chờ.',
                                style: TextStyle(color: Colors.white60),
                              ),
                            )
                          else
                            for (final request in pending)
                              MetaGymGlassCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0x26FF9F0A),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.person_pin,
                                        color: Color(0xFFFF9F0A),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _coachLabel(request.coachId),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            request.message ??
                                                request.statusLabel,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFFF6961,
                                        ),
                                      ),
                                      onPressed: _busy
                                          ? null
                                          : () => _cancel(request),
                                      child: const Text('Hủy yêu cầu'),
                                    ),
                                  ],
                                ),
                              ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user,
                                  color: Color(0xFF34C759),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Coach hiện tại',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (_current == null)
                            MetaGymGlassCard(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'Chưa có Coach hiện tại.',
                                style: TextStyle(color: Colors.white60),
                              ),
                            )
                          else
                            MetaGymGlassCard(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0x3334C759),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.fitness_center,
                                      color: Color(0xFF34C759),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _coachLabel(_current!.coachId),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _current!.statusLabel,
                                          style: const TextStyle(
                                            color: Color(0xFF34C759),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF6961),
                                    ),
                                    onPressed: _busy ? null : _terminate,
                                    child: const Text('Kết thúc quan hệ'),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Lịch sử yêu cầu',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          if (previousRequests.isEmpty)
                            MetaGymGlassCard(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'Chưa có lịch sử yêu cầu.',
                                style: TextStyle(color: Colors.white60),
                              ),
                            )
                          else
                            for (final request in previousRequests)
                              MetaGymGlassCard(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.history,
                                      color: Colors.white38,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _coachLabel(request.coachId),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            request.statusLabel,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Lịch sử quan hệ',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          if (previousRelationships.isEmpty)
                            MetaGymGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: const Text(
                                'Chưa có lịch sử quan hệ.',
                                style: TextStyle(color: Colors.white60),
                              ),
                            )
                          else
                            for (final item in previousRelationships)
                              MetaGymGlassCard(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.badge_outlined,
                                      color: Colors.white38,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _coachLabel(item.coachId),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.statusLabel,
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
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
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
