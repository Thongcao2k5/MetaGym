import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:provider/provider.dart';

class CoachOffersPage extends StatefulWidget {
  const CoachOffersPage({required this.coachId, super.key});
  final String coachId;

  @override
  State<CoachOffersPage> createState() => _CoachOffersPageState();
}

class _CoachOffersPageState extends State<CoachOffersPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  final _money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  final _keys = <String, String>{};

  List<CoachRecord> _offers = [];
  List<CoachRecord> _days = [];
  CoachRecord? _hold;
  String? _error;
  bool _busy = false;
  bool _loaded = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      _timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_hold != null && _hold!['status'] == 'HELD') {
          _checkHoldSilently();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkHoldSilently() async {
    final current = _hold;
    if (current == null) return;
    try {
      final res = await _api.get('/coach-payment-holds/${current['id']}');
      if (mounted) setState(() => _hold = res);
    } catch (_) {}
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
        setState(() => _error = 'Không thực hiện được thao tác. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() => _run(() async {
        final offers = await _api.list('/coach-packages');
        final schedule =
            await _api.get('/coaches/${widget.coachId}/work-slots');
        final holds = await _api.list('/coach-payment-holds');
        final current = _hold;
        final refreshed = current == null
            ? holds
                .where((row) => row['coachId'] == widget.coachId)
                .firstOrNull
            : await _api.get('/coach-payment-holds/${current['id']}');
        if (!mounted) return;
        setState(() {
          _offers = offers;
          _days = (schedule['days'] as List).cast<CoachRecord>();
          _hold = refreshed;
          _loaded = true;
        });
      });

  Future<void> _reserve(String code) => _run(() async {
        final hold = await _api.post(
          '/coach-payment-holds',
          body: {'coachId': widget.coachId, 'planCode': code},
          key: _keys.putIfAbsent(code, newClientMessageId),
        );
        if (mounted) setState(() => _hold = hold);
      });

  Future<void> _readHold({bool cancel = false}) => _run(() async {
        final path = '/coach-payment-holds/${_hold!['id']}';
        final result = cancel
            ? await _api.post('$path/cancel')
            : await _api.get(path);
        if (mounted) setState(() => _hold = result);
      });

  Future<void> _confirmMockPayment() => _run(() async {
        final path =
            '/coach-payment-holds/${_hold!['id']}/mock-confirmations';
        final result = await _api.post(path);
        if (mounted) {
          setState(() {
            _hold = result['hold'] as CoachRecord;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kích hoạt gói Coach thành công!'),
              backgroundColor: Color(0xFF34C759),
            ),
          );
        }
      });

  @override
  Widget build(BuildContext context) {
    final hold = _hold;
    final held = hold?['status'] == 'HELD';
    final consumed = hold?['status'] == 'CONSUMED';

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      MetaGymCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HUẤN LUYỆN VIÊN 1-1',
                              style: TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Gói thuê Coach',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MetaGymCircleIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Tải lại',
                        onTap: _busy ? null : _load,
                      ),
                    ],
                  ),
                ),
                if (_busy)
                  const LinearProgressIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: Color(0x20FF5A36),
                    minHeight: 2,
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (_error != null) ...[
                        MetaGymGlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFFF6961), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6961),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Thông báo quy tắc điều kiện gói Gym
                      MetaGymGlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              color: MetaGymTheme.reflectionBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Điều kiện thuê Coach',
                                    style: TextStyle(
                                      color: MetaGymTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Khi gói Gym hết hạn, bạn tạm dừng đặt lịch với Coach. Thời hạn gói Coach vẫn tiếp tục tính.',
                                    style: TextStyle(
                                      color: MetaGymTheme.textSecondary,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Trạng thái giữ suất hoặc đã kích hoạt
                      if (hold != null) ...[
                        if (held)
                          _buildHeldCard(hold)
                        else if (consumed)
                          _buildConsumedCard(hold)
                        else
                          _buildOtherStatusCard(hold),
                        const SizedBox(height: 18),
                      ],

                      // Tiêu đề danh sách gói
                      const Text(
                        'Các gói đào tạo cá nhân',
                        style: TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_loaded && _offers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Hiện chưa có gói Coach nào đang mở bán.',
                              style: TextStyle(color: MetaGymTheme.textSecondary),
                            ),
                          ),
                        ),

                      for (final offer in _offers)
                        _buildOfferCard(offer, disabled: _busy || held),

                      const SizedBox(height: 20),

                      // Lịch làm việc của Coach
                      const Text(
                        'Lịch làm việc cố định của Coach',
                        style: TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Mỗi buổi tập diễn ra trong 90 phút (1-1). Bạn có thể đặt trước các khung giờ dưới đây sau khi kích hoạt gói.',
                        style: TextStyle(
                          color: MetaGymTheme.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_loaded && _days.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Coach chưa cấu hình lịch làm việc.',
                            style: TextStyle(color: MetaGymTheme.textSecondary),
                          ),
                        ),

                      for (final day in _days) _buildScheduleDayTile(day),
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

  Widget _buildHeldCard(CoachRecord hold) {
    final expires = DateTime.tryParse(hold['expiresAt'] as String? ?? '')?.toLocal();
    final expireText = expires == null ? '' : DateFormat('HH:mm').format(expires);

    return MetaGymGlassCard(
      padding: const EdgeInsets.all(16),
      featured: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0x26FF5A36),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: MetaGymTheme.brandOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ĐANG GIỮ SUẤT (15 PHÚT)',
                      style: TextStyle(
                        color: MetaGymTheme.brandOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${hold['planName']} · ${_money.format(hold['amount'])}',
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Hệ thống đang giữ slot học viên cho bạn đến $expireText. Vui lòng xác nhận thanh toán mô phỏng để kích hoạt gói ngay.',
            style: const TextStyle(
              color: MetaGymTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.brandOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            onPressed: _busy ? null : _confirmMockPayment,
            label: const Text(
              'Xác nhận đã thanh toán mô phỏng',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _readHold(),
                child: const Text('Kiểm tra trạng thái',
                    style: TextStyle(color: MetaGymTheme.reflectionBlue, fontSize: 12)),
              ),
              TextButton(
                onPressed: _busy ? null : () => _readHold(cancel: true),
                child: const Text('Hủy giữ suất',
                    style: TextStyle(color: Color(0xFFFF6961), fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsumedCard(CoachRecord hold) {
    return MetaGymGlassCard(
      padding: const EdgeInsets.all(16),
      featured: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0x2634C759),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF34C759),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ĐÃ KÍCH HOẠT GÓI COACH',
                      style: TextStyle(
                        color: Color(0xFF34C759),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${hold['planName']} · Đang hoạt động',
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Quan hệ Coach đã được kích hoạt. Bạn có thể quay lại trang Tập luyện để xem Giáo trình hoặc đặt lịch tập 1-1.',
            style: TextStyle(
              color: MetaGymTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hoàn tất & Quay lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherStatusCard(CoachRecord hold) {
    final status = hold['status'];
    final label = switch (status) {
      'EXPIRED' => 'Suất giữ đã hết hạn 15 phút.',
      'CANCELLED' => 'Bạn đã hủy giữ suất này.',
      _ => 'Giao dịch chưa hoàn thành.',
    };

    return MetaGymGlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: MetaGymTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: MetaGymTheme.textSecondary, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _keys.clear();
                      _hold = null;
                    }),
            child: const Text('Chọn lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(CoachRecord offer, {required bool disabled}) {
    final code = offer['code'] as String;
    final name = offer['name'] as String;
    final sessionCount = offer['sessionCount'] as int;
    final durationDays = offer['durationDays'] as int;
    final price = offer['price'] as num;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MetaGymGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: MetaGymTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x26A9C7E8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x40A9C7E8)),
                  ),
                  child: Text(
                    '$sessionCount buổi tập',
                    style: const TextStyle(
                      color: MetaGymTheme.reflectionBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_money.format(price)} · Thời hạn $durationDays ngày',
              style: const TextStyle(
                color: MetaGymTheme.brandOrange,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mỗi buổi 90 phút (1-1). Tặng tối đa 7 ngày bổ sung nếu chưa dùng hết buổi.',
              style: TextStyle(
                color: MetaGymTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: disabled ? null : () => _reserve(code),
              child: const Text(
                'Giữ suất',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleDayTile(CoachRecord day) {
    final weekday = day['weekday'] as int;
    final dayName = weekday == 7 ? 'Chủ nhật' : 'Thứ ${weekday + 1}';
    final starts = (day['starts'] as List).cast<String>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MetaGymGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x1FA9C7E8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                dayName,
                style: const TextStyle(
                  color: MetaGymTheme.reflectionBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                starts.isEmpty ? 'Nghỉ' : starts.join('  ·  '),
                style: const TextStyle(
                  color: MetaGymTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
