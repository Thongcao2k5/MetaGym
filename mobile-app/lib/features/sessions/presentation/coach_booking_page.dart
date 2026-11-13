import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:provider/provider.dart';

DateTime _gymTime(DateTime time) => time.toUtc().add(const Duration(hours: 7));
String _date(DateTime time) => time.toIso8601String().substring(0, 10);

String _slotLabel(String value) {
  final time = _gymTime(DateTime.parse(value));
  return '${_date(time)} · ${time.toIso8601String().substring(11, 16)}';
}

class CoachBookingPage extends StatefulWidget {
  const CoachBookingPage({this.coachId, super.key});
  final String? coachId;

  @override
  State<CoachBookingPage> createState() => _CoachBookingPageState();
}

class _CoachBookingPageState extends State<CoachBookingPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  bool get _isCoach => widget.coachId != null;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  List<CoachRecord> _packages = [];
  List<CoachRecord> _bookings = [];
  List<CoachRecord> _blocks = [];
  List<CoachRecord> _days = [];

  @override
  void initState() {
    super.initState();
    _run(_reload);
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
        setState(() => _error = 'Không xử lý được lịch. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    final bookings = await _api.list('/coach-bookings');
    final packages = _isCoach
        ? <CoachRecord>[]
        : await _api.list('/coach-entitlements');
    final blocks = _isCoach
        ? await _api.list('/coach-bookings/blocks')
        : <CoachRecord>[];
    final schedule = _isCoach
        ? await _api.get('/coaches/${widget.coachId}/work-slots')
        : null;
    if (mounted) {
      setState(() {
        _bookings = bookings;
        _packages = packages;
        _blocks = blocks;
        _days = (schedule?['days'] as List? ?? []).cast<CoachRecord>();
        _loaded = true;
      });
    }
  }

  Future<void> _chooseSlot(CoachRecord pack, {String? bookingId}) async {
    final now = _gymTime(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime.parse(pack['endsOn'] as String);
    if (end.isBefore(today)) return;
    final day = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: end,
    );
    if (day == null || !mounted) return;
    await _run(() async {
      final slots = await _api.list(
        '/coach-bookings/available-slots',
        query: {
          'date': _date(day),
          'entitlementId': pack['id'],
          'bookingId': ?bookingId,
        },
      );
      if (!mounted) return;
      final slot = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(bookingId == null ? 'Chọn giờ tập' : 'Chọn giờ mới'),
          children: [
            if (slots.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Không có giờ khả dụng ngày này.'),
              ),
            for (final slot in slots)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, slot['startsAt']),
                child: Text(_slotLabel(slot['startsAt'] as String)),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      if (slot == null || !mounted) return;
      if (bookingId == null) {
        await _api.post(
          '/coach-bookings',
          body: {'entitlementId': pack['id'], 'startsAt': slot},
        );
      } else {
        final original = _bookings.firstWhere(
          (entry) => entry['id'] == bookingId,
        );
        if (_willCharge(original) && !await _confirmCharge('Đổi giờ tập')) {
          return;
        }
        await _api.patch('/coach-bookings/$bookingId', {
          'action': 'RESCHEDULE',
          'startsAt': slot,
        });
      }
      await _reload();
    });
  }

  Future<String?> _reason(String heading) async {
    var reason = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(heading),
        content: TextFormField(
          maxLength: 500,
          autofocus: true,
          onChanged: (value) => reason = value.trim(),
          decoration: const InputDecoration(labelText: 'Lý do'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () {
              if (reason.isNotEmpty) Navigator.pop(ctx, reason);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(CoachRecord booking, String action) async {
    if (!_isCoach &&
        action == 'CANCEL' &&
        _willCharge(booking) &&
        !await _confirmCharge('Hủy buổi tập')) {
      return;
    }
    final reason = _isCoach && action == 'CANCEL'
        ? await _reason('Hủy buổi tập')
        : null;
    if (!mounted || (_isCoach && action == 'CANCEL' && reason == null)) return;
    await _run(() async {
      await _api.patch('/coach-bookings/${booking['id']}', {
        'action': action,
        'reason': ?reason,
      });
      await _reload();
    });
  }

  bool _willCharge(CoachRecord booking) =>
      DateTime.parse(booking['startsAt'] as String).difference(DateTime.now()) <
      const Duration(hours: 12);

  Future<bool> _confirmCharge(String title) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(title),
            content: const Text(
              'Còn dưới 12 giờ đến buổi tập. Nếu tiếp tục, gói Coach sẽ bị trừ một lượt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Quay lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _block() async {
    final now = _gymTime(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final day = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 190)),
    );
    if (day == null || !mounted) return;
    final starts =
        _days
                .where((row) => row['weekday'] == day.weekday)
                .firstOrNull?['starts']
            as List? ??
        [];
    final time = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Chọn giờ cần khóa'),
        children: [
          if (starts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ngày này không có lịch làm việc.'),
            ),
          for (final time in starts)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, time),
              child: Text(time as String),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    if (time == null || !mounted) return;
    final reason = await _reason('Khóa khung giờ');
    if (reason == null || !mounted) return;
    await _setBlock('${_date(day)}T$time:00+07:00', reason: reason);
  }

  Future<void> _setBlock(String slot, {String? reason}) => _run(() async {
    await _api.put('/coach-bookings/blocks', {
      'startsAt': slot,
      'blocked': reason != null,
      'reason': ?reason,
    });
    await _reload();
  });

  Future<void> _editSchedule() async {
    final values = {
      for (final day in _days)
        day['weekday'] as int: (day['starts'] as List).join(', '),
    };
    final days = await showDialog<List<CoachRecord>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lịch làm việc hằng tuần'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nhập giờ bắt đầu, cách nhau bằng dấu phẩy. Chọn ít nhất 6 ngày, mỗi ngày 4 khung liên tiếp cách nhau 90 phút.',
              ),
              for (var day = 1; day <= 7; day++)
                TextFormField(
                  initialValue: values[day],
                  onChanged: (value) => values[day] = value,
                  decoration: InputDecoration(
                    labelText: day == 7 ? 'Chủ nhật' : 'Thứ ${day + 1}',
                    hintText: '06:00, 07:30, 09:00, 10:30',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Thông báo Coach',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const CoachNotificationsPage()),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, <CoachRecord>[
              for (final entry in values.entries)
                if (entry.value.trim().isNotEmpty)
                  {
                    'weekday': entry.key,
                    'starts': entry.value
                        .split(',')
                        .map((value) => value.trim())
                        .toList(),
                  },
            ]),
            child: const Text('Lưu lịch'),
          ),
        ],
      ),
    );
    if (days == null || !mounted) return;
    await _run(() async {
      await _api.put('/coach/work-slots', {'days': days});
      await _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch Coach'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _busy ? null : () => _run(_reload),
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
          if (_isCoach) ...[
            OutlinedButton(
              onPressed: _busy ? null : _editSchedule,
              child: const Text('Sửa lịch làm việc'),
            ),
            OutlinedButton(
              onPressed: _busy || _days.isEmpty ? null : _block,
              child: const Text('Khóa khung giờ'),
            ),
            for (final block in _blocks)
              ListTile(
                title: Text(_slotLabel(block['startsAt'] as String)),
                subtitle: Text(block['reason'] as String),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _setBlock(block['startsAt'] as String),
                  child: const Text('Mở giờ'),
                ),
              ),
          ] else ...[
            if (_loaded && _packages.isEmpty)
              const Text('Bạn chưa có gói Coach.'),
            for (final pack in _packages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(pack['planName'] as String),
                subtitle: Text(switch (pack['status']) {
                  'ACTIVE' when pack['relationshipStatus'] == 'PAUSED' =>
                    'Tạm dừng · Gói Coach vẫn tính thời hạn đến ${pack['endsOn']}',
                  'ACTIVE' =>
                    '${pack['remainingSessions']}/${pack['totalSessions']} buổi còn lại · Đến ${pack['endsOn']}',
                  'QUEUED' => 'Chờ kích hoạt',
                  _ => 'Đã kết thúc',
                }),
                trailing:
                    pack['status'] != 'ACTIVE' ||
                        pack['relationshipStatus'] != 'ACTIVE' ||
                        DateTime.parse(pack['endsOn'] as String)
                            .isBefore(DateTime.parse(_date(_gymTime(now))))
                    ? null
                    : FilledButton(
                        onPressed: _busy ? null : () => _chooseSlot(pack),
                        child: const Text('Đặt lịch'),
                      ),
              ),
          ],
          const SizedBox(height: 20),
          Text('Buổi tập', style: Theme.of(context).textTheme.titleMedium),
          if (_loaded && _bookings.isEmpty)
            const Text('Chưa có buổi tập với Coach.'),
          for (final booking in _bookings) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_slotLabel(booking['startsAt'] as String)),
              subtitle: Text(switch (booking['status']) {
                'BOOKED' => 'Đã đặt',
                'COMPLETED' => 'Đã hoàn thành',
                _ =>
                  'Đã hủy${booking['chargedAt'] != null ? ' · Đã trừ lượt' : ''}',
              }),
            ),
            if (booking['status'] == 'BOOKED')
              Wrap(
                spacing: 8,
                children: [
                  if (DateTime.parse(booking['startsAt'] as String)
                      .isAfter(now)) ...[
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _resolve(booking, 'CANCEL'),
                      child: const Text('Hủy buổi'),
                    ),
                    if (!_isCoach)
                      for (final pack in _packages.where(
                        (row) =>
                            row['id'] == booking['entitlementId'] &&
                            row['status'] == 'ACTIVE',
                      ))
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _chooseSlot(
                                  pack,
                                  bookingId: booking['id'] as String,
                                ),
                          child: const Text('Đổi giờ'),
                        ),
                  ],
                  if (_isCoach &&
                      !DateTime.parse(booking['endsAt'] as String)
                          .isAfter(now)) ...[
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _resolve(booking, 'COMPLETE'),
                      child: const Text('Hoàn thành'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _resolve(booking, 'NO_SHOW'),
                      child: const Text('Vắng'),
                    ),
                  ],
                ],
              ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}
