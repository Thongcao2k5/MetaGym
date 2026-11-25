import 'dart:async';

import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/domain/journal_entry.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:meta_gym_app/features/progress/presentation/member_measurement_page.dart';
import 'package:provider/provider.dart';

enum _JournalTab { journal, progress }

enum _CalendarMode { week, month }

enum _EditCard { photos, measurements, achievements }

/// Màn hình Nhật ký tập luyện theo bố cục 2 tab (Nhật ký & Số đo & biểu đồ),
/// lịch tuần/tháng, chỉnh sửa inline theo từng thẻ cho ngày hôm nay và
/// khóa chỉ xem đối với các ngày đã qua hoặc khi gói tập không hoạt động.
class MemberJournalPage extends StatefulWidget {
  const MemberJournalPage({
    this.service,
    this.membershipService,
    this.photoService,
    this.measurementService,
    this.progressService,
    this.picker,
    this.todayOverride,
    super.key,
  });

  final MemberJournalService? service;
  final MembershipService? membershipService;
  final MemberPhotoService? photoService;
  final MemberMeasurementService? measurementService;
  final MemberProgressService? progressService;
  final ProgressPhotoPicker? picker;
  final DateTime? todayOverride;

  @override
  State<MemberJournalPage> createState() => _MemberJournalPageState();
}

class _MemberJournalPageState extends State<MemberJournalPage> {
  static const List<String> _starterAchievements = [
    'Đẩy ngực',
    'Kéo lưng',
    'Squat',
  ];
  static const List<String> _weekdayShort = [
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];
  static const List<String> _weekdayFull = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  MemberJournalService? _service;
  MembershipService? _membershipService;
  MemberPhotoService? _photoService;
  MemberMeasurementService? _measurementService;
  MemberProgressService? _progressService;
  ProgressPhotoPicker? _picker;

  List<JournalEntry> _entries = const [];
  List<BodyMeasurement> _measurements = const [];
  ProgressSummary? _summary;
  List<WeightPoint> _weightPoints = const [];
  String _chartRange = '8 tuần';

  bool _loading = true;
  bool _saving = false;
  bool _canWrite = false;
  String? _error;
  String? _accessError;
  String? _saveError;

  _JournalTab _tab = _JournalTab.journal;
  _CalendarMode _calendarMode = _CalendarMode.week;
  late DateTime _selectedDate;
  _EditCard? _openCard;

  // Draft state for today's editable entry
  _DayDraft? _savedDraft;
  _DayDraft? _draft;
  bool _toastVisible = false;
  Timer? _toastTimer;

  DateTime get _today {
    final now = widget.todayOverride ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _today;
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberJournalService>();
    _membershipService =
        widget.membershipService ?? context.read<MembershipService>();
    _photoService = widget.photoService ?? context.read<MemberPhotoService>();
    _measurementService =
        widget.measurementService ?? _tryRead<MemberMeasurementService>();
    _progressService =
        widget.progressService ?? _tryRead<MemberProgressService>();
    _picker = widget.picker ?? DeviceProgressPhotoPicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  T? _tryRead<T>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _accessError = null;
      _saveError = null;
    });
    try {
      final entries = await _service!.getPage(1);
      var canWrite = false;
      String? accessError;
      try {
        final memberships = await _membershipService!.getCurrentMemberships();
        canWrite = memberships.any((item) => item.status == 'ACTIVE');
      } catch (_) {
        accessError = 'Không kiểm tra được gói tập. Nhật ký tạm thời chỉ xem.';
      }

      List<BodyMeasurement> measurements = const [];
      if (_measurementService != null) {
        try {
          measurements = await _measurementService!.getPage(1);
        } catch (_) {}
      }

      ProgressSummary? summary;
      List<WeightPoint> weightPoints = const [];
      if (_progressService != null) {
        try {
          summary = await _progressService!.getSummary();
          weightPoints = await _fetchChartRange(_chartRange);
        } catch (_) {}
      }

      if (!mounted) return;
      final todayEntry = _entryForDate(_today, entries);
      final todayMeasurement = _measurementForDate(_today, measurements);
      final initialDraft = _DayDraft.fromRecords(
        entry: todayEntry,
        measurement: todayMeasurement,
        starterTitles: _starterAchievements,
      );
      setState(() {
        _entries = entries;
        _measurements = measurements;
        _summary = summary;
        _weightPoints = weightPoints;
        _canWrite = canWrite;
        _accessError = accessError;
        _savedDraft = initialDraft;
        _draft = initialDraft.copy();
        _openCard = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được nhật ký tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<WeightPoint>> _fetchChartRange(String range) async {
    if (_progressService == null) return const [];
    final to = _today;
    DateTime? from;
    if (range == '8 tuần') {
      from = to.subtract(const Duration(days: 55));
    } else if (range == '30 ngày') {
      from = to.subtract(const Duration(days: 29));
    }
    return _progressService!.getCharts(from: from, to: to);
  }

  Future<void> _changeChartRange(String range) async {
    setState(() => _chartRange = range);
    if (_progressService == null) return;
    try {
      final points = await _fetchChartRange(range);
      if (mounted) setState(() => _weightPoints = points);
    } catch (_) {}
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _parseIsoDate(String raw) {
    final datePart = raw.split('T').first;
    final parsed = DateTime.tryParse(datePart);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    final local = DateTime.tryParse(raw)?.toLocal();
    return local == null ? null : DateTime(local.year, local.month, local.day);
  }

  JournalEntry? _entryForDate(DateTime date, [List<JournalEntry>? list]) {
    final target = _isoDate(date);
    for (final item in list ?? _entries) {
      if (item.journalDate.split('T').first == target) return item;
    }
    return null;
  }

  BodyMeasurement? _measurementForDate(
    DateTime date, [
    List<BodyMeasurement>? list,
  ]) {
    final target = _isoDate(date);
    for (final item in list ?? _measurements) {
      final parsed = _parseIsoDate(item.measuredAt);
      if (parsed != null && _isoDate(parsed) == target) return item;
    }
    return null;
  }

  bool _hasRecordOnDate(DateTime date) =>
      _entryForDate(date) != null || _measurementForDate(date) != null;

  bool get _isSelectedToday => _isSameDay(_selectedDate, _today);
  bool get _canEditSelectedDay => _isSelectedToday && _canWrite;
  bool get _isDirty =>
      _draft != null && _savedDraft != null && !_draft!.equals(_savedDraft!);

  DateTime _weekMonday(DateTime date) =>
      date.subtract(Duration(days: (date.weekday + 6) % 7));

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
      _openCard = null;
      _saveError = null;
    });
  }

  void _movePeriod(int direction) {
    if (_calendarMode == _CalendarMode.week) {
      _selectDate(_selectedDate.add(Duration(days: direction * 7)));
      return;
    }
    final targetMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + direction,
      1,
    );
    final daysInTarget = DateTime(
      targetMonth.year,
      targetMonth.month + 1,
      0,
    ).day;
    _selectDate(
      DateTime(
        targetMonth.year,
        targetMonth.month,
        _selectedDate.day.clamp(1, daysInTarget),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final draft = _draft;
    if (draft == null || !_canEditSelectedDay || _saving) return;
    if (draft.totalPhotos >= 3) return;
    try {
      final picked = await _picker!.pick();
      if (picked == null || !mounted) return;
      final validation = validateProgressImage(picked);
      if (validation != null) {
        setState(() => _saveError = validation);
        return;
      }
      setState(() {
        _saveError = null;
        draft.pendingImages.add(picked);
      });
    } catch (_) {
      if (mounted) setState(() => _saveError = 'Không chọn được ảnh.');
    }
  }

  double? _parseOptionalNumber(String raw, String label) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value <= 0 || value > 9999.99) {
      throw FormatException('$label phải là số lớn hơn 0.');
    }
    return value;
  }

  double? _parseOptionalPercent(String raw, String label) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null || value < 0 || value > 100) {
      throw FormatException('$label phải từ 0 đến 100%.');
    }
    return value;
  }

  Future<void> _saveToday() async {
    final draft = _draft;
    if (draft == null || !_canEditSelectedDay || _saving) return;

    // Validate custom achievements: both name & result must be present if either is non-empty
    for (
      var i = _starterAchievements.length;
      i < draft.achievements.length;
      i++
    ) {
      final row = draft.achievements[i];
      final hasTitle = row.title.trim().isNotEmpty;
      final hasResult = row.result.trim().isNotEmpty;
      if (hasTitle != hasResult) {
        setState(() {
          _openCard = _EditCard.achievements;
          _saveError = 'Hãy nhập đầy đủ cả tên bài và kết quả thành tích.';
        });
        return;
      }
    }

    double? weightKg;
    double? bodyFat;
    double? chestCm;
    double? waistCm;
    double? hipsCm;
    try {
      weightKg = _parseOptionalNumber(draft.weight, 'Cân nặng');
      bodyFat = _parseOptionalPercent(draft.bodyFat, 'Body fat');
      chestCm = _parseOptionalNumber(draft.chest, 'Vòng ngực');
      waistCm = _parseOptionalNumber(draft.waist, 'Vòng eo');
      hipsCm = _parseOptionalNumber(draft.hips, 'Vòng hông');
    } on FormatException catch (e) {
      setState(() {
        _openCard = _EditCard.measurements;
        _saveError = e.message;
      });
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      // 1. Upload any newly picked images
      final uploadedIds = <String>[];
      for (final image in draft.pendingImages) {
        uploadedIds.add(await _photoService!.upload(image));
      }
      final allPhotoIds = [...draft.existingPhotoIds, ...uploadedIds];

      // 2. Filter non-empty achievements
      final achievementsPayload = draft.achievements
          .where(
            (row) =>
                row.title.trim().isNotEmpty && row.result.trim().isNotEmpty,
          )
          .map(
            (row) => {'title': row.title.trim(), 'result': row.result.trim()},
          )
          .toList();

      final journalPayload = <String, Object?>{
        'notes': draft.notes.trim().isEmpty ? null : draft.notes.trim(),
        'chestCm': chestCm,
        'waistCm': waistCm,
        'hipsCm': hipsCm,
        'achievements': achievementsPayload,
        'photoMediaIds': allPhotoIds,
      };

      final existingEntry = _entryForDate(_today);
      if (existingEntry == null) {
        await _service!.create(journalPayload);
      } else {
        await _service!.update(existingEntry.id, journalPayload);
      }

      // 3. Persist weight/bodyFat to BodyMeasurement if service available & weight provided
      if (_measurementService != null && weightKg != null) {
        final existingMeasure = _measurementForDate(_today);
        final measurePayload = <String, Object?>{
          'measuredAt': DateTime.now().toUtc().toIso8601String(),
          'weightKg': weightKg,
          'bodyFatPercent': bodyFat,
          'chestCm': chestCm,
          'waistCm': waistCm,
          'hipsCm': hipsCm,
        };
        if (existingMeasure == null) {
          await _measurementService!.create(measurePayload);
        } else {
          await _measurementService!.update(existingMeasure.id, {
            'weightKg': weightKg,
            'bodyFatPercent': bodyFat,
            'chestCm': chestCm,
            'waistCm': waistCm,
            'hipsCm': hipsCm,
          });
        }
      }

      if (!mounted) return;
      await _load();
      if (!mounted) return;
      _showSavedToast();
    } on ApiException catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = 'Không lưu được nhật ký hôm nay.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    if (_saving) return;
    final accepted = await MetaGymNavigation.showDialogOnce<bool>(
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
          'Nhật ký ngày ${_shortDate(_parseIsoDate(entry.journalDate) ?? _today)} sẽ bị xóa.',
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
              backgroundColor: MetaGymTheme.dangerCoral,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service!.delete(entry.id);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = 'Không thể xóa nhật ký. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSavedToast() {
    _toastTimer?.cancel();
    setState(() => _toastVisible = true);
    _toastTimer = Timer(const Duration(milliseconds: 2300), () {
      if (mounted) setState(() => _toastVisible = false);
    });
  }

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _dayHeaderTitle(DateTime d) {
    if (_isSameDay(d, _today)) {
      return '${_weekdayFull[d.weekday - 1]}, ${d.day} tháng ${d.month}';
    }
    return '${d.day} tháng ${d.month}, ${d.year}';
  }

  String _calendarTitleText() {
    if (_calendarMode == _CalendarMode.week) {
      final offset =
          _weekMonday(_selectedDate).difference(_weekMonday(_today)).inDays ~/
          7;
      if (offset == 0) return 'Tuần này';
      if (offset == -1) return 'Tuần trước';
      if (offset == 1) return 'Tuần sau';
      final abs = offset.abs();
      return '$abs tuần ${offset < 0 ? 'trước' : 'sau'}';
    }
    return 'Tháng ${_selectedDate.month}, ${_selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final showSaveBar =
        _tab == _JournalTab.journal &&
        _canEditSelectedDay &&
        _isDirty &&
        !_loading;

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: _buildSegmentedTabs(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: const Color(0xFF2B2622),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        showSaveBar ? 104 : 36,
                      ),
                      children: [
                        if (_accessError != null) ...[
                          _buildBanner(_accessError!, isError: false),
                          const SizedBox(height: 10),
                        ],
                        if (_saveError != null) ...[
                          _buildBanner(_saveError!, isError: true),
                          const SizedBox(height: 10),
                        ],
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 56),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: MetaGymTheme.brandOrange,
                              ),
                            ),
                          )
                        else if (_error != null)
                          _buildErrorCard()
                        else if (_tab == _JournalTab.journal)
                          _buildJournalTab()
                        else
                          _buildProgressTab(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showSaveBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  14 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xF5141315), Color(0x00141315)],
                  ),
                ),
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.brandOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _saving ? null : _saveToday,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Lưu thay đổi',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          if (_toastVisible)
            Positioned(
              left: 22,
              right: 22,
              bottom: 24 + MediaQuery.paddingOf(context).bottom,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEC143B2D),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: MetaGymTheme.progressGreen.withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  'Đã lưu nhật ký hôm nay',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFA4F4C4),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final todayEntry = _isSelectedToday ? _entryForDate(_today) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                  'Nhật ký tập luyện',
                  style: TextStyle(
                    color: Color(0xFFF6F3F0),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Hành trình và kết quả của bạn',
                  style: TextStyle(color: Color(0xFFBCB5AE), fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (_tab == _JournalTab.journal &&
              _canWrite &&
              todayEntry != null) ...[
            MetaGymCircleIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Xóa nhật ký hôm nay',
              onTap: _saving ? null : () => _deleteEntry(todayEntry),
            ),
            const SizedBox(width: 8),
          ],
          MetaGymCircleIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Tải lại',
            onTap: _loading ? null : _load,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x991C1917),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x55A79D92), width: 0.9),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Nhật ký',
              active: _tab == _JournalTab.journal,
              onTap: () => setState(() => _tab = _JournalTab.journal),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _SegmentButton(
              label: 'Số đo & biểu đồ',
              active: _tab == _JournalTab.progress,
              onTap: () => setState(() => _tab = _JournalTab.progress),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCalendarCard(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                _dayHeaderTitle(_selectedDate),
                style: const TextStyle(
                  color: Color(0xFFD5CCBF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_isSelectedToday && _canWrite)
              _statusPill(
                label: 'Hôm nay',
                color: MetaGymTheme.progressGreen,
              )
            else if (!_canWrite && _isSelectedToday)
              _statusPill(
                label: 'Chỉ xem (hết hạn gói)',
                color: MetaGymTheme.warningAmber,
              )
            else if (!_isSelectedToday && _selectedDate.isBefore(_today))
              _statusPill(
                label: 'Ngày đã khóa',
                color: const Color(0xFFA99F98),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDayCards(),
      ],
    );
  }

  Widget _statusPill({required String label, required Color color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.44)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _buildCalendarCard() {
    final monthStart = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final gridStart = _calendarMode == _CalendarMode.week
        ? _weekMonday(_selectedDate)
        : _weekMonday(monthStart);
    final daysInMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    ).day;
    final cellCount = _calendarMode == _CalendarMode.week
        ? 7
        : ((((monthStart.weekday - 1) + daysInMonth) / 7).ceil() * 7);

    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        children: [
          Row(
            children: [
              _CalendarNavButton(
                icon: Icons.chevron_left_rounded,
                tooltip: _calendarMode == _CalendarMode.week
                    ? 'Tuần trước'
                    : 'Tháng trước',
                onTap: () => _movePeriod(-1),
              ),
              Expanded(
                child: Text(
                  _calendarTitleText(),
                  style: const TextStyle(
                    color: Color(0xFFF6F3F0),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _CalendarNavButton(
                icon: Icons.chevron_right_rounded,
                tooltip: _calendarMode == _CalendarMode.week
                    ? 'Tuần sau'
                    : 'Tháng sau',
                onTap: () => _movePeriod(1),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF211E1C),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0x808C7766)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ViewModeChip(
                      label: 'Tuần',
                      active: _calendarMode == _CalendarMode.week,
                      onTap: () =>
                          setState(() => _calendarMode = _CalendarMode.week),
                    ),
                    const SizedBox(width: 2),
                    _ViewModeChip(
                      label: 'Tháng',
                      active: _calendarMode == _CalendarMode.month,
                      onTap: () =>
                          setState(() => _calendarMode = _CalendarMode.month),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_calendarMode == _CalendarMode.month) ...[
            const SizedBox(height: 6),
            Row(
              children: _weekdayShort
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFFA99F98),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 4),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 44,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final date = gridStart.add(Duration(days: index));
              final selected = _isSameDay(date, _selectedDate);
              final outsideMonth =
                  _calendarMode == _CalendarMode.month &&
                  date.month != _selectedDate.month;
              final hasEntry = _hasRecordOnDate(date);
              final label = _calendarMode == _CalendarMode.week
                  ? _weekdayShort[index]
                  : '${date.day}';

              return MetaGymTap(
                borderRadius: BorderRadius.circular(11),
                onTap: () => _selectDate(date),
                child: AnimatedContainer(
                  duration: MetaGymTheme.stateDurationOf(context),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: selected
                        ? MetaGymTheme.brandOrange
                        : hasEntry
                        ? const Color(0x1E2ECC71)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: selected
                        ? null
                        : hasEntry
                        ? Border.all(
                            color: const Color(0x552ECC71),
                            width: 1,
                          )
                        : null,
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0x40FF5E36),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : hasEntry
                              ? MetaGymTheme.progressGreen
                              : outsideMonth
                              ? const Color(0xFF8D827B)
                              : const Color(0xFFDED7D1),
                          fontSize: 12,
                          height: 1.15,
                          fontWeight:
                              selected || hasEntry || _calendarMode == _CalendarMode.week
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      if (hasEntry)
                        Positioned(
                          bottom: 3,
                          child: AnimatedContainer(
                            duration: MetaGymTheme.stateDurationOf(context),
                            curve: Curves.easeOutCubic,
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : MetaGymTheme.progressGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCards() {
    if (_isSelectedToday) {
      final draft =
          _draft ??
          _DayDraft.fromRecords(
            entry: null,
            measurement: null,
            starterTitles: _starterAchievements,
          );
      final editable = _canEditSelectedDay;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          editable && _openCard == _EditCard.photos
              ? _buildEditablePhotoCard(draft)
              : _buildSummaryPhotoCard(
                  photoIds: draft.existingPhotoIds,
                  pendingImages: draft.pendingImages,
                  interactive: editable,
                ),
          const SizedBox(height: 10),
          editable && _openCard == _EditCard.measurements
              ? _buildEditableMeasurementCard(draft)
              : _buildSummaryMeasurementCard(
                  weight: draft.weight,
                  bodyFat: draft.bodyFat,
                  chest: draft.chest,
                  waist: draft.waist,
                  hips: draft.hips,
                  interactive: editable,
                ),
          const SizedBox(height: 10),
          editable && _openCard == _EditCard.achievements
              ? _buildEditableAchievementCard(draft)
              : _buildSummaryAchievementCard(
                  items: draft.achievements,
                  notes: draft.notes,
                  interactive: editable,
                ),
        ],
      );
    }

    final entry = _entryForDate(_selectedDate);
    final measurement = _measurementForDate(_selectedDate);
    if (entry == null && measurement == null) {
      return MetaGymGlassCard(
        solid: false,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text(
          _selectedDate.isAfter(_today)
              ? 'Chưa đến ngày này.'
              : 'Ngày này chưa có nhật ký và đã khóa.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFBCB3AB),
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      );
    }

    final pastDraft = _DayDraft.fromRecords(
      entry: entry,
      measurement: measurement,
      starterTitles: _starterAchievements,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummaryPhotoCard(
          photoIds: pastDraft.existingPhotoIds,
          pendingImages: const [],
          interactive: false,
        ),
        const SizedBox(height: 10),
        _buildSummaryMeasurementCard(
          weight: pastDraft.weight,
          bodyFat: pastDraft.bodyFat,
          chest: pastDraft.chest,
          waist: pastDraft.waist,
          hips: pastDraft.hips,
          interactive: false,
        ),
        const SizedBox(height: 10),
        _buildSummaryAchievementCard(
          items: pastDraft.achievements,
          notes: pastDraft.notes,
          interactive: false,
        ),
      ],
    );
  }

  Widget _buildSummaryPhotoCard({
    required List<String> photoIds,
    required List<SelectedProgressImage> pendingImages,
    required bool interactive,
  }) {
    final count = photoIds.length + pendingImages.length;
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: MetaGymTap(
        borderRadius: BorderRadius.circular(18),
        onTap: interactive
            ? () => setState(() => _openCard = _EditCard.photos)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0x20FF5E36),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x55FF5E36)),
                  ),
                  alignment: Alignment.center,
                  child: const MetaGymSvgIcon(
                    MetaGymIcons.bodyProgressPhoto,
                    size: 20,
                    fallbackIcon: Icons.photo_library_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ảnh thành quả',
                        style: TextStyle(
                          color: Color(0xFFF6F3F0),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        interactive
                            ? '$count ảnh đã lưu trong ngày · Chạm để sửa'
                            : '$count ảnh đã lưu trong ngày',
                        style: const TextStyle(
                          color: Color(0xFFBDB3AD),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (count > 0) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: count,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index < photoIds.length) {
                      return SizedBox(
                        width: 64,
                        height: 80,
                        child: _JournalPhoto(
                          id: photoIds[index],
                          service: _photoService!,
                        ),
                      );
                    }
                    final local = pendingImages[index - photoIds.length];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.memory(
                        local.bytes,
                        width: 64,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditablePhotoCard(_DayDraft draft) {
    final total = draft.totalPhotos;
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x20FF5E36),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0x55FF5E36)),
                ),
                alignment: Alignment.center,
                child: const MetaGymSvgIcon(
                  MetaGymIcons.bodyProgressPhoto,
                  size: 19,
                  fallbackIcon: Icons.photo_library_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ảnh thành quả',
                      style: TextStyle(
                        color: Color(0xFFF6F3F0),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$total/3 ảnh · Chạm để thêm hoặc xóa',
                      style: const TextStyle(
                        color: Color(0xFFBDB3AD),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Thu gọn ảnh thành quả',
                onPressed: () => setState(() => _openCard = null),
                icon: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFFFFAD95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 4 / 5,
            ),
            itemCount: total < 3 ? total + 1 : total,
            itemBuilder: (context, index) {
              if (index == total) {
                return MetaGymTap(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _saving ? null : _pickPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x10FF5E36),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x8CFF9D7B)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: Color(0xFFFFAD95),
                          size: 24,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Thêm ảnh',
                          style: TextStyle(
                            color: Color(0xFFFFAD95),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final isExisting = index < draft.existingPhotoIds.length;
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isExisting
                        ? _JournalPhoto(
                            id: draft.existingPhotoIds[index],
                            service: _photoService!,
                          )
                        : Image.memory(
                            draft
                                .pendingImages[index -
                                    draft.existingPhotoIds.length]
                                .bytes,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: MetaGymTap(
                      onTap: _saving
                          ? null
                          : () => setState(() {
                              if (isExisting) {
                                draft.existingPhotoIds.removeAt(index);
                              } else {
                                draft.pendingImages.removeAt(
                                  index - draft.existingPhotoIds.length,
                                );
                              }
                            }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xE8241F1B),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0x95ADA295)),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMeasurementCard({
    required String weight,
    required String bodyFat,
    required String chest,
    required String waist,
    required String hips,
    required bool interactive,
  }) {
    String fmt(String raw, String unit) =>
        raw.trim().isEmpty ? '—' : '${raw.trim()}$unit';

    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: MetaGymTap(
        borderRadius: BorderRadius.circular(18),
        onTap: interactive
            ? () => setState(() => _openCard = _EditCard.measurements)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chỉ số cơ thể',
                    style: TextStyle(
                      color: Color(0xFFF6F3F0),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (interactive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Chạm để nhập',
                      style: TextStyle(
                        color: Color(0xFFFF9A79),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _PrimaryMetricBox(
                    label: 'Cân nặng',
                    value: fmt(weight, ' kg'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PrimaryMetricBox(
                    label: 'Body fat',
                    value: fmt(bodyFat, '%'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _SecondaryMetricBox(
                    label: 'Vòng ngực',
                    value: fmt(chest, ' cm'),
                    accentColor: MetaGymTheme.brandOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SecondaryMetricBox(
                    label: 'Vòng eo',
                    value: fmt(waist, ' cm'),
                    accentColor: MetaGymTheme.progressGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SecondaryMetricBox(
                    label: 'Vòng hông',
                    value: fmt(hips, ' cm'),
                    accentColor: MetaGymTheme.reflectionBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableMeasurementCard(_DayDraft draft) {
    Widget field({
      required String label,
      required String unit,
      required String initial,
      required ValueChanged<String> onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFBDB3AD), fontSize: 10),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextFormField(
                    initialValue: initial,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '—',
                      hintStyle: const TextStyle(color: Color(0xFF77706A)),
                      filled: true,
                      fillColor: const Color(0x99211E1C),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0x6BA89280)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: MetaGymTheme.brandOrange,
                        ),
                      ),
                    ),
                    onChanged: (value) => setState(() => onChanged(value)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  color: Color(0xFFC8BDB5),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Chỉ số cơ thể',
                  style: TextStyle(
                    color: Color(0xFFF6F3F0),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Thu gọn chỉ số cơ thể',
                onPressed: () => setState(() => _openCard = null),
                icon: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFFFFAD95),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: field(
                  label: 'Cân nặng',
                  unit: 'kg',
                  initial: draft.weight,
                  onChanged: (v) => draft.weight = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  label: 'Body fat',
                  unit: '%',
                  initial: draft.bodyFat,
                  onChanged: (v) => draft.bodyFat = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: field(
                  label: 'Vòng ngực',
                  unit: 'cm',
                  initial: draft.chest,
                  onChanged: (v) => draft.chest = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  label: 'Vòng eo',
                  unit: 'cm',
                  initial: draft.waist,
                  onChanged: (v) => draft.waist = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  label: 'Vòng hông',
                  unit: 'cm',
                  initial: draft.hips,
                  onChanged: (v) => draft.hips = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAchievementCard({
    required List<_AchievementDraft> items,
    required String notes,
    required bool interactive,
  }) {
    final filled = items
        .where((item) => item.result.trim().isNotEmpty)
        .toList();
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: MetaGymTap(
        borderRadius: BorderRadius.circular(18),
        onTap: interactive
            ? () => setState(() => _openCard = _EditCard.achievements)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MetaGymSvgIcon(
                  MetaGymIcons.progressAchievementPr,
                  size: 17,
                  fallbackIcon: Icons.emoji_events_outlined,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Thành tích của bạn',
                    style: TextStyle(
                      color: Color(0xFFF6F3F0),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (interactive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Chạm để ghi',
                      style: TextStyle(
                        color: Color(0xFFFF9A79),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              'Tùy chọn · 3 bài gợi ý hoặc thêm bài riêng',
              style: TextStyle(color: Color(0xFFBDB3AD), fontSize: 10.5),
            ),
            const SizedBox(height: 8),
            if (filled.isEmpty)
              const Text(
                'Chưa ghi thành tích',
                style: TextStyle(color: Color(0xFFBDB3AD), fontSize: 11.5),
              )
            else
              ...filled.map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x24A79D92))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: Color(0xFFD7CDC5),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        item.result,
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 7),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x20FFFFFF))),
                ),
                child: Text(
                  notes.trim(),
                  style: const TextStyle(
                    color: Color(0xFFBDB3AD),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditableAchievementCard(_DayDraft draft) {
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thành tích của bạn',
                  style: TextStyle(
                    color: Color(0xFFF6F3F0),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Thu gọn thành tích',
                onPressed: () => setState(() => _openCard = null),
                icon: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFFFFAD95),
                ),
              ),
            ],
          ),
          const Text(
            'Tùy chọn · Chỉ lưu bài bạn đã ghi',
            style: TextStyle(color: Color(0xFFBDB3AD), fontSize: 10.5),
          ),
          const SizedBox(height: 8),
          ...List.generate(draft.achievements.length, (index) {
            final row = draft.achievements[index];
            final isStarter = index < _starterAchievements.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: isStarter
                        ? Text(
                            _starterAchievements[index],
                            style: const TextStyle(
                              color: Color(0xFFD7CDC5),
                              fontSize: 12.5,
                            ),
                          )
                        : SizedBox(
                            height: 48,
                            child: TextFormField(
                              key: ValueKey('custom-name-$index'),
                              initialValue: row.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _inlineInputDecoration('Tên bài'),
                              onChanged: (v) => setState(() => row.title = v),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    height: 48,
                    child: TextFormField(
                      key: ValueKey('ach-result-$index'),
                      initialValue: row.result,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inlineInputDecoration('Chưa ghi'),
                      onChanged: (v) => setState(() => row.result = v),
                    ),
                  ),
                  if (!isStarter)
                    IconButton(
                      tooltip: 'Xóa bài',
                      onPressed: () =>
                          setState(() => draft.achievements.removeAt(index)),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFFFAD95),
                        size: 18,
                      ),
                    ),
                ],
              ),
            );
          }),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFAE94),
                backgroundColor: const Color(0x17FF5E36),
                side: const BorderSide(color: Color(0x6EC78C72)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => setState(() {
                draft.achievements.add(
                  _AchievementDraft(title: '', result: ''),
                );
              }),
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text(
                'Thêm bài khác',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: draft.notes,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
            decoration: _inlineInputDecoration('Ghi chú buổi tập (tùy chọn)'),
            onChanged: (v) => setState(() => draft.notes = v),
          ),
        ],
      ),
    );
  }

  InputDecoration _inlineInputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF77706A), fontSize: 12),
    filled: true,
    fillColor: const Color(0x99211E1C),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0x6BA89280)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: MetaGymTheme.brandOrange),
    ),
  );

  Widget _buildProgressTab() {
    final latestMeasure = _measurements.isNotEmpty ? _measurements.first : null;
    final latestWeight =
        latestMeasure?.weightKg ?? _summary?.latestMeasurement?.weightKg;
    final workoutCount = _summary?.workoutCount;

    String weightDeltaLabel = 'Chưa đủ dữ liệu so sánh';
    if (_weightPoints.length >= 2) {
      final delta = _weightPoints.last.weightKg - _weightPoints.first.weightKg;
      final sign = delta <= 0 ? '↓' : '↑';
      weightDeltaLabel =
          '$sign ${delta.abs().toStringAsFixed(1)} kg trong $_chartRange';
    }

    final latestEntryWithMeasure = _entries.cast<JournalEntry?>().firstWhere(
      (e) => e?.chestCm != null || e?.waistCm != null || e?.hipsCm != null,
      orElse: () => null,
    );
    final chest = latestMeasure?.chestCm ?? latestEntryWithMeasure?.chestCm;
    final waist = latestMeasure?.waistCm ?? latestEntryWithMeasure?.waistCm;
    final hips = latestMeasure?.hipsCm ?? latestEntryWithMeasure?.hipsCm;
    final latestDate = latestMeasure != null
        ? _shortDate(_parseIsoDate(latestMeasure.measuredAt) ?? _today)
        : latestEntryWithMeasure != null
        ? _shortDate(
            _parseIsoDate(latestEntryWithMeasure.journalDate) ?? _today,
          )
        : null;

    final highlights = <JournalAchievement>[];
    final seenTitles = <String>{};
    for (final entry in _entries) {
      for (final item in entry.achievements) {
        if (seenTitles.add(item.title)) {
          highlights.add(item);
          if (highlights.length >= 3) break;
        }
      }
      if (highlights.length >= 3) break;
    }
    final trendRange = _weightPoints.length >= 2
        ? '${_weightPoints.first.weightKg.toStringAsFixed(1)} → ${_weightPoints.last.weightKg.toStringAsFixed(1)}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: MetaGymGlassCard(
                solid: false,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cân nặng gần nhất',
                      style: TextStyle(color: Color(0xFFBCB2AB), fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      latestWeight == null
                          ? '—'
                          : '${latestWeight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        color: Color(0xFFF6F3F0),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      weightDeltaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.progressGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetaGymGlassCard(
                solid: false,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng buổi đã tập',
                      style: TextStyle(color: Color(0xFFBCB2AB), fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      workoutCount == null ? '—' : '$workoutCount buổi',
                      style: const TextStyle(
                        color: MetaGymTheme.brandOrange,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_entries.length} ngày có nhật ký',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MetaGymTheme.progressGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MetaGymGlassCard(
          solid: false,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MetaGymSvgIcon(
                        MetaGymIcons.statsChartLine,
                        size: 17,
                        fallbackIcon: Icons.show_chart_rounded,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Biểu đồ cân nặng',
                        style: TextStyle(
                          color: Color(0xFFF6F3F0),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trendRange != null) ...[
                        Text(
                          trendRange,
                          style: const TextStyle(
                            color: MetaGymTheme.progressGreen,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _chartRange,
                          dropdownColor: const Color(0xFF2B2622),
                          style: const TextStyle(
                            color: Color(0xFFFF9A79),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                          items: const ['8 tuần', '30 ngày', 'Toàn bộ']
                              .map(
                                (label) => DropdownMenuItem(
                                  value: label,
                                  child: Text(label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) _changeChartRange(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Text(
                'Thay đổi theo những lần bạn nhập số đo',
                style: TextStyle(color: Color(0xFFBFB6B0), fontSize: 11),
              ),
              const SizedBox(height: 14),
              if (_weightPoints.length < 2)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Cần ít nhất 2 lần cân để vẽ biểu đồ.',
                      style: TextStyle(color: Color(0xFFBCB3AB), fontSize: 12),
                    ),
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final weights = _weightPoints
                        .map((p) => p.weightKg)
                        .toList();
                    final rawMin = weights.reduce((a, b) => a < b ? a : b);
                    final rawMax = weights.reduce((a, b) => a > b ? a : b);
                    final minY = (rawMin - 0.6).floorToDouble();
                    final maxY = (rawMax + 0.6).ceilToDouble();
                    final span = (maxY - minY).clamp(1.0, 999.0);
                    final yInterval = (span / 3).ceilToDouble().clamp(
                      1.0,
                      99.0,
                    );
                    return SizedBox(
                      height: 165,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: yInterval,
                              getDrawingHorizontalLine: (_) => const FlLine(
                                color: Color(0x24FFFFFF),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 38,
                                  interval: yInterval,
                                  getTitlesWidget: (value, meta) {
                                    if (value == meta.min ||
                                        value == meta.max) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      value.toStringAsFixed(0),
                                      style: const TextStyle(
                                        color: Color(0xFFAB9F98),
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  interval: (_weightPoints.length / 4)
                                      .clamp(1, 999)
                                      .toDouble(),
                                  getTitlesWidget: (value, _) {
                                    final idx = value.round();
                                    if (idx < 0 ||
                                        idx >= _weightPoints.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final d = _parseIsoDate(
                                      _weightPoints[idx].measuredAt,
                                    );
                                    return Text(
                                      d == null
                                          ? ''
                                          : DateFormat('d/M').format(d),
                                      style: const TextStyle(
                                        color: Color(0xFFAB9F98),
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(
                                  _weightPoints.length,
                                  (i) => FlSpot(
                                    i.toDouble(),
                                    _weightPoints[i].weightKg,
                                  ),
                                ),
                                isCurved: true,
                                color: MetaGymTheme.brandOrange,
                                barWidth: 3,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (_, _, _, index) {
                                    final isLatest =
                                        index == _weightPoints.length - 1;
                                    return FlDotCirclePainter(
                                      radius: isLatest ? 4.5 : 3.2,
                                      color: isLatest
                                          ? MetaGymTheme.progressGreen
                                          : MetaGymTheme.brandOrange,
                                      strokeWidth: isLatest ? 1.6 : 0,
                                      strokeColor: Colors.white,
                                    );
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      MetaGymTheme.brandOrange.withValues(
                                        alpha: 0.30,
                                      ),
                                      MetaGymTheme.brandOrange.withValues(
                                        alpha: 0.0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetaGymGlassCard(
          solid: false,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Số đo cơ thể',
                    style: TextStyle(
                      color: Color(0xFFF6F3F0),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final router = GoRouter.maybeOf(context);
                      if (router != null) {
                        MetaGymNavigation.pushPathOnce(
                          context,
                          '/member/features/measurements',
                        );
                      } else if (_measurementService != null) {
                        MetaGymNavigation.pushOnce<void>(
                          context,
                          MetaGymPageRoute(
                            builder: (_) => MemberMeasurementPage(
                              service: _measurementService,
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Xem lịch sử ›',
                      style: TextStyle(
                        color: Color(0xFFFF9A79),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                latestDate == null
                    ? 'Chưa có dữ liệu số đo'
                    : 'Cập nhật gần nhất: $latestDate',
                style: const TextStyle(color: Color(0xFFBEB3AC), fontSize: 11),
              ),
              const SizedBox(height: 10),
              _MeasureRow(
                label: 'Vòng ngực',
                value: chest == null ? '—' : '${chest.toStringAsFixed(1)} cm',
                dotColor: MetaGymTheme.brandOrange,
              ),
              _MeasureRow(
                label: 'Vòng eo',
                value: waist == null ? '—' : '${waist.toStringAsFixed(1)} cm',
                dotColor: MetaGymTheme.progressGreen,
              ),
              _MeasureRow(
                label: 'Vòng hông',
                value: hips == null ? '—' : '${hips.toStringAsFixed(1)} cm',
                dotColor: MetaGymTheme.reflectionBlue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetaGymGlassCard(
          solid: false,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.42),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const MetaGymSvgIcon(
                      MetaGymIcons.progressAchievementPr,
                      size: 18,
                      fallbackIcon: Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Thành tích tập luyện',
                      style: TextStyle(
                        color: Color(0xFFF6F3F0),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (highlights.isEmpty)
                const Text(
                  'Ghi thành tích ở tab Nhật ký để theo dõi tiến bộ.',
                  style: TextStyle(color: Color(0xFFBCB2AA), fontSize: 12),
                )
              else
                for (final (idx, item) in highlights.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: idx > 0
                        ? const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0x24A79D92)),
                            ),
                          )
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              color: Color(0xFFD7CDC5),
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Text(
                          item.result,
                          style: const TextStyle(
                            color: MetaGymTheme.brandOrange,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(String text, {required bool isError}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: isError ? const Color(0x2EF15B64) : const Color(0x28F39C12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isError
            ? MetaGymTheme.dangerCoral.withValues(alpha: 0.5)
            : MetaGymTheme.warningAmber.withValues(alpha: 0.5),
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: isError ? const Color(0xFFFFB4B8) : const Color(0xFFFFD89B),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _buildErrorCard() => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFF6F3F0), fontSize: 13),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _load,
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MetaGymTap(
    borderRadius: BorderRadius.circular(11),
    onTap: onTap,
    child: AnimatedContainer(
      duration: MetaGymTheme.stateDurationOf(context),
      curve: Curves.easeOutCubic,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0x2EFF5E36) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        border: active
            ? Border.all(
                color: MetaGymTheme.brandOrange.withValues(alpha: 0.78),
                width: 1.1,
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFFBDB5AE),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    onPressed: onTap,
    icon: Icon(icon, color: const Color(0xFFE6D9D1), size: 22),
  );
}

class _ViewModeChip extends StatelessWidget {
  const _ViewModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MetaGymTap(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: AnimatedContainer(
      duration: MetaGymTheme.stateDurationOf(context),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0x2EFF5E36) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: active
            ? Border.all(
                color: MetaGymTheme.brandOrange.withValues(alpha: 0.72),
                width: 1,
              )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFFBDB5AE),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _PrimaryMetricBox extends StatelessWidget {
  const _PrimaryMetricBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x80211E1C),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x55A79D92)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFBDB3AD),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF6F3F0),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    ),
  );
}

class _SecondaryMetricBox extends StatelessWidget {
  const _SecondaryMetricBox({
    required this.label,
    required this.value,
    required this.accentColor,
  });
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
    decoration: BoxDecoration(
      color: accentColor.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: accentColor.withValues(alpha: 0.34), width: 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFD5CCBF),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF6F3F0),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    ),
  );
}

class _MeasureRow extends StatelessWidget {
  const _MeasureRow({
    required this.label,
    required this.value,
    required this.dotColor,
  });
  final String label;
  final String value;
  final Color dotColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0x24A79D92))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFD5CCBF), fontSize: 12.5),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFF6F3F0),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: MetaGymTheme.tabularFigures,
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(11),
    child: Container(
      color: const Color(0xFF221E1B),
      child: FutureBuilder<Uri>(
        future: _accessUrl,
        builder: (context, snapshot) => snapshot.hasData
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

class _AchievementDraft {
  _AchievementDraft({required this.title, required this.result});
  String title;
  String result;

  _AchievementDraft copy() => _AchievementDraft(title: title, result: result);

  @override
  bool operator ==(Object other) =>
      other is _AchievementDraft &&
      other.title == title &&
      other.result == result;

  @override
  int get hashCode => Object.hash(title, result);
}

class _DayDraft {
  _DayDraft({
    required this.existingPhotoIds,
    required this.pendingImages,
    required this.weight,
    required this.bodyFat,
    required this.chest,
    required this.waist,
    required this.hips,
    required this.notes,
    required this.achievements,
  });

  factory _DayDraft.fromRecords({
    required JournalEntry? entry,
    required BodyMeasurement? measurement,
    required List<String> starterTitles,
  }) {
    String fmtNum(double? val) {
      if (val == null) return '';
      return val == val.roundToDouble()
          ? val.toInt().toString()
          : val.toString();
    }

    final existing = entry?.achievements ?? const <JournalAchievement>[];
    final byTitle = {for (final item in existing) item.title: item.result};
    final rows = <_AchievementDraft>[
      for (final starter in starterTitles)
        _AchievementDraft(title: starter, result: byTitle[starter] ?? ''),
      for (final item in existing)
        if (!starterTitles.contains(item.title))
          _AchievementDraft(title: item.title, result: item.result),
    ];

    return _DayDraft(
      existingPhotoIds: List<String>.from(entry?.photoMediaIds ?? const []),
      pendingImages: <SelectedProgressImage>[],
      weight: fmtNum(measurement?.weightKg),
      bodyFat: fmtNum(measurement?.bodyFatPercent),
      chest: fmtNum(entry?.chestCm ?? measurement?.chestCm),
      waist: fmtNum(entry?.waistCm ?? measurement?.waistCm),
      hips: fmtNum(entry?.hipsCm ?? measurement?.hipsCm),
      notes: entry?.notes ?? '',
      achievements: rows,
    );
  }

  final List<String> existingPhotoIds;
  final List<SelectedProgressImage> pendingImages;
  String weight;
  String bodyFat;
  String chest;
  String waist;
  String hips;
  String notes;
  final List<_AchievementDraft> achievements;

  int get totalPhotos => existingPhotoIds.length + pendingImages.length;

  _DayDraft copy() => _DayDraft(
    existingPhotoIds: List<String>.from(existingPhotoIds),
    pendingImages: List<SelectedProgressImage>.from(pendingImages),
    weight: weight,
    bodyFat: bodyFat,
    chest: chest,
    waist: waist,
    hips: hips,
    notes: notes,
    achievements: achievements.map((e) => e.copy()).toList(),
  );

  bool equals(_DayDraft other) {
    if (existingPhotoIds.length != other.existingPhotoIds.length ||
        pendingImages.length != other.pendingImages.length ||
        achievements.length != other.achievements.length) {
      return false;
    }
    for (var i = 0; i < existingPhotoIds.length; i++) {
      if (existingPhotoIds[i] != other.existingPhotoIds[i]) return false;
    }
    for (var i = 0; i < pendingImages.length; i++) {
      if (pendingImages[i] != other.pendingImages[i]) return false;
    }
    for (var i = 0; i < achievements.length; i++) {
      if (achievements[i] != other.achievements[i]) return false;
    }
    return weight == other.weight &&
        bodyFat == other.bodyFat &&
        chest == other.chest &&
        waist == other.waist &&
        hips == other.hips &&
        notes == other.notes;
  }
}
