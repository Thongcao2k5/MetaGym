import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_health_declaration_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:provider/provider.dart';

class CoachOffersPage extends StatefulWidget {
  const CoachOffersPage({
    required this.coachId,
    this.coachView = false,
    super.key,
  });

  final String coachId;
  final bool coachView;

  @override
  State<CoachOffersPage> createState() => _CoachOffersPageState();
}

class _CoachOffersPageState extends State<CoachOffersPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  final _keys = <String, String>{};
  List<CoachRecord> _offers = [];
  CoachRecord? _coach;
  CoachRecord? _hold;
  CoachRecord? _relationship;
  bool? _hasActiveGym;
  bool _hasQueuedPackage = false;
  bool _healthDeclared = false;
  int _selectedOfferIndex = 0;
  String? _error;
  bool _busy = false;
  bool _loaded = false;

  bool get _isCoachView {
    if (widget.coachView) return true;
    final user = optionalProvider<SessionController>(context)?.user;
    return user?.role == UserRole.coach && user?.id == widget.coachId;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được dữ liệu. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<T?> _optional<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() => _run(() async {
    final isCoachView = _isCoachView;
    final offersFuture = _api.list('/coach-packages');
    final coachFuture = _optional(() => _api.get('/coaches/${widget.coachId}'));
    if (isCoachView) {
      final offers = await offersFuture;
      final coach = await coachFuture;
      if (!mounted) return;
      setState(() {
        _offers = offers;
        if (_selectedOfferIndex >= offers.length) _selectedOfferIndex = 0;
        _coach = coach ?? _coach;
        _loaded = true;
      });
      return;
    }

    final apiClient = context.read<ApiClient>();
    final holdsFuture = _api.list('/coach-payment-holds');
    final userFuture = _optional(() => _api.get('/users/me'));
    final membershipsFuture = _optional(() => _api.list('/memberships/me'));
    final relationshipFuture = _optional(
      () => apiClient.get<CoachRecord?>(
        '/relationships/me',
        decode: (data) =>
            data == null ? null : Map<String, dynamic>.from(data as Map),
      ),
    );
    final entitlementsFuture = _optional(
      () => _api.list('/coach-entitlements'),
    );

    final offers = await offersFuture;
    final holds = await holdsFuture;
    final coach = await coachFuture;
    final user = await userFuture;
    final memberships = await membershipsFuture;
    final relationship = await relationshipFuture;
    final entitlements = await entitlementsFuture;

    final current = _hold;
    final refreshed = current == null
        ? holds.where((row) => row['coachId'] == widget.coachId).firstOrNull
        : await _api.get('/coach-payment-holds/${current['id']}');
    if (refreshed != null && refreshed['status'] != 'HELD') {
      _keys.remove(refreshed['planCode']);
    }

    final profile = user?['profile'] as Map?;
    final hasActiveGym = memberships?.any((item) => item['status'] == 'ACTIVE');
    final hasQueued =
        entitlements?.any((item) => item['status'] == 'QUEUED') ?? false;

    if (!mounted) return;
    setState(() {
      _offers = offers;
      if (_selectedOfferIndex >= offers.length) _selectedOfferIndex = 0;
      _coach = coach ?? _coach;
      _hold = refreshed;
      _relationship = relationship?.data;
      _hasActiveGym = hasActiveGym;
      _hasQueuedPackage = hasQueued;
      _healthDeclared = profile?['healthDeclarationCompletedAt'] != null;
      _loaded = true;
    });
  });

  Future<bool> _openHealthDeclaration({bool checkoutFlow = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemberHealthDeclarationPage(
          submitLabel: checkoutFlow
              ? 'Lưu và tiếp tục thanh toán'
              : 'Lưu khai báo',
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() => _healthDeclared = true);
      return true;
    }
    return false;
  }

  Future<void> _reserve(String code) => _run(() async {
    final user = await _optional(() => _api.get('/users/me'));
    final profile = user?['profile'] as Map?;
    final needsDeclaration =
        user != null && profile?['healthDeclarationCompletedAt'] == null;
    if (needsDeclaration) {
      if (!mounted) return;
      final saved = await _openHealthDeclaration(checkoutFlow: true);
      if (!saved || !mounted) return;
    }
    if (_hold != null && _hold!['status'] != 'HELD') {
      _keys.remove(code);
    }
    Future<CoachRecord> createHold() => _api.post(
      '/coach-payment-holds',
      body: {'coachId': widget.coachId, 'planCode': code},
      key: _keys.putIfAbsent(code, newClientMessageId),
    );
    CoachRecord hold;
    try {
      hold = await createHold();
    } on ApiException catch (error) {
      if (error.code != 'HEALTH_DECLARATION_REQUIRED' || !mounted) rethrow;
      final saved = await _openHealthDeclaration(checkoutFlow: true);
      if (!saved || !mounted) return;
      _keys.remove(code);
      hold = await createHold();
    }
    if (hold['status'] != 'HELD') {
      _keys.remove(code);
    }
    if (mounted) setState(() => _hold = hold);
  });

  Future<void> _confirmMockPayment() => _run(() async {
    final hold = _hold;
    if (hold == null) return;
    final result = await _api.post(
      '/coach-payment-holds/${hold['id']}/mock-confirmations',
    );
    _keys.remove(hold['planCode']);
    if (!mounted) return;
    setState(() {
      _hold = Map<String, dynamic>.from(result['hold'] as Map? ?? hold);
    });
    showCoachingSnackBar(context, 'Thanh toán mô phỏng thành công');
    final isRootRoute = ModalRoute.of(context)?.isFirst ?? false;
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(builder: (_) => const MemberCoachingPage()),
      (route) => !isRootRoute && route.isFirst,
    );
  });

  Future<void> _editHealthDeclaration() => _openHealthDeclaration();

  Future<void> _readHold({bool cancel = false}) => _run(() async {
    final path = '/coach-payment-holds/${_hold!['id']}';
    final result = cancel
        ? await _api.post('$path/cancel')
        : await _api.get(path);
    if (result['status'] != 'HELD') {
      _keys.remove(result['planCode'] ?? _hold?['planCode']);
    }
    if (mounted) {
      setState(() => _hold = result);
      if (cancel) {
        showCoachingSnackBar(context, 'Đã hủy giữ suất');
      }
    }
  });

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final isCoachView = _isCoachView;
    final hold = _hold;
    final held = hold?['status'] == 'HELD';
    final coachName =
        (_coach?['fullName'] as String?) ??
        (isCoachView ? 'Hồ sơ Coach của bạn' : 'Coach phụ trách');
    final coachAvatar = _coach?['avatarUrl'] as String?;
    final usedSlots = (_coach?['usedSlots'] as num?)?.toInt();
    final memberLimit = (_coach?['memberLimit'] as num?)?.toInt();
    final availableSlots = (_coach?['availableSlots'] as num?)?.toInt();
    final relCoachId = _relationship?['coachId'] as String?;
    final assignedElsewhere =
        relCoachId != null && relCoachId != widget.coachId;
    final assignedHere = relCoachId != null && relCoachId == widget.coachId;
    final noGym = _hasActiveGym == false;
    final full = availableSlots != null && availableSlots <= 0 && !assignedHere;
    final selectedOffer = _offers.isNotEmpty
        ? _offers[_selectedOfferIndex]
        : null;
    final canCheckout =
        !_busy &&
        !held &&
        !noGym &&
        !full &&
        !assignedElsewhere &&
        !(assignedHere && _hasQueuedPackage) &&
        selectedOffer != null;

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
        title: Text(
          isCoachView ? 'Gói PT & Bảng giá' : 'Chọn gói Coach',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
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
            child: !_loaded && _busy && _offers.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: MetaGymTheme.cardSurface,
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_busy)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: LinearProgressIndicator(
                                color: MetaGymTheme.brandOrange,
                                backgroundColor: MetaGymTheme.cardSurface,
                              ),
                            ),
                          if (_error != null) ...[
                            CoachingErrorBanner(message: _error!),
                            if (!_loaded && _offers.isEmpty) ...[
                              CoachingSecondaryButton(
                                label: 'Thử lại',
                                expand: true,
                                onPressed: _busy ? null : _load,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                          if (isCoachView) ...[
                            _CoachPackagesHeroCard(
                              coachName: coachName,
                              coachAvatar: coachAvatar,
                              usedSlots: usedSlots,
                              memberLimit: memberLimit,
                              availableSlots: availableSlots,
                              offerCount: _offers.length,
                            ),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10, top: 4),
                              child: Text(
                                'Bảng giá gói PT đang mở bán',
                                style: TextStyle(
                                  color: MetaGymTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_loaded && _offers.isEmpty)
                              const CoachingGraphiteCard(
                                child: Text(
                                  'Chưa có gói Coach đang mở bán.',
                                  style: TextStyle(
                                    color: MetaGymTheme.textSecondary,
                                  ),
                                ),
                              ),
                            for (final offer in _offers)
                              _OfferPackageCard(
                                offer: offer,
                                selected: false,
                                enabled: false,
                                readOnlyMode: true,
                                onTap: () {},
                              ),
                            CoachingGraphiteCard(
                              margin: const EdgeInsets.only(top: 2, bottom: 12),
                              padding: const EdgeInsets.all(14),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: MetaGymTheme.reflectionBlue,
                                    size: 19,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Bảng giá và quyền lợi gói PT được đồng bộ theo cấu hình của phòng tập. Mỗi buổi huấn luyện có thời lượng 90 phút.',
                                      style: TextStyle(
                                        color: Color(0xFFD2D5DB),
                                        fontSize: 12.5,
                                        height: 1.48,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            CoachingGraphiteCard(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CoachingAvatar(
                                    fullName: coachName,
                                    avatarUrl: coachAvatar,
                                    size: 44,
                                    round: true,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          coachName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: MetaGymTheme.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Huấn luyện cá nhân · mỗi buổi 90 phút',
                                          style: TextStyle(
                                            color: MetaGymTheme.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (noGym)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                borderColor: const Color(0xFF815423),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Gói Gym chưa hiệu lực',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Bạn vẫn có thể xem hồ sơ và giá gói Coach. Để mua, hãy có gói Gym còn hiệu lực.',
                                      style: TextStyle(
                                        color: Color(0xFFC8CBD2),
                                        fontSize: 12.5,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    CoachingSecondaryButton(
                                      label: 'Xem gói Gym',
                                      onPressed: () => Navigator.of(context)
                                          .push<void>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const MembershipPage(),
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            else if (full)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                borderColor: const Color(0xFF815423),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Coach đã hết suất',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Bạn có thể nhắn Coach hoặc quay lại Khám phá để chọn người khác.',
                                      style: TextStyle(
                                        color: Color(0xFFC8CBD2),
                                        fontSize: 12.5,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    CoachingSecondaryButton(
                                      label: 'Quay lại hồ sơ Coach',
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                    ),
                                  ],
                                ),
                              )
                            else if (assignedElsewhere)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                borderColor: const Color(0xFF815423),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bạn đã có Coach khác',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Mỗi hội viên chỉ có một Coach hiện hành. Xem thông tin Coach của bạn trước khi chọn người mới.',
                                      style: TextStyle(
                                        color: Color(0xFFC8CBD2),
                                        fontSize: 12.5,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    CoachingSecondaryButton(
                                      label: 'Coach của tôi',
                                      onPressed: () => Navigator.of(context)
                                          .push<void>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const MemberCoachingPage(),
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            else if (assignedHere)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Gói nối tiếp',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _hasQueuedPackage
                                          ? 'Bạn đã có một gói Coach đang chờ kích hoạt sau gói hiện tại.'
                                          : 'Bạn đang tập cùng Coach này. Có thể mua một gói chờ kích hoạt sau gói hiện tại.',
                                      style: const TextStyle(
                                        color: Color(0xFFC8CBD2),
                                        fontSize: 12.5,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_healthDeclared)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: MetaGymTheme.success,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'Đã khai báo thể trạng',
                                        style: TextStyle(
                                          color: Color(0xFFD9DDE3),
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : _editHealthDeclaration,
                                      style: TextButton.styleFrom(
                                        foregroundColor: MetaGymTheme.primary,
                                        minimumSize: const Size(48, 48),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                      ),
                                      child: const Text('Xem / sửa'),
                                    ),
                                  ],
                                ),
                              ),
                            if (hold != null) ...[
                              MetaGymHeroGlassCard(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CoachingPill(
                                      label: switch (hold['status']) {
                                        'HELD' =>
                                          'Đang giữ suất · Chờ thanh toán',
                                        'CONSUMED' => 'Đã kích hoạt gói hoặc đưa vào hàng chờ',
                                        'EXPIRED' => 'Đã hết hạn giữ suất',
                                        'CANCELLED' => 'Đã hủy giữ suất',
                                        _ => 'Thanh toán không thành công',
                                      },
                                      tone: held
                                          ? CoachingPillTone.amber
                                          : (hold['status'] == 'CONSUMED'
                                                ? CoachingPillTone.green
                                                : CoachingPillTone.neutral),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${hold['planName']} · ${formatVnd((hold['amount'] as num?) ?? 0)}',
                                      style: const TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (held) ...[
                                      Text(
                                        'Suất được giữ tối đa 15 phút (hết hạn ${formatVietnamTime(hold['expiresAt'] as String?)})',
                                        style: const TextStyle(
                                          color: Color(0xFFE0D9D0),
                                          fontSize: 12.5,
                                          height: 1.45,
                                          fontFeatures:
                                              MetaGymTheme.tabularFigures,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      CoachingPrimaryButton(
                                        label: 'Hoàn tất thanh toán',
                                        onPressed: _busy
                                            ? null
                                            : _confirmMockPayment,
                                      ),
                                      const SizedBox(height: 10),
                                      CoachingSecondaryButton(
                                        label: 'Hủy giữ suất',
                                        expand: true,
                                        onPressed: _busy
                                            ? null
                                            : () => _readHold(cancel: true),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 6),
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => setState(() {
                                                _keys.clear();
                                                _hold = null;
                                              }),
                                        style: TextButton.styleFrom(
                                          foregroundColor: MetaGymTheme.primary,
                                          minimumSize: const Size(48, 48),
                                        ),
                                        child: const Text('Chọn gói khác'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10, top: 4),
                              child: Text(
                                'Gói huấn luyện',
                                style: TextStyle(
                                  color: MetaGymTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_loaded && _offers.isEmpty)
                              const CoachingGraphiteCard(
                                child: Text(
                                  'Chưa có gói Coach đang mở bán.',
                                  style: TextStyle(
                                    color: MetaGymTheme.textSecondary,
                                  ),
                                ),
                              ),
                            for (var i = 0; i < _offers.length; i++)
                              _OfferPackageCard(
                                offer: _offers[i],
                                selected: i == _selectedOfferIndex,
                                enabled: !held && !_busy,
                                onTap: () =>
                                    setState(() => _selectedOfferIndex = i),
                              ),
                            CoachingGraphiteCard(
                              margin: const EdgeInsets.only(top: 2, bottom: 12),
                              padding: const EdgeInsets.all(14),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    color: MetaGymTheme.warning,
                                    size: 19,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Thời hạn bắt đầu khi gói được kích hoạt. Khi gói Gym hết hạn, bạn tạm dừng đặt lịch với Coach. Thời hạn gói Coach vẫn tiếp tục tính.',
                                      style: TextStyle(
                                        color: Color(0xFFD2D5DB),
                                        fontSize: 12.5,
                                        height: 1.48,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedOffer != null)
                              CoachingGraphiteCard(
                                margin: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Gói đã chọn',
                                      style: TextStyle(
                                        color: MetaGymTheme.textPrimary,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _SummaryLine(
                                      label: 'Tên gói',
                                      value: selectedOffer['name'] as String,
                                    ),
                                    _SummaryLine(
                                      label: 'Quyền lợi',
                                      value:
                                          '${selectedOffer['durationDays']} ngày · ${selectedOffer['sessionCount']} buổi',
                                    ),
                                    _SummaryLine(
                                      label: 'Giá gói',
                                      value: formatVnd(
                                        (selectedOffer['price'] as num?) ?? 0,
                                      ),
                                      highlight: true,
                                    ),
                                    const Divider(
                                      color: Color(0x26FFFFFF),
                                      height: 22,
                                    ),
                                    CoachingPrimaryButton(
                                      label: noGym
                                          ? 'Cần gói Gym hiệu lực'
                                          : full
                                          ? 'Coach đã hết suất'
                                          : assignedElsewhere
                                          ? 'Đang có Coach khác'
                                          : (assignedHere && _hasQueuedPackage)
                                          ? 'Đã có gói chờ'
                                          : 'Thanh toán',
                                      loading: _busy && !held,
                                      onPressed: canCheckout
                                          ? () => _reserve(
                                              selectedOffer['code'] as String,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      held
                                          ? 'Bạn đã có một suất đang giữ.'
                                          : assignedHere
                                          ? 'Chỉ một gói Coach được chờ nối tiếp tại một thời điểm.'
                                          : 'Suất được giữ tối đa 15 phút trong quá trình thanh toán.',
                                      style: const TextStyle(
                                        color: MetaGymTheme.textSecondary,
                                        fontSize: 11.5,
                                        height: 1.4,
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
          ),
        ],
      ),
    );
  }
}

class _CoachPackagesHeroCard extends StatelessWidget {
  const _CoachPackagesHeroCard({
    required this.coachName,
    required this.coachAvatar,
    required this.usedSlots,
    required this.memberLimit,
    required this.availableSlots,
    required this.offerCount,
  });

  final String coachName;
  final String? coachAvatar;
  final int? usedSlots;
  final int? memberLimit;
  final int? availableSlots;
  final int offerCount;

  @override
  Widget build(BuildContext context) {
    final hasCapacity = usedSlots != null && memberLimit != null;
    final hasSlots = availableSlots == null || availableSlots! > 0;
    return MetaGymHeroGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachingAvatar(
                fullName: coachName,
                avatarUrl: coachAvatar,
                size: 46,
                round: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coachName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Huấn luyện 1:1 · Mỗi buổi 90 phút',
                      style: TextStyle(color: Color(0xFFD7D2CE), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CoachingPill(
                label: availableSlots == null
                    ? 'Đang mở'
                    : (hasSlots ? 'Còn $availableSlots suất' : 'Đã đủ suất'),
                tone: hasSlots
                    ? CoachingPillTone.green
                    : CoachingPillTone.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MetaGymMetricPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suất học viên',
                          style: TextStyle(
                            color: Color(0xFFB7B2AF),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasCapacity ? '$usedSlots/$memberLimit' : '--',
                          style: const TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
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
                        const Text(
                          'Gói đang mở bán',
                          style: TextStyle(
                            color: Color(0xFFB7B2AF),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$offerCount gói',
                          style: const TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
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

class _OfferPackageCard extends StatelessWidget {
  const _OfferPackageCard({
    required this.offer,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.readOnlyMode = false,
  });

  final CoachRecord offer;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool readOnlyMode;

  @override
  Widget build(BuildContext context) {
    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: selected ? MetaGymTheme.primary : MetaGymTheme.cardBorder,
      onTap: enabled ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  offer['name'] as String,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CoachingPill(
                label: readOnlyMode
                    ? 'Đang mở bán'
                    : (selected ? 'Đã chọn' : 'Chọn gói'),
                tone: readOnlyMode
                    ? CoachingPillTone.green
                    : (selected
                          ? CoachingPillTone.coral
                          : CoachingPillTone.neutral),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${offer['sessionCount']} buổi · ${offer['durationDays']} ngày',
            style: const TextStyle(
              color: Color(0xFFD9DADD),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatVnd((offer['price'] as num?) ?? 0),
            style: const TextStyle(
              color: MetaGymTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: MetaGymTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: MetaGymTheme.textPrimary,
                fontSize: highlight ? 17 : 13.5,
                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
