import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/domain/journal_entry.dart';
import 'package:provider/provider.dart';

/// Màn hình Nhật ký tập luyện cá nhân đồng bộ bảng màu & định dạng thẻ
/// với Trang chủ Hội viên (`member_dashboard_view.dart`) và Hồ sơ (`profile_page.dart`).
class MemberJournalPage extends StatefulWidget {
  const MemberJournalPage({
    this.service,
    this.membershipService,
    this.photoService,
    this.picker,
    super.key,
  });

  final MemberJournalService? service;
  final MembershipService? membershipService;
  final MemberPhotoService? photoService;
  final ProgressPhotoPicker? picker;

  @override
  State<MemberJournalPage> createState() => _MemberJournalPageState();
}

class _MemberJournalPageState extends State<MemberJournalPage> {
  MemberJournalService? _service;
  MembershipService? _membershipService;
  MemberPhotoService? _photoService;
  ProgressPhotoPicker? _picker;
  List<JournalEntry> _entries = const [];
  List<JournalChartPoint> _chart = const [];
  String? _error;
  String? _accessError;
  bool _loading = true;
  bool _canWrite = false;
  bool _hasMore = false;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberJournalService>();
    _membershipService =
        widget.membershipService ?? context.read<MembershipService>();
    _photoService = widget.photoService ?? context.read<MemberPhotoService>();
    _picker = widget.picker ?? DeviceProgressPhotoPicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool more = false}) async {
    if (more && (!_hasMore || _loading)) return;
    setState(() {
      _loading = true;
      _error = null;
      _accessError = null;
      if (!more) {
        _entries = const [];
        _chart = const [];
        _page = 0;
      }
    });
    try {
      final page = await _service!.getPage(_page + 1);
      if (more) {
        if (!mounted) return;
        setState(() {
          _entries = [..._entries, ...page];
          _page++;
          _hasMore = page.length == 20;
        });
      } else {
        final chart = await _service!.getChart();
        var canWrite = false;
        String? accessError;
        try {
          final memberships = await _membershipService!.getCurrentMemberships();
          canWrite = memberships.any((item) => item.status == 'ACTIVE');
        } catch (_) {
          accessError =
              'Không kiểm tra được gói tập. Nhật ký tạm thời chỉ xem.';
        }
        if (!mounted) return;
        setState(() {
          _entries = page;
          _chart = chart;
          _page = 1;
          _hasMore = page.length == 20;
          _canWrite = canWrite;
          _accessError = accessError;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được nhật ký tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([JournalEntry? entry]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _JournalEditor(
          service: _service!,
          photoService: _photoService!,
          picker: _picker!,
          entry: entry,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete(JournalEntry entry) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2B2622),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xB7B3A99D), width: 1.1),
        ),
        title: const Text(
          'Xóa nhật ký?',
          style: TextStyle(
            color: Color(0xFFF7F9FC),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Nhật ký ngày ${_dateLabel(entry.journalDate)} sẽ bị xóa.',
          style: const TextStyle(color: Color(0xFFEAE6E2)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Giữ lại',
              style: TextStyle(color: Color(0xFFB7B2AF)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF15B64),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await _service!.delete(entry.id);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.scaffoldBackground,
    floatingActionButton: _canWrite
        ? FloatingActionButton.extended(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Ghi hôm nay',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          )
        : null,
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
                    if (Navigator.of(context).canPop()) ...[
                      MetaGymCircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NHẬT KÝ CÁ NHÂN',
                            style: TextStyle(
                              color: Color(0xFFB7B2AF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Nhật ký tập luyện',
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
                      onTap: _loading ? null : () => _load(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: MetaGymTheme.brandOrange,
                  backgroundColor: const Color(0xFF2B2622),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                    children: [
                      if (_loading && _entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.brandOrange,
                            ),
                          ),
                        ),
                      if (_error != null) ...[
                        MetaGymGlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFF15B64),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF857D),
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text(
                                  'Thử lại',
                                  style: TextStyle(
                                    color: MetaGymTheme.brandOrange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_accessError != null)
                        MetaGymGlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _accessError!,
                            style: const TextStyle(
                              color: Color(0xFFFF857D),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if (!_loading && _error == null && !_canWrite)
                        const MetaGymGlassCard(
                          margin: EdgeInsets.only(bottom: 16),
                          padding: EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFFF2A93B),
                                size: 18,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Bạn có thể xem nhật ký cũ. Cần gói tập đang hoạt động để ghi hoặc sửa.',
                                  style: TextStyle(
                                    color: Color(0xFFEAE6E2),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_loading && _error == null && _entries.isEmpty)
                        const MetaGymHeroGlassCard(
                          margin: EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.menu_book_rounded,
                                    color: MetaGymTheme.brandOrange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Chưa có nhật ký tập.',
                                    style: TextStyle(
                                      color: Color(0xFFF7F9FC),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Ghi buổi tập đầu tiên để theo dõi quá trình của bạn.',
                                style: TextStyle(
                                  color: Color(0xFFB7B2AF),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_chart.isNotEmpty) ...[
                        MetaGymHeroGlassCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.show_chart_rounded,
                                    color: MetaGymTheme.brandOrange,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Ba vòng cơ thể',
                                    style: TextStyle(
                                      color: Color(0xFFF7F9FC),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _JournalChart(points: _chart),
                            ],
                          ),
                        ),
                      ],
                      for (final entry in _entries) ...[
                        MetaGymGlassCard(
                          featured: true,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0x24FF5A36),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today_rounded,
                                      color: MetaGymTheme.brandOrange,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _dateLabel(entry.journalDate),
                                      style: const TextStyle(
                                        color: Color(0xFFF7F9FC),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x80211E1C),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0x9A8C8176),
                                      ),
                                    ),
                                    child: Text(
                                      '${entry.achievements.length} thành tích · ${entry.photoMediaIds.length} ảnh',
                                      style: const TextStyle(
                                        color: Color(0xFFEAE6E2),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (entry.notes?.isNotEmpty == true) ...[
                                const SizedBox(height: 10),
                                Text(
                                  entry.notes!,
                                  style: const TextStyle(
                                    color: Color(0xFFF7F9FC),
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (entry.chestCm != null ||
                                  entry.waistCm != null ||
                                  entry.hipsCm != null) ...[
                                const SizedBox(height: 10),
                                MetaGymMetricPanel(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.straighten_rounded,
                                        color: Color(0xFF8EB9E5),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Ngực ${entry.chestCm ?? '—'} · Eo ${entry.waistCm ?? '—'} · Mông ${entry.hipsCm ?? '—'} cm',
                                          style: const TextStyle(
                                            color: Color(0xFFEAE6E2),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (entry.achievements.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                for (final achievement in entry.achievements)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: MetaGymMetricPanel(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.emoji_events_outlined,
                                            color: MetaGymTheme.progressGreen,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${achievement.title}: ${achievement.result}',
                                              style: const TextStyle(
                                                color: Color(0xFFF7F9FC),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                              if (entry.photoMediaIds.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final id in entry.photoMediaIds)
                                      _JournalPhoto(
                                        id: id,
                                        service: _photoService!,
                                      ),
                                  ],
                                ),
                              ],
                              if (_canWrite) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _openEditor(entry),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            MetaGymTheme.brandOrange,
                                      ),
                                      child: const Text(
                                        'Sửa',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _delete(entry),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFF15B64,
                                        ),
                                      ),
                                      child: const Text(
                                        'Xóa',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (_hasMore && !_loading)
                        Center(
                          child: TextButton(
                            onPressed: () => _load(more: true),
                            style: TextButton.styleFrom(
                              foregroundColor: MetaGymTheme.brandOrange,
                            ),
                            child: const Text(
                              'Tải thêm',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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

String _dateLabel(String day) {
  final parts = day.split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : day;
}

class _JournalPhoto extends StatefulWidget {
  const _JournalPhoto({required this.id, required this.service});
  final String id;
  final MemberPhotoService service;

  @override
  State<_JournalPhoto> createState() => _JournalPhotoState();
}

class _JournalPhotoState extends State<_JournalPhoto> {
  late Future<Uri> _accessUrl;

  @override
  void initState() {
    super.initState();
    _accessUrl = widget.service.getAccessUrl(widget.id);
  }

  @override
  void didUpdateWidget(covariant _JournalPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.service != widget.service) {
      _accessUrl = widget.service.getAccessUrl(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uri>(
    future: _accessUrl,
    builder: (context, snapshot) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0x80211E1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x9A8C8176)),
        ),
        child: snapshot.hasData
            ? Image.network(
                snapshot.data.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFFB7B2AF),
                ),
              )
            : const Icon(Icons.image_outlined, color: Color(0xFFB7B2AF)),
      ),
    ),
  );
}

class _JournalChart extends StatelessWidget {
  const _JournalChart({required this.points});
  final List<JournalChartPoint> points;

  static const _chestColor = Color(0xFFFF5E36);
  static const _waistColor = Color(0xFF70AEE8);
  static const _hipsColor = Color(0xFF2ECC71);

  double? _latestValue(double? Function(JournalChartPoint) selector) {
    for (var i = points.length - 1; i >= 0; i--) {
      final v = selector(points[i]);
      if (v != null) return v;
    }
    return null;
  }

  double? _deltaValue(double? Function(JournalChartPoint) selector) {
    double? latest;
    for (var i = points.length - 1; i >= 0; i--) {
      final v = selector(points[i]);
      if (v != null) {
        if (latest == null) {
          latest = v;
        } else {
          return latest - v;
        }
      }
    }
    return null;
  }

  String _shortDate(String iso) {
    final parts = iso.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}' : iso;
  }

  @override
  Widget build(BuildContext context) {
    final latestChest = _latestValue((p) => p.chestCm);
    final latestWaist = _latestValue((p) => p.waistCm);
    final latestHips = _latestValue((p) => p.hipsCm);

    final deltaChest = _deltaValue((p) => p.chestCm);
    final deltaWaist = _deltaValue((p) => p.waistCm);
    final deltaHips = _deltaValue((p) => p.hipsCm);

    final values = <double>[?latestChest, ?latestWaist, ?latestHips];
    final maxBarValue = values.isEmpty
        ? 100.0
        : values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return MetaGymMetricPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _BodyMetricTile(
                  label: 'Ngực',
                  color: _chestColor,
                  value: latestChest,
                  delta: deltaChest,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BodyMetricTile(
                  label: 'Eo',
                  color: _waistColor,
                  value: latestWaist,
                  delta: deltaWaist,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BodyMetricTile(
                  label: 'Mông',
                  color: _hipsColor,
                  value: latestHips,
                  delta: deltaHips,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (points.length <= 1) ...[
            _SingleDayComparisonBar(
              label: 'Vòng ngực',
              color: _chestColor,
              value: latestChest,
              maxValue: maxBarValue,
            ),
            const SizedBox(height: 5),
            _SingleDayComparisonBar(
              label: 'Vòng eo',
              color: _waistColor,
              value: latestWaist,
              maxValue: maxBarValue,
            ),
            const SizedBox(height: 5),
            _SingleDayComparisonBar(
              label: 'Vòng mông',
              color: _hipsColor,
              value: latestHips,
              maxValue: maxBarValue,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: Color(0xFFB7B2AF),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    points.isEmpty
                        ? 'Chưa có số đo 3 vòng.'
                        : 'Số đo ngày ${_shortDate(points.last.journalDate)} · Ghi thêm từ ngày thứ 2 để xem đường xu hướng',
                    style: const TextStyle(
                      color: Color(0xFFB7B2AF),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              height: 105,
              width: double.infinity,
              child: CustomPaint(painter: _JournalChartPainter(points)),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _shortDate(points.first.journalDate),
                  style: const TextStyle(
                    color: Color(0xFFB7B2AF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (points.length >= 3)
                  Text(
                    _shortDate(points[points.length ~/ 2].journalDate),
                    style: const TextStyle(
                      color: Color(0xFFB7B2AF),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  _shortDate(points.last.journalDate),
                  style: const TextStyle(
                    color: Color(0xFFB7B2AF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Wrap(
              spacing: 16,
              children: [
                _ChartLegend('Ngực', _chestColor),
                _ChartLegend('Eo', _waistColor),
                _ChartLegend('Mông', _hipsColor),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BodyMetricTile extends StatelessWidget {
  const _BodyMetricTile({
    required this.label,
    required this.color,
    required this.value,
    required this.delta,
  });

  final String label;
  final Color color;
  final double? value;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    String deltaText = 'Mới';
    Color deltaColor = const Color(0xFFB7B2AF);
    if (value == null) {
      deltaText = '—';
    } else if (delta != null) {
      if (delta!.abs() < 0.05) {
        deltaText = '±0.0';
      } else if (delta! > 0) {
        deltaText = '+${delta!.toStringAsFixed(1)}';
        deltaColor = const Color(0xFF2ECC71);
      } else {
        deltaText = delta!.toStringAsFixed(1);
        deltaColor = const Color(0xFF70AEE8);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF26221F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFEAE6E2),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                deltaText,
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 9.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value != null ? '${value!.toStringAsFixed(1)} cm' : '—',
            style: const TextStyle(
              color: Color(0xFFF7F9FC),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SingleDayComparisonBar extends StatelessWidget {
  const _SingleDayComparisonBar({
    required this.label,
    required this.color,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final Color color;
  final double? value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final ratio = value == null ? 0.0 : (value! / maxValue).clamp(0.08, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFEAE6E2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value != null ? '${value!.toStringAsFixed(1)} cm' : 'Chưa nhập',
              style: TextStyle(
                color: value != null
                    ? const Color(0xFFF7F9FC)
                    : const Color(0xFFB7B2AF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 5.5,
            width: double.infinity,
            color: const Color(0xFF2A2521),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio,
              child: Container(
                height: 5.5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFEAE6E2),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _JournalChartPainter extends CustomPainter {
  const _JournalChartPainter(this.points);
  final List<JournalChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final all = <double>[
      for (final point in points) ...[
        if (point.chestCm != null) point.chestCm!,
        if (point.waistCm != null) point.waistCm!,
        if (point.hipsCm != null) point.hipsCm!,
      ],
    ];
    if (all.isEmpty) return;
    var min = all.first;
    var max = all.first;
    for (final value in all) {
      if (value < min) min = value;
      if (value > max) max = value;
    }
    final range = max == min ? 1.0 : max - min;
    const leftPad = 38.0;
    const rightPad = 10.0;
    const topPad = 10.0;
    const bottomPad = 10.0;
    final width = (size.width - leftPad - rightPad).clamp(10.0, size.width);
    final height = (size.height - topPad - bottomPad).clamp(10.0, size.height);

    // Vẽ 3 đường lưới ngang (Max, Mid, Min) kèm nhãn số đo cm bên trái
    final gridPaint = Paint()
      ..color = const Color(0x2E9A8C81)
      ..strokeWidth = 0.8;
    final gridLevels = <double>[max, (max + min) / 2, min];
    for (var i = 0; i < gridLevels.length; i++) {
      final y = topPad + height * (i / (gridLevels.length - 1));
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + width, y),
        gridPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: gridLevels[i].toStringAsFixed(0),
          style: const TextStyle(
            color: Color(0xFFB7B2AF),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPad - 4);
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // Vẽ đường và chấm tròn với bán kính khác nhau để không bao giờ che khuất nhau khi 2 chỉ số bằng nhau
    void series(
      Color color,
      double dotRadius,
      double? Function(JournalChartPoint) get,
    ) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke;
      final dots = Paint()..color = color;
      final dotBorder = Paint()
        ..color = const Color(0xFF1F1C1A)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final path = Path();
      var started = false;
      for (var index = 0; index < points.length; index++) {
        final value = get(points[index]);
        if (value == null) continue;
        final x =
            leftPad +
            (points.length == 1
                ? width / 2
                : width * index / (points.length - 1));
        final y = topPad + height * (1 - (value - min) / range);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
      for (var index = 0; index < points.length; index++) {
        final value = get(points[index]);
        if (value == null) continue;
        final x =
            leftPad +
            (points.length == 1
                ? width / 2
                : width * index / (points.length - 1));
        final y = topPad + height * (1 - (value - min) / range);
        canvas.drawCircle(Offset(x, y), dotRadius, dots);
        canvas.drawCircle(Offset(x, y), dotRadius, dotBorder);
      }
    }

    series(const Color(0xFFFF5E36), 6.0, (point) => point.chestCm);
    series(const Color(0xFF70AEE8), 4.3, (point) => point.waistCm);
    series(const Color(0xFF2ECC71), 2.8, (point) => point.hipsCm);
  }

  @override
  bool shouldRepaint(covariant _JournalChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _JournalEditor extends StatefulWidget {
  const _JournalEditor({
    required this.service,
    required this.photoService,
    required this.picker,
    this.entry,
  });

  final MemberJournalService service;
  final MemberPhotoService photoService;
  final ProgressPhotoPicker picker;
  final JournalEntry? entry;

  @override
  State<_JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<_JournalEditor> {
  final _notes = TextEditingController();
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _hips = TextEditingController();
  final _achievements = TextEditingController();
  final _newImages = <SelectedProgressImage>[];
  final _uploadedIds = <String>[];
  List<String> _existingPhotos = const [];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry == null) return;
    _notes.text = entry.notes ?? '';
    _chest.text = entry.chestCm?.toString() ?? '';
    _waist.text = entry.waistCm?.toString() ?? '';
    _hips.text = entry.hipsCm?.toString() ?? '';
    _achievements.text = entry.achievements
        .map((item) => '${item.title} | ${item.result}')
        .join('\n');
    _existingPhotos = List.of(entry.photoMediaIds);
  }

  @override
  void dispose() {
    _notes.dispose();
    _chest.dispose();
    _waist.dispose();
    _hips.dispose();
    _achievements.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_existingPhotos.length + _newImages.length >= 3) return;
    try {
      final image = await widget.picker.pick();
      if (image == null || !mounted) return;
      final validation = validateProgressImage(image);
      if (validation != null) {
        setState(() => _error = validation);
        return;
      }
      setState(() {
        _newImages.add(image);
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Không chọn được ảnh. Hãy thử lại.');
    }
  }

  double? _readMeasurement(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : double.tryParse(value.replaceAll(',', '.'));
  }

  Future<void> _save() async {
    if (_saving) return;
    final numbers = [
      _readMeasurement(_chest),
      _readMeasurement(_waist),
      _readMeasurement(_hips),
    ];
    final inputs = [_chest, _waist, _hips];
    if (List.generate(
      3,
      (index) =>
          inputs[index].text.trim().isNotEmpty &&
          (numbers[index] == null ||
              numbers[index]! <= 0 ||
              numbers[index]! > 9999.99),
    ).contains(true)) {
      setState(() => _error = 'Số đo phải lớn hơn 0 và không quá 9999,99 cm.');
      return;
    }
    final achievements = <Map<String, String>>[];
    for (final line in _achievements.text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final separator = line.indexOf('|');
      if (separator < 1 || separator == line.length - 1) {
        setState(() => _error = 'Mỗi thành tích cần dạng: Tên | Kết quả.');
        return;
      }
      final title = line.substring(0, separator).trim();
      final result = line.substring(separator + 1).trim();
      if (title.isEmpty ||
          result.isEmpty ||
          title.length > 150 ||
          result.length > 1000) {
        setState(() => _error = 'Tên hoặc kết quả thành tích không hợp lệ.');
        return;
      }
      achievements.add({'title': title, 'result': result});
    }
    if (_notes.text.trim().length > 5000) {
      setState(() => _error = 'Ghi chú tối đa 5000 ký tự.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      for (
        var index = _uploadedIds.length;
        index < _newImages.length;
        index++
      ) {
        _uploadedIds.add(await widget.photoService.upload(_newImages[index]));
      }
      final payload = <String, Object?>{
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'chestCm': numbers[0],
        'waistCm': numbers[1],
        'hipsCm': numbers[2],
        'achievements': achievements,
        'photoMediaIds': [..._existingPhotos, ..._uploadedIds],
      };
      if (widget.entry == null) {
        await widget.service.create(payload);
      } else {
        await widget.service.update(widget.entry!.id, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không lưu được nhật ký. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _darkInputDecoration({
    String? labelText,
    String? hintText,
    String? helperText,
  }) => InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    filled: true,
    fillColor: const Color(0xFF211E1C),
    labelStyle: const TextStyle(
      color: Color(0xFFB7B2AF),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    floatingLabelStyle: const TextStyle(
      color: MetaGymTheme.brandOrange,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: const TextStyle(
      color: Color(0xFF8C847E),
      fontSize: 13.5,
      height: 1.4,
    ),
    helperStyle: const TextStyle(color: Color(0xFFB7B2AF), fontSize: 11.5),
    counterStyle: const TextStyle(color: Color(0xFFB7B2AF), fontSize: 11.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0x529A8C81)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0x529A8C81)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.4),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
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
                    Expanded(
                      child: Text(
                        widget.entry == null
                            ? 'Ghi nhật ký hôm nay'
                            : 'Sửa nhật ký ${_dateLabel(widget.entry!.journalDate)}',
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Ngày ghi được xác định tự động theo giờ phòng tập.',
                      style: TextStyle(
                        color: Color(0xFFB7B2AF),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MetaGymGlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nội dung buổi tập',
                            style: TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notes,
                            maxLines: 3,
                            maxLength: 5000,
                            cursorColor: MetaGymTheme.brandOrange,
                            style: const TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _darkInputDecoration(
                              labelText: 'Hôm nay bạn đã tập gì?',
                              hintText: 'Ví dụ: Tập ngực, hít đất 4 hiệp, chạy bộ 20 phút...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    MetaGymGlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Số đo tùy chọn (cm)',
                            style: TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              for (final (label, controller) in [
                                ('Ngực', _chest),
                                ('Eo', _waist),
                                ('Mông', _hips),
                              ]) ...[
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    cursorColor: MetaGymTheme.brandOrange,
                                    style: const TextStyle(
                                      color: Color(0xFFF7F9FC),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: _darkInputDecoration(
                                      labelText: label,
                                      hintText: 'cm',
                                    ),
                                  ),
                                ),
                                if (label != 'Mông') const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    MetaGymGlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thành tích',
                            style: TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _achievements,
                            maxLines: 5,
                            cursorColor: MetaGymTheme.brandOrange,
                            style: const TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _darkInputDecoration(
                              hintText: 'Hít đất | 20 lần\nChạy bộ | 3 km',
                              helperText: 'Mỗi dòng là một mục: Tên | Kết quả',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    MetaGymGlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ảnh (tối đa 3)',
                            style: TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final id in _existingPhotos)
                                InputChip(
                                  backgroundColor: const Color(0xFF26221F),
                                  side: const BorderSide(
                                    color: Color(0x529A8C81),
                                  ),
                                  deleteIconColor: const Color(0xFFB7B2AF),
                                  label: const Text(
                                    'Ảnh đã lưu',
                                    style: TextStyle(color: Color(0xFFF7F9FC)),
                                  ),
                                  onDeleted: _saving
                                      ? null
                                      : () => setState(
                                          () => _existingPhotos.remove(id),
                                        ),
                                ),
                              for (final image in _newImages)
                                InputChip(
                                  backgroundColor: const Color(0xFF26221F),
                                  side: const BorderSide(
                                    color: Color(0x529A8C81),
                                  ),
                                  deleteIconColor: const Color(0xFFB7B2AF),
                                  avatar: Image.memory(
                                    image.bytes,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                  ),
                                  label: Text(
                                    image.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFF7F9FC),
                                    ),
                                  ),
                                  onDeleted: _saving
                                      ? null
                                      : () => setState(() {
                                          final index = _newImages.indexOf(
                                            image,
                                          );
                                          _newImages.removeAt(index);
                                          if (index < _uploadedIds.length) {
                                            _uploadedIds.removeAt(index);
                                          }
                                        }),
                                ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed:
                                _saving ||
                                    _existingPhotos.length +
                                            _newImages.length >=
                                        3
                                ? null
                                : _pickPhoto,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: MetaGymTheme.brandOrange,
                            ),
                            label: const Text(
                              'Thêm ảnh',
                              style: TextStyle(
                                color: MetaGymTheme.brandOrange,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFF15B64)),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: MetaGymTheme.brandOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Đang lưu…' : 'Lưu nhật ký',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
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
