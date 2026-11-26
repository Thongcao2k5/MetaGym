import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_health_declaration_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:provider/provider.dart';

/// Màn hình **5.9 Xem gói Coach** đồng bộ `tab5-profile-sub.js`
/// (`member-coach-offers`) và chuẩn Warm Smoked Liquid Glass
/// (Dark Mode + Light Mode Daylight Studio).
class CoachOffersPage extends StatefulWidget {
  const CoachOffersPage({required this.coachId, super.key});

  final String coachId;

  @override
  State<CoachOffersPage> createState() => _CoachOffersPageState();
}

class _CoachOffersPageState extends State<CoachOffersPage> {
  CoachV2Api? _api;
  bool _initialized = false;
  final _keys = <String, String>{};
  List<CoachRecord> _offers = [];
  CoachRecord? _coach;
  CoachRecord? _hold;
  CoachRecord? _relationship;
  CoachRecord? _activeMembership;
  bool? _hasActiveGym;
  bool _hasQueuedPackage = false;
  bool _healthDeclared = false;
  double? _memberHeightCm;
  double? _memberWeightKg;
  int _selectedOfferIndex = 0;
  String? _error;
  bool _busy = false;
  bool _loaded = false;

  ApiClient? _watchApiClient(BuildContext context) {
    try {
      return Provider.of<ApiClient?>(context);
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = _watchApiClient(context);
    if (_initialized && identical(client, _api?.client)) return;
    _initialized = true;
    if (client != null) {
      _api = CoachV2Api(client);
      _keys.clear();
      _hold = null;
      _loaded = false;
      _error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    } else {
      _api = null;
      _offers = [];
      _coach = null;
      _hold = null;
      _relationship = null;
      _activeMembership = null;
      _hasActiveGym = null;
      _loaded = true;
      _error = 'Chưa kết nối máy chủ. Hãy đăng nhập lại để xem gói Coach.';
    }
  }

  @override
  void didUpdateWidget(covariant CoachOffersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coachId != widget.coachId && _api != null) {
      _keys.clear();
      _coach = null;
      _hold = null;
      _loaded = false;
      _selectedOfferIndex = 0;
      _load();
    }
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

  int _popularOfferIndex(List<CoachRecord> offers) {
    if (offers.length <= 1) return 0;
    final explicitIdx = offers.indexWhere((o) => o['isPopular'] == true);
    if (explicitIdx >= 0) return explicitIdx;
    var bestIndex = 0;
    var bestSessions = -1;
    for (var i = 0; i < offers.length; i++) {
      final sessions = _offerSessions(offers[i]);
      if (sessions > bestSessions) {
        bestSessions = sessions;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  int _offerSessions(CoachRecord offer) =>
      ((offer['sessionCount'] as num?) ?? (offer['sessionsTotal'] as num?))
          ?.toInt() ??
      0;

  num _offerPrice(CoachRecord offer) =>
      (offer['price'] as num?) ?? (offer['priceVnd'] as num?) ?? 0;

  num _resolveHoldAmount(CoachRecord hold) {
    final direct = (hold['amount'] as num?) ?? (hold['amountVnd'] as num?);
    if (direct != null && direct > 0) return direct;
    final code = hold['planCode'] as String?;
    if (code != null) {
      final matched = _offers.where((o) => o['code'] == code).firstOrNull;
      if (matched != null) {
        final matchedPrice = _offerPrice(matched);
        if (matchedPrice > 0) return matchedPrice;
      }
    }
    return 0;
  }

  void _applyUserProfile(CoachRecord? user) {
    final profile = user?['profile'] as Map?;
    _healthDeclared = profile?['healthDeclarationCompletedAt'] != null;
    _memberHeightCm = (profile?['heightCm'] as num?)?.toDouble();
    _memberWeightKg = (profile?['weightKg'] as num?)?.toDouble();
  }

  Future<void> _load() => _run(() async {
    final api = _api;
    final apiClient = optionalProvider<ApiClient>(context);
    if (api == null || apiClient == null) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = 'Chưa kết nối máy chủ. Hãy đăng nhập lại để xem gói Coach.';
        });
      }
      return;
    }

    final offersFuture = api.list('/coach-packages');
    final holdsFuture = api.list('/coach-payment-holds');
    final coachFuture = _optional(() => api.get('/coaches/${widget.coachId}'));
    final userFuture = _optional(() => api.get('/users/me'));
    final membershipsFuture = _optional(() => api.list('/memberships/me'));
    final relationshipFuture = _optional(
      () => apiClient.get<CoachRecord?>(
        '/relationships/me',
        decode: (data) =>
            data == null ? null : Map<String, dynamic>.from(data as Map),
      ),
    );
    final entitlementsFuture = _optional(() => api.list('/coach-entitlements'));

    final offers = await offersFuture;
    final holds = await holdsFuture;
    final coach = await coachFuture;
    final user = await userFuture;
    final memberships = await membershipsFuture;
    final relationship = await relationshipFuture;
    final entitlements = await entitlementsFuture;

    final current = _hold;
    final activeHoldForCoach = holds
        .where(
          (row) => row['coachId'] == widget.coachId && row['status'] == 'HELD',
        )
        .firstOrNull;
    final refreshed = current == null
        ? activeHoldForCoach
        : (await _optional(
                () => api.get('/coach-payment-holds/${current['id']}'),
              ) ??
              activeHoldForCoach);
    if (refreshed != null && refreshed['status'] != 'HELD') {
      _keys.remove(refreshed['planCode']);
    }

    final activeMembership = memberships
        ?.where((item) => item['status'] == 'ACTIVE')
        .firstOrNull;
    final hasActiveGym = memberships == null ? null : activeMembership != null;
    final hasQueued =
        entitlements?.any((item) => item['status'] == 'QUEUED') ?? false;

    if (!mounted) return;
    setState(() {
      final wasLoaded = _loaded;
      _offers = offers;
      if (!wasLoaded && offers.isNotEmpty) {
        _selectedOfferIndex = _popularOfferIndex(offers);
      } else if (_selectedOfferIndex >= offers.length) {
        _selectedOfferIndex = 0;
      }
      _coach = coach ?? _coach;
      _hold = refreshed;
      _relationship = relationship?.data;
      _activeMembership = activeMembership;
      _hasActiveGym = hasActiveGym;
      _hasQueuedPackage = hasQueued;
      _applyUserProfile(user);
      _loaded = true;
    });
  });

  Future<bool> _openHealthDeclaration({bool checkoutFlow = false}) async {
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
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
      final refreshedUser = _api == null
          ? null
          : await _optional(() => _api!.get('/users/me'));
      if (!mounted) return true;
      setState(() {
        if (refreshedUser != null) {
          _applyUserProfile(refreshedUser);
        }
        _healthDeclared = true;
      });
      return true;
    }
    return false;
  }

  Future<void> _reserve(String code) => _run(() async {
    final api = _api;
    if (api == null) return;
    final user = await _optional(() => api.get('/users/me'));
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
    Future<CoachRecord> createHold() => api.post(
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
    final api = _api;
    final hold = _hold;
    if (api == null || hold == null) return;
    final result = await api.post(
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
    final api = _api;
    if (api == null || _hold == null) return;
    final path = '/coach-payment-holds/${_hold!['id']}';
    final result = cancel
        ? await api.post('$path/cancel')
        : await api.get(path);
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

  String _formatMetric(double value, {required int decimals}) {
    if (decimals == 0 || value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(decimals);
  }

  String _healthMetricsSubtitle() {
    if (!_healthDeclared) {
      return 'Cập nhật chỉ số cơ thể để Coach thiết kế giáo án an toàn';
    }
    final parts = <String>[
      if (_memberHeightCm != null && _memberHeightCm! > 0)
        '${_formatMetric(_memberHeightCm!, decimals: 0)} cm',
      if (_memberWeightKg != null && _memberWeightKg! > 0)
        '${_formatMetric(_memberWeightKg!, decimals: 1)} kg',
      'Sẵn sàng thuê Coach',
    ];
    return parts.join(' · ');
  }

  bool get _isCoachViewer {
    try {
      return optionalProvider<SessionController>(context)?.user?.role ==
          UserRole.coach;
    } catch (_) {
      return false;
    }
  }

  Widget _buildHeader(
    BuildContext context,
    MetaGymColors colors, {
    required String? resolvedCoachName,
  }) {
    final canPop = Navigator.of(context).canPop();
    final isCoachViewer = _isCoachViewer;
    final title = resolvedCoachName != null && resolvedCoachName.isNotEmpty
        ? 'Gói của $resolvedCoachName'
        : 'Xem gói Coach';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          if (canPop) ...[
            Tooltip(
              message: 'Back',
              child: MetaGymCircleIconButton(
                svgAsset: MetaGymIcons.commonBack,
                tooltip: 'Quay lại',
                onTap: _busy ? null : () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GÓI COACHING 1:1',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (!isCoachViewer) ...[
            const SizedBox(width: 8),
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonRefresh,
              tooltip: 'Tải lại',
              onTap: _busy ? null : _load,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoachStrip(
    MetaGymColors colors, {
    required String coachName,
    required String? coachAvatar,
    required int? availableSlots,
  }) {
    return MetaGymGlassCard(
      solid: false,
      key: const Key('offers-coach-strip'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CoachingAvatar(
            fullName: coachName,
            avatarUrl: coachAvatar,
            size: 40,
            round: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coachName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Huấn luyện 1:1 · mỗi buổi 90 phút',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textWarmMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (availableSlots != null) ...[
            const SizedBox(width: 8),
            CoachingPill(
              label: availableSlots > 0
                  ? 'Còn $availableSlots suất'
                  : 'Hết suất',
              tone: availableSlots > 0
                  ? CoachingPillTone.green
                  : CoachingPillTone.amber,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthStatusCard(MetaGymColors colors) {
    final statusColor = _healthDeclared ? colors.success : colors.warning;
    return MetaGymGlassCard(
      solid: false,
      key: const Key('offers-health-status-card'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const MetaGymIcon(
            MetaGymIcons.healthShield,
            size: MetaGymIconSize.sm,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _healthDeclared
                            ? 'Đã khai báo thể trạng'
                            : 'Chưa khai báo thể trạng',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _healthMetricsSubtitle(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textWarmMuted,
                    fontSize: 11.5,
                    height: 1.35,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(MetaGymTheme.radiusSm),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _busy ? null : _editHealthDeclaration,
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusSm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Center(
                    child: Text(
                      _healthDeclared ? 'Xem / sửa' : 'Khai báo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _busy
                            ? colors.textSecondary
                            : colors.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierPerkCard(
    BuildContext context,
    MetaGymColors colors,
    _MembershipTierPerk perk,
  ) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final goldBorder = isLight
        ? colors.warning.withValues(alpha: 0.45)
        : const Color(0x80DAB066);

    return MetaGymGlassCard(
      solid: false,
      key: const Key('offers-tier-perk-card'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      borderColor: goldBorder,
      child: Row(
        children: [
          const MetaGymIcon(
            MetaGymIcons.premiumCrown,
            size: MetaGymIconSize.sm,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perk.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  perk.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textWarmMuted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CoachingPill(
            label: perk.badgeLabel,
            tone: perk.discountPercent > 0
                ? CoachingPillTone.coral
                : CoachingPillTone.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(
    BuildContext context,
    MetaGymColors colors, {
    required String svgAsset,
    required String title,
    required String description,
    required bool isWarning,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final borderColor = isWarning
        ? (isLight
              ? colors.warning.withValues(alpha: 0.45)
              : const Color(0xFF815423))
        : null;

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetaGymIcon(
                svgAsset,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: colors.textWarmMuted,
              fontSize: 12.5,
              height: 1.48,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            CoachingSecondaryButton(label: actionLabel, onPressed: onAction),
          ],
        ],
      ),
    );
  }

  Widget _buildHoldCard(MetaGymColors colors, CoachRecord hold) {
    final held = hold['status'] == 'HELD';
    final consumed = hold['status'] == 'CONSUMED';
    final holdAmount = _resolveHoldAmount(hold);
    final planName = (hold['planName'] as String?)?.trim();
    final holdTitle =
        '${planName != null && planName.isNotEmpty ? planName : (hold['planCode'] ?? 'Gói Coach')} · ${formatVnd(holdAmount)}';

    return MetaGymHeroGlassCard(
      key: const Key('offers-hold-card'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetaGymIcon(
                held
                    ? MetaGymIcons.paymentPending
                    : consumed
                    ? MetaGymIcons.paymentSuccess
                    : MetaGymIcons.stateInfo,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: CoachingPill(
                  label: switch (hold['status']) {
                    'HELD' => 'Đang giữ suất · Chờ thanh toán',
                    'CONSUMED' => 'Đã kích hoạt gói hoặc đưa vào hàng chờ',
                    'EXPIRED' => 'Đã hết hạn giữ suất',
                    'CANCELLED' => 'Đã hủy giữ suất',
                    _ => 'Thanh toán không thành công',
                  },
                  tone: held
                      ? CoachingPillTone.amber
                      : consumed
                      ? CoachingPillTone.green
                      : CoachingPillTone.neutral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            holdTitle,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
          const SizedBox(height: 6),
          if (held) ...[
            Text(
              'Suất được giữ tối đa 15 phút (hết hạn ${formatVietnamTime(hold['expiresAt'] as String?)})',
              style: TextStyle(
                color: colors.textWarmMuted,
                fontSize: 12.5,
                height: 1.45,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
            const SizedBox(height: 14),
            CoachingPrimaryButton(
              label: 'Hoàn tất thanh toán',
              onPressed: _busy ? null : _confirmMockPayment,
            ),
            const SizedBox(height: 10),
            CoachingSecondaryButton(
              label: 'Hủy giữ suất',
              expand: true,
              onPressed: _busy ? null : () => _readHold(cancel: true),
            ),
          ] else ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _keys.clear();
                      _hold = null;
                    }),
              style: TextButton.styleFrom(
                foregroundColor: colors.primaryText,
                minimumSize: const Size(48, 48),
              ),
              child: const Text(
                'Chọn gói khác',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckoutSummaryCard(
    MetaGymColors colors, {
    required CoachRecord selectedOffer,
    required _MembershipTierPerk? tierPerk,
    required bool noGym,
    required bool full,
    required bool assignedElsewhere,
    required bool assignedHere,
    required bool held,
    required bool canCheckout,
  }) {
    final rawName = (selectedOffer['name'] as String?)?.trim();
    final offerName = rawName != null && rawName.isNotEmpty
        ? rawName
        : ((selectedOffer['code'] as String?) ?? 'Gói Coach');
    final durationDays = (selectedOffer['durationDays'] as num?)?.toInt() ?? 0;
    final sessionCount = _offerSessions(selectedOffer);
    final rawPrice = _offerPrice(selectedOffer);
    final discountPercent = tierPerk?.discountPercent ?? 0;
    final discountedPrice = discountPercent > 0
        ? (rawPrice * (100 - discountPercent) / 100).round()
        : rawPrice;
    final discountAmount = rawPrice - discountedPrice;
    final description = (selectedOffer['description'] as String?)?.trim();

    return MetaGymGlassCard(
      solid: false,
      key: const Key('offers-checkout-card'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MetaGymIcon(
                MetaGymIcons.paymentCart,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chọn gói & Thanh toán',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SummaryLine(label: 'Tên gói', value: offerName),
          _SummaryLine(
            label: 'Quyền lợi',
            value: '$durationDays ngày · $sessionCount buổi',
          ),
          if (discountPercent > 0 && tierPerk != null) ...[
            _SummaryLine(label: 'Giá niêm yết', value: formatVnd(rawPrice)),
            _SummaryLine(
              label: 'Ưu đãi ${tierPerk.tierLabel}',
              value: '-$discountPercent% (-${formatVnd(discountAmount)})',
              valueColor: colors.success,
            ),
            _SummaryLine(
              label: 'Giá sau ưu đãi',
              value: formatVnd(discountedPrice),
              highlight: true,
            ),
          ] else
            _SummaryLine(
              label: 'Giá gói',
              value: formatVnd(rawPrice),
              highlight: true,
            ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: colors.textWarmMuted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
          Divider(
            color: colors.metricPanelBorder.withValues(alpha: 0.45),
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
                ? () => _reserve(selectedOffer['code'] as String)
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            held
                ? 'Bạn đã có một suất đang giữ.'
                : assignedHere
                ? 'Chỉ một gói Coach được chờ nối tiếp tại một thời điểm.'
                : 'Suất được giữ tối đa 15 phút trong quá trình thanh toán.',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final hold = _hold;
    final held = hold?['status'] == 'HELD';
    final rawCoachName = (_coach?['fullName'] as String?)?.trim();
    final coachName = rawCoachName != null && rawCoachName.isNotEmpty
        ? rawCoachName
        : 'Coach phụ trách';
    final coachAvatar = _coach?['avatarUrl'] as String?;
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
    final tierPerk = _activeMembership != null
        ? _MembershipTierPerk.fromMembership(_activeMembership!)
        : null;
    final popularIdx = _offers.length > 1 ? _popularOfferIndex(_offers) : -1;
    final canCheckout =
        !_busy &&
        !held &&
        !noGym &&
        !full &&
        !assignedElsewhere &&
        !(assignedHere && _hasQueuedPackage) &&
        selectedOffer != null;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context, colors, resolvedCoachName: rawCoachName),
                Expanded(
                  child: !_loaded && _busy && _offers.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: colors.overlayGlass,
                          onRefresh: _load,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              MediaQuery.paddingOf(context).bottom + 28,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_busy)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        color: MetaGymTheme.brandOrange,
                                        backgroundColor: colors.metricPanelBg,
                                      ),
                                    ),
                                  ),
                                if (_error != null) ...[
                                  CoachingErrorBanner(message: _error!),
                                  if (!_loaded || _offers.isEmpty) ...[
                                    CoachingSecondaryButton(
                                      label: 'Thử lại',
                                      expand: true,
                                      onPressed: _busy ? null : _load,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ],
                                if (_coach != null)
                                  _buildCoachStrip(
                                    colors,
                                    coachName: coachName,
                                    coachAvatar: coachAvatar,
                                    availableSlots: availableSlots,
                                  ),
                                if (_loaded && _api != null)
                                  _buildHealthStatusCard(colors),
                                if (noGym)
                                  _buildNoticeCard(
                                    context,
                                    colors,
                                    svgAsset: MetaGymIcons.stateWarning,
                                    title: 'Gói Gym chưa hiệu lực',
                                    description: 'Bạn vẫn có thể xem hồ sơ và giá gói Coach. Để mua, hãy có gói Gym còn hiệu lực.',
                                    isWarning: true,
                                    actionLabel: 'Xem gói Gym',
                                    onAction: () =>
                                        MetaGymNavigation.pushOnce<void>(
                                          context,
                                          MetaGymPageRoute(
                                            builder: (_) =>
                                                const MembershipPage(),
                                          ),
                                        ),
                                  )
                                else if (tierPerk != null)
                                  _buildTierPerkCard(context, colors, tierPerk),
                                if (full)
                                  _buildNoticeCard(
                                    context,
                                    colors,
                                    svgAsset: MetaGymIcons.stateWarning,
                                    title: 'Coach đã hết suất',
                                    description: 'Bạn có thể nhắn Coach hoặc quay lại Khám phá để chọn người khác.',
                                    isWarning: true,
                                    actionLabel: 'Quay lại hồ sơ Coach',
                                    onAction: () =>
                                        Navigator.of(context).maybePop(),
                                  )
                                else if (assignedElsewhere)
                                  _buildNoticeCard(
                                    context,
                                    colors,
                                    svgAsset: MetaGymIcons.stateWarning,
                                    title: 'Bạn đã có Coach khác',
                                    description: 'Mỗi hội viên chỉ có một Coach hiện hành. Xem thông tin Coach của bạn trước khi chọn người mới.',
                                    isWarning: true,
                                    actionLabel: 'Coach của tôi',
                                    onAction: () =>
                                        MetaGymNavigation.pushOnce<void>(
                                          context,
                                          MetaGymPageRoute(
                                            builder: (_) =>
                                                const MemberCoachingPage(),
                                          ),
                                        ),
                                  )
                                else if (assignedHere)
                                  _buildNoticeCard(
                                    context,
                                    colors,
                                    svgAsset: MetaGymIcons.membershipScheduled,
                                    title: 'Gói nối tiếp',
                                    description: _hasQueuedPackage
                                        ? 'Bạn đã có một gói Coach đang chờ kích hoạt sau gói hiện tại.'
                                        : 'Bạn đang tập cùng Coach này. Có thể mua một gói chờ kích hoạt sau gói hiện tại.',
                                    isWarning: false,
                                  ),
                                if (hold != null) _buildHoldCard(colors, hold),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 10,
                                    top: 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Gói huấn luyện',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (_offers.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        CoachingPill(
                                          label: '${_offers.length} gói',
                                          tone: CoachingPillTone.neutral,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_loaded && _offers.isEmpty)
                                  MetaGymGlassCard(
                                    solid: false,
                                    key: const Key('offers-empty-card'),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      children: [
                                        const MetaGymIcon(
                                          MetaGymIcons.emptyPayments,
                                          size: MetaGymIconSize.lg,
                                          excludeFromSemantics: true,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Chưa có gói Coach đang mở bán.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Vui lòng quay lại sau hoặc kéo xuống để tải lại bảng giá mới nhất.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: colors.textWarmMuted,
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                for (var i = 0; i < _offers.length; i++)
                                  _OfferPackageCard(
                                    offer: _offers[i],
                                    selected: i == _selectedOfferIndex,
                                    isPopular: i == popularIdx,
                                    featuredGlass:
                                        i == _selectedOfferIndex &&
                                        hold == null,
                                    discountPercent:
                                        tierPerk?.discountPercent ?? 0,
                                    enabled: !held && !_busy,
                                    onTap: () =>
                                        setState(() => _selectedOfferIndex = i),
                                  ),
                                MetaGymGlassCard(
                                  solid: false,
                                  margin: const EdgeInsets.only(
                                    top: 2,
                                    bottom: 12,
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const MetaGymIcon(
                                        MetaGymIcons.timeClock,
                                        size: MetaGymIconSize.sm,
                                        excludeFromSemantics: true,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Thời hạn bắt đầu khi gói được kích hoạt. Khi gói Gym hết hạn, bạn tạm dừng đặt lịch với Coach. Thời hạn gói Coach vẫn tiếp tục tính.',
                                          style: TextStyle(
                                            color: colors.textWarmMuted,
                                            fontSize: 12.5,
                                            height: 1.48,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (selectedOffer != null)
                                  _buildCheckoutSummaryCard(
                                    colors,
                                    selectedOffer: selectedOffer,
                                    tierPerk: tierPerk,
                                    noGym: noGym,
                                    full: full,
                                    assignedElsewhere: assignedElsewhere,
                                    assignedHere: assignedHere,
                                    held: held,
                                    canCheckout: canCheckout,
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
    );
  }
}

class _MembershipTierPerk {
  const _MembershipTierPerk({
    required this.tierLabel,
    required this.discountPercent,
    required this.pointsMultiplier,
  });

  final String tierLabel;
  final int discountPercent;
  final String pointsMultiplier;

  String get title => discountPercent > 0
      ? 'Đặc quyền $tierLabel đang áp dụng'
      : 'Quyền lợi $tierLabel đang áp dụng';

  String get subtitle => discountPercent > 0
      ? 'Giảm trực tiếp $discountPercent% mọi gói Coach 1:1 + Tích Meta Points'
      : 'Tích Meta Points mọi gói Coach 1:1 · Nâng hạng để giảm tới 10%';

  String get badgeLabel =>
      discountPercent > 0 ? '-$discountPercent%' : pointsMultiplier;

  static _MembershipTierPerk fromMembership(CoachRecord membership) {
    final explicitDiscount = (membership['coachDiscountPercent'] as num?)
        ?.toInt();
    final explicitTier = (membership['tierName'] as String?)?.trim();
    if (explicitDiscount != null && explicitDiscount > 0) {
      return _MembershipTierPerk(
        tierLabel: explicitTier != null && explicitTier.isNotEmpty
            ? explicitTier
            : 'Hạng Hội viên',
        discountPercent: explicitDiscount.clamp(0, 50),
        pointsMultiplier: '×1.5',
      );
    }

    final planName = (membership['planName'] as String? ?? '').toLowerCase();
    final durationDays = _inferDurationDays(membership);

    if (planName.contains('kim cương') ||
        planName.contains('diamond') ||
        planName.contains('1 năm') ||
        planName.contains('12 tháng') ||
        durationDays >= 330) {
      return const _MembershipTierPerk(
        tierLabel: 'Thẻ Kim Cương',
        discountPercent: 10,
        pointsMultiplier: '×2.0',
      );
    }
    if (planName.contains('vàng') ||
        planName.contains('gold') ||
        planName.contains('elite') ||
        planName.contains('6 tháng') ||
        durationDays >= 160) {
      return const _MembershipTierPerk(
        tierLabel: 'Thẻ Vàng',
        discountPercent: 5,
        pointsMultiplier: '×1.5',
      );
    }
    if (planName.contains('bạc') ||
        planName.contains('silver') ||
        planName.contains('pro') ||
        planName.contains('3 tháng') ||
        durationDays >= 75) {
      return const _MembershipTierPerk(
        tierLabel: 'Thẻ Bạc',
        discountPercent: 3,
        pointsMultiplier: '×1.2',
      );
    }
    return const _MembershipTierPerk(
      tierLabel: 'Hội viên',
      discountPercent: 0,
      pointsMultiplier: 'Meta Points',
    );
  }

  static int _inferDurationDays(CoachRecord membership) {
    final raw = (membership['durationDays'] as num?)?.toInt();
    if (raw != null && raw > 0) return raw;
    final start = DateTime.tryParse(
      (membership['startDate'] as String? ?? '').trim(),
    );
    final end = DateTime.tryParse(
      (membership['endDate'] as String? ?? '').trim(),
    );
    if (start == null || end == null) return 0;
    return end.difference(start).inDays;
  }
}

class _OfferPackageCard extends StatelessWidget {
  const _OfferPackageCard({
    required this.offer,
    required this.selected,
    required this.isPopular,
    required this.featuredGlass,
    required this.discountPercent,
    required this.enabled,
    required this.onTap,
  });

  final CoachRecord offer;
  final bool selected;
  final bool isPopular;
  final bool featuredGlass;
  final int discountPercent;
  final bool enabled;
  final VoidCallback onTap;

  String _packageIconAsset(int sessionCount) {
    if (isPopular || sessionCount >= 20) {
      return MetaGymIcons.coachPkgIntensive;
    }
    if (sessionCount >= 10) {
      return MetaGymIcons.coachPkgStandard;
    }
    return MetaGymIcons.coachPkgTrial;
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final code = (offer['code'] as String?)?.trim() ?? '';
    final rawName = (offer['name'] as String?)?.trim();
    final displayName = rawName != null && rawName.isNotEmpty
        ? rawName
        : (code.isNotEmpty ? code : 'Gói Coach');
    final description = (offer['description'] as String?)?.trim();
    final sessionCount =
        ((offer['sessionCount'] as num?) ?? (offer['sessionsTotal'] as num?))
            ?.toInt() ??
        0;
    final durationDays = (offer['durationDays'] as num?)?.toInt() ?? 0;
    final price = (offer['price'] as num?) ?? (offer['priceVnd'] as num?) ?? 0;
    final hasDiscount = discountPercent > 0 && price > 0;
    final discountedPrice = hasDiscount
        ? (price * (100 - discountPercent) / 100).round()
        : price;

    final borderColor = selected
        ? MetaGymTheme.primary.withValues(alpha: isLight ? 0.85 : 0.72)
        : null;

    return MetaGymGlassCard(
      solid: false,
      key: ValueKey('offer-card-${code.isNotEmpty ? code : displayName}'),
      margin: const EdgeInsets.only(bottom: 11),
      padding: EdgeInsets.all(selected ? 15 : 14),
      featured: featuredGlass,
      borderColor: borderColor,
      borderRadius: BorderRadius.circular(
        selected ? MetaGymTheme.radiusGlassDock : MetaGymTheme.radiusCard,
      ),
      onTap: enabled ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetaGymIcon(
                _packageIconAsset(sessionCount),
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: selected ? 15.5 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isPopular)
                const CoachingPill(
                  label: 'Phổ biến',
                  tone: CoachingPillTone.coral,
                )
              else
                Text(
                  '$durationDays ngày',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                formatVnd(discountedPrice),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: selected ? 21 : 18.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
              if (hasDiscount)
                Text(
                  formatVnd(price),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: colors.textSecondary,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textWarmMuted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$sessionCount buổi · $durationDays ngày',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textWarmMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                const CoachingPill(
                  label: 'Đã chọn',
                  tone: CoachingPillTone.coral,
                  icon: Icons.check_rounded,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.metricPanelBg,
                    borderRadius: BorderRadius.circular(MetaGymTheme.radiusSm),
                    border: Border.all(color: colors.metricPanelBorder),
                  ),
                  child: Text(
                    'Chọn gói',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.highlight = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: colors.textWarmMuted, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color:
                    valueColor ??
                    (highlight ? colors.primaryText : colors.textPrimary),
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
