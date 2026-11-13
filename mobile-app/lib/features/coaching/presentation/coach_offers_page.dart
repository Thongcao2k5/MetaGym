import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
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
  final _keys = <String, String>{};
  List<CoachRecord> _offers = [];
  List<CoachRecord> _days = [];
  CoachRecord? _hold;
  String? _error;
  bool _busy = false;
  bool _loaded = false;

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

  Future<void> _load() => _run(() async {
    final offers = await _api.list('/coach-packages');
    final schedule = await _api.get('/coaches/${widget.coachId}/work-slots');
    final holds = await _api.list('/coach-payment-holds');
    final current = _hold;
    final refreshed = current == null
        ? holds.where((row) => row['coachId'] == widget.coachId).firstOrNull
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

  @override
  Widget build(BuildContext context) {
    final hold = _hold;
    final held = hold?['status'] == 'HELD';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói Coach'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Khi gói Gym hết hạn, bạn tạm dừng đặt lịch với Coach. '
                      'Thời hạn gói Coach vẫn tiếp tục tính.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hold != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${hold['planName']} · ${hold['amount']} ₫'),
                    Text(switch (hold['status']) {
                      'HELD' => 'Đang giữ suất · Chờ thanh toán',
                      'CONSUMED' => 'Đã kích hoạt gói hoặc đưa vào hàng chờ',
                      'EXPIRED' => 'Đã hết hạn giữ suất',
                      'CANCELLED' => 'Đã hủy giữ suất',
                      _ => 'Thanh toán không thành công',
                    }),
                    if (held) ...[
                      Text(
                        'Hết hạn lúc ${DateTime.parse(hold['expiresAt'] as String).toLocal()}',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : () => _readHold(),
                            child: const Text('Kiểm tra trạng thái'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _readHold(cancel: true),
                            child: const Text('Hủy giữ suất'),
                          ),
                        ],
                      ),
                    ] else
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _keys.clear();
                                _hold = null;
                              }),
                        child: const Text('Chọn gói khác'),
                      ),
                  ],
                ),
              ),
            ),
          if (_loaded && _offers.isEmpty)
            const Text('Chưa có gói Coach đang mở bán.'),
          for (final offer in _offers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(offer['name'] as String),
              subtitle: Text(
                '${offer['sessionCount']} buổi · ${offer['durationDays']} ngày · ${offer['price']} ₫',
              ),
              trailing: FilledButton(
                onPressed: _busy || hold != null
                    ? null
                    : () => _reserve(offer['code'] as String),
                child: const Text('Giữ suất'),
              ),
            ),
          const SizedBox(height: 20),
          Text('Lịch làm việc', style: Theme.of(context).textTheme.titleMedium),
          if (_loaded && _days.isEmpty) const Text('Coach chưa cấu hình lịch.'),
          for (final day in _days)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                day['weekday'] == 7
                    ? 'Chủ nhật'
                    : 'Thứ ${(day['weekday'] as int) + 1}',
              ),
              subtitle: Text((day['starts'] as List).join(' · ')),
            ),
        ],
      ),
    );
  }
}
