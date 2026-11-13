import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/training/data/gym_visits_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

/// QR attendance is operational history, independent of the private journal
/// and the sessions booked with a Coach.
class GymVisitsPage extends StatefulWidget {
  const GymVisitsPage({this.api, super.key});
  final GymVisitsApi? api;

  @override
  State<GymVisitsPage> createState() => _GymVisitsPageState();
}

class _GymVisitsPageState extends State<GymVisitsPage> {
  GymVisitsApi? _api;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  GymVisitMonth? _data;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    _api = widget.api ?? GymVisitsApi(context.read<ApiClient>());
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _load(); });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api!.getMonth(_month);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch sử đến gym.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _moveMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    setState(() { _month = next; _data = null; });
    _load();
  }

  Future<void> _scan() async {
    final visited = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _GymQrScanner(api: _api!),
    ));
    if (visited == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canGoForward = _month.isBefore(DateTime(now.year, now.month));
    final data = _data;
    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      appBar: AppBar(title: const Text('Lịch sử đến gym'), centerTitle: true,
        backgroundColor: MetaGymTheme.scaffoldBackground),
      body: RefreshIndicator(onRefresh: _load, color: MetaGymTheme.primary,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          physics: const AlwaysScrollableScrollPhysics(), children: [
          _surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Lịch đến gym', style: TextStyle(
                color: MetaGymTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w600))),
              IconButton(onPressed: () => _moveMonth(-1), tooltip: 'Tháng trước',
                icon: const Icon(Icons.chevron_left, color: MetaGymTheme.textPrimary)),
              Text(DateFormat('MM/yyyy').format(_month), style: const TextStyle(
                color: MetaGymTheme.textPrimary, fontWeight: FontWeight.w600)),
              IconButton(onPressed: canGoForward ? () => _moveMonth(1) : null,
                tooltip: 'Tháng sau', icon: const Icon(Icons.chevron_right)),
            ]),
            if (_loading) const Padding(padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator(color: MetaGymTheme.primary)))
            else if (_error != null) TextButton.icon(onPressed: _load,
              icon: const Icon(Icons.refresh), label: Text('$_error Thử lại'))
            else if (data != null) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _stat('Đã đến gym', data.visitedDays, MetaGymTheme.primary)),
                const SizedBox(width: 10),
                Expanded(child: _stat('Ngày chưa đến',
                  (data.eligibleDays - data.visitedDays).clamp(0, 31),
                  MetaGymTheme.textSecondary)),
              ]),
              const SizedBox(height: 18),
              _calendar(data),
              const SizedBox(height: 10),
              const Text('Ngày chưa đến chỉ tính khi gói tập có hiệu lực.',
                style: TextStyle(color: MetaGymTheme.textSecondary, fontSize: 12)),
            ],
          ])),
          const SizedBox(height: 20),
          const Text('Các lần đến gym', style: TextStyle(color: MetaGymTheme.textPrimary,
            fontSize: 19, fontWeight: FontWeight.w600)),
          if (data != null && !_loading && _error == null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(
              '${data.entryCount} lượt quét trong tháng · Có thể vào nhiều lần mỗi ngày',
              style: const TextStyle(color: MetaGymTheme.textSecondary, fontSize: 12))),
          const SizedBox(height: 12),
          if (!_loading && _error == null && data != null && data.visits.isEmpty)
            _surface(child: const Text('Chưa có lượt đến gym trong tháng này.',
              style: TextStyle(color: MetaGymTheme.textSecondary)))
          else if (data != null && !_loading && _error == null)
            ...data.visits.map((visit) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _surface(child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined, color: MetaGymTheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('dd/MM/yyyy').format(visit.day),
                        style: const TextStyle(color: MetaGymTheme.textPrimary,
                          fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('${DateFormat('HH:mm').format(visit.checkedInAt.toLocal())} · ${visit.gymName}',
                        style: const TextStyle(color: MetaGymTheme.textPrimary, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(visit.gymAddress, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: MetaGymTheme.textSecondary, fontSize: 12)),
                    ])),
                ])),
            )),
        ])),
      bottomNavigationBar: SafeArea(minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(onPressed: _scan,
          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
          label: const Text('Quét QR tại phòng gym', style: TextStyle(color: Colors.white)),
          style: FilledButton.styleFrom(backgroundColor: MetaGymTheme.primary,
            minimumSize: const Size.fromHeight(50)))),
    );
  }

  Widget _calendar(GymVisitMonth data) {
    final first = DateTime(_month.year, _month.month);
    final leading = first.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final visits = data.visits.map((v) => v.day.day).toSet();
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    return Column(children: [
      Row(children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
        .map((label) => Expanded(child: Center(child: Text(label,
          style: const TextStyle(color: MetaGymTheme.textSecondary, fontSize: 12)))))
        .toList()),
      const SizedBox(height: 8),
      ...List.generate(((leading + days) / 7).ceil(), (week) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: List.generate(7, (weekday) {
          final day = week * 7 + weekday - leading + 1;
          if (day < 1 || day > days) return const Expanded(child: SizedBox(height: 44));
          final visited = visits.contains(day);
          final future = isCurrentMonth && day > now.day;
          final today = isCurrentMonth && day == now.day;
          return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(height: 44, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: visited ? MetaGymTheme.primary :
                  future ? MetaGymTheme.darkCanvasElevated : MetaGymTheme.elevatedSurface,
                border: Border.all(color: today ? MetaGymTheme.reflectionBlue :
                  MetaGymTheme.cardBorder),
                borderRadius: BorderRadius.circular(9)),
              child: Text('$day', style: TextStyle(
                color: future ? MetaGymTheme.textSecondary : MetaGymTheme.textPrimary,
                fontWeight: visited || today ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13)))));
        })),
      )),
    ]);
  }

  Widget _stat(String label, int value, Color accent) => Container(
    padding: const EdgeInsets.all(13), decoration: BoxDecoration(
      color: MetaGymTheme.elevatedSurface, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: MetaGymTheme.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: MetaGymTheme.textSecondary, fontSize: 12)),
      const SizedBox(height: 6),
      Text('$value', style: TextStyle(color: accent, fontSize: 25, fontWeight: FontWeight.w700)),
    ]));
}

Widget _surface({required Widget child}) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: MetaGymTheme.cardSurface,
    border: Border.all(color: MetaGymTheme.cardBorder),
    borderRadius: BorderRadius.circular(20)), child: child);

class _GymQrScanner extends StatefulWidget {
  const _GymQrScanner({required this.api});
  final GymVisitsApi api;
  @override
  State<_GymQrScanner> createState() => _GymQrScannerState();
}

class _GymQrScannerState extends State<_GymQrScanner> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode]);
  bool _busy = false;
  bool _completed = false;
  String? _error;

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _controller.stop();
      await widget.api.checkIn(code);
      if (!mounted) return;
      _completed = true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã ghi nhận lượt đến gym hôm nay.')));
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể điểm danh. Hãy thử lại.');
    } finally {
      if (mounted && !_completed) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.scaffoldBackground,
    appBar: AppBar(title: const Text('Quét mã tại quầy')),
    body: Stack(children: [
      MobileScanner(controller: _controller, onDetect: _detected,
        errorBuilder: (context, error) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Không mở được camera. Hãy cấp quyền camera rồi thử lại.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: MetaGymTheme.textPrimary))))),
      Align(alignment: Alignment.bottomCenter,
        child: Container(width: double.infinity, padding: const EdgeInsets.all(20),
          color: MetaGymTheme.cardSurface,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Đưa mã QR tại quầy vào khung hình.',
              style: TextStyle(color: MetaGymTheme.textPrimary)),
            if (_busy) const Padding(padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: MetaGymTheme.primary)),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10),
              child: Column(children: [
                Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: MetaGymTheme.warning)),
                TextButton(onPressed: () async {
                  setState(() => _error = null);
                  try { await _controller.start(); }
                  catch (_) {
                    if (mounted) setState(() => _error = 'Không mở được camera. Hãy thử lại.');
                  }
                }, child: const Text('Quét lại')),
              ])),
          ]))),
    ]),
  );
}
