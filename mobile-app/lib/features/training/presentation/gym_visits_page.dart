import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/training/data/gym_visits_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

/// Màn hình Điểm danh QR (Lịch sử đến gym) đồng bộ bảng màu & định dạng thẻ
/// với Trang chủ Hội viên (`member_dashboard_view.dart`) và Hồ sơ (`profile_page.dart`).
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
    setState(() {
      _month = next;
      _data = null;
    });
    _load();
  }

  Future<void> _scan() async {
    final visited = await MetaGymNavigation.pushOnce<bool>(
      context,
      MetaGymPageRoute(builder: (_) => _GymQrScanner(api: _api!)),
    );
    if (visited == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canGoForward = _month.isBefore(DateTime(now.year, now.month));
    final data = _data;

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
                              'ĐIỂM DANH QR',
                              style: TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Lịch sử đến gym',
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
                        onTap: _loading ? null : _load,
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        MetaGymHeroGlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    color: MetaGymTheme.brandOrange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Lịch đến gym',
                                      style: TextStyle(
                                        color: Color(0xFFF7F9FC),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x80211E1C),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0x9A8C8176),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 44,
                                            minHeight: 44,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _moveMonth(-1),
                                          tooltip: 'Tháng trước',
                                          icon: const Icon(
                                            Icons.chevron_left_rounded,
                                            color: Color(0xFFF7F9FC),
                                            size: 20,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          child: Text(
                                            DateFormat('MM/yyyy')
                                                .format(_month),
                                            style: const TextStyle(
                                              color: Color(0xFFF7F9FC),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              fontFeatures:
                                                  MetaGymTheme.tabularFigures,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 44,
                                            minHeight: 44,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: canGoForward
                                              ? () => _moveMonth(1)
                                              : null,
                                          tooltip: 'Tháng sau',
                                          icon: Icon(
                                            Icons.chevron_right_rounded,
                                            color: canGoForward
                                                ? const Color(0xFFF7F9FC)
                                                : const Color(0x55B7B2AF),
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (_loading)
                                const Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: MetaGymTheme.brandOrange,
                                    ),
                                  ),
                                )
                              else if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: MetaGymMetricPanel(
                                    onTap: _load,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.refresh_rounded,
                                          color: MetaGymTheme.brandOrange,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '$_error · Chạm để thử lại',
                                            style: const TextStyle(
                                              color: Color(0xFFEAE6E2),
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (data != null) ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _stat(
                                        'Đã đến gym',
                                        data.visitedDays,
                                        MetaGymTheme.brandOrange,
                                        Icons.bolt_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _stat(
                                        'Ngày chưa đến',
                                        (data.eligibleDays - data.visitedDays)
                                            .clamp(0, 31),
                                        const Color(0xFFEAE6E2),
                                        Icons.event_busy_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _calendar(data),
                                const SizedBox(height: 10),
                                const Text(
                                  'Ngày chưa đến chỉ tính khi gói tập có hiệu lực.',
                                  style: TextStyle(
                                    color: Color(0xFFB7B2AF),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              color: MetaGymTheme.brandOrange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Các lần đến gym',
                                style: TextStyle(
                                  color: Color(0xFFF7F9FC),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (data != null && !_loading && _error == null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x262ECC71),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0x4D2ECC71),
                                  ),
                                ),
                                child: Text(
                                  '${data.entryCount} lượt quét',
                                  style: const TextStyle(
                                    color: MetaGymTheme.progressGreen,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (data != null && !_loading && _error == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${data.entryCount} lượt quét trong tháng · Có thể vào nhiều lần mỗi ngày',
                              style: const TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (!_loading &&
                            _error == null &&
                            data != null &&
                            data.visits.isEmpty)
                          const MetaGymGlassCard(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Color(0xFFB7B2AF),
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Chưa có lượt đến gym trong tháng này.',
                                    style: TextStyle(
                                      color: Color(0xFFEAE6E2),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (data != null && !_loading && _error == null)
                          ...data.visits.map(
                            (visit) => MetaGymGlassCard(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0x24FF5A36),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0x4DFF5A36),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.place_outlined,
                                      color: MetaGymTheme.brandOrange,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('dd/MM/yyyy')
                                              .format(visit.day),
                                          style: const TextStyle(
                                            color: Color(0xFFF7F9FC),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${DateFormat('HH:mm').format(visit.checkedInAt.toLocal())} · ${visit.gymName}',
                                          style: const TextStyle(
                                            color: Color(0xFFEAE6E2),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          visit.gymAddress,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFB7B2AF),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _scan,
          icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
          label: const Text(
            'Quét QR tại phòng gym',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendar(GymVisitMonth data) {
    final first = DateTime(_month.year, _month.month);
    final leading = first.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final visits = data.visits.map((v) => v.day.day).toSet();
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;
    return Column(
      children: [
        Row(
          children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFB7B2AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate(
          ((leading + days) / 7).ceil(),
          (week) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: List.generate(7, (weekday) {
                final day = week * 7 + weekday - leading + 1;
                if (day < 1 || day > days) {
                  return const Expanded(child: SizedBox(height: 42));
                }
                final visited = visits.contains(day);
                final future = isCurrentMonth && day > now.day;
                final today = isCurrentMonth && day == now.day;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: visited
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFF6D3F), Color(0xFFFF4F2B)],
                              )
                            : null,
                        color: visited
                            ? null
                            : future
                            ? const Color(0x4D211E1C)
                            : const Color(0x80211E1C),
                        border: Border.all(
                          color: today
                              ? const Color(0xFF8EB9E5)
                              : visited
                              ? const Color(0xFFFF8566)
                              : const Color(0x9A8C8176),
                          width: today ? 1.4 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: visited
                              ? Colors.white
                              : future
                              ? const Color(0x77B7B2AF)
                              : const Color(0xFFF7F9FC),
                          fontWeight: visited || today
                              ? FontWeight.w800
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, int value, Color accent, IconData icon) =>
      MetaGymMetricPanel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB7B2AF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: TextStyle(
                color: accent,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.05,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ],
        ),
      );
}

class _GymQrScanner extends StatefulWidget {
  const _GymQrScanner({required this.api});
  final GymVisitsApi api;
  @override
  State<_GymQrScanner> createState() => _GymQrScannerState();
}

class _GymQrScannerState extends State<_GymQrScanner> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _busy = false;
  bool _completed = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _controller.stop();
      await widget.api.checkIn(code);
      if (!mounted) return;
      _completed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã ghi nhận lượt đến gym hôm nay.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể điểm danh. Hãy thử lại.');
      }
    } finally {
      if (mounted && !_completed) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MetaGymTheme.scaffoldBackground,
    appBar: AppBar(
      title: const Text('Quét mã tại quầy'),
      backgroundColor: const Color(0xFF211E1C),
      foregroundColor: const Color(0xFFF7F9FC),
    ),
    body: Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _detected,
          errorBuilder: (context, error) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Không mở được camera. Hãy cấp quyền camera rồi thử lại.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFF7F9FC)),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MetaGymHeroGlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Đưa mã QR tại quầy vào khung hình.',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.brandOrange,
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: MetaGymTheme.warning),
                          ),
                          TextButton(
                            onPressed: () async {
                              setState(() => _error = null);
                              try {
                                await _controller.start();
                              } catch (_) {
                                if (mounted) {
                                  setState(
                                    () => _error =
                                        'Không mở được camera. Hãy thử lại.',
                                  );
                                }
                              }
                            },
                            child: const Text('Quét lại'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
