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
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/domain/journal_entry.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:meta_gym_app/features/progress/presentation/member_measurement_page.dart';
import 'package:meta_gym_app/features/progress/presentation/widgets/journal_interactive_modals.dart';
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
  int _modalSyncVersion = 0;
  bool _isFemale = false;

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
    final profileGender = _tryRead<SessionController>()?.user?.profile['gender']
        ?.toString()
        .toUpperCase();
    if (profileGender == 'FEMALE') {
      _isFemale = true;
    }
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

  void _jumpToToday() => _selectDate(_today);

  String _fmtDraftDouble(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  Future<void> _openWeightBodyFatSheet(_DayDraft draft) async {
    if (!_canEditSelectedDay || _saving) return;
    final initialWeight =
        double.tryParse(draft.weight.trim().replaceAll(',', '.'));
    final initialFat =
        double.tryParse(draft.bodyFat.trim().replaceAll(',', '.'));
    final picked = await showWeightBodyFatPickerSheet(
      context,
      initialWeightKg: initialWeight,
      initialBodyFatPercent: initialFat,
    );
    if (picked == null || !mounted) return;
    setState(() {
      draft.weight = _fmtDraftDouble(picked.weightKg);
      draft.bodyFat = _fmtDraftDouble(picked.bodyFatPercent);
      _modalSyncVersion++;
      _saveError = null;
    });
  }

  Future<void> _openTapeScannerSheet(_DayDraft draft, String part) async {
    if (!_canEditSelectedDay || _saving) return;
    final initialChest =
        double.tryParse(draft.chest.trim().replaceAll(',', '.'));
    final initialWaist =
        double.tryParse(draft.waist.trim().replaceAll(',', '.'));
    final initialHips =
        double.tryParse(draft.hips.trim().replaceAll(',', '.'));
    final picked = await showBodyTapeScannerSheet(
      context,
      initialChestCm: initialChest,
      initialWaistCm: initialWaist,
      initialHipsCm: initialHips,
      initialPart: part,
      initialIsFemale: _isFemale,
    );
    if (picked == null || !mounted) return;
    setState(() {
      draft.chest = _fmtDraftDouble(picked.chestCm);
      draft.waist = _fmtDraftDouble(picked.waistCm);
      draft.hips = _fmtDraftDouble(picked.hipsCm);
      _modalSyncVersion++;
      _saveError = null;
    });
  }

  Future<void> _openAddPrSheet(_DayDraft draft) async {
    if (!_canEditSelectedDay || _saving) return;
    final picked = await showAddWorkoutPrSheet(context);
    if (picked == null || !mounted) return;
    setState(() {
      final existingIdx = draft.achievements.indexWhere(
        (item) =>
            item.title.trim().toLowerCase() ==
            picked.title.trim().toLowerCase(),
      );
      if (existingIdx >= 0) {
        draft.achievements[existingIdx].result = picked.result;
      } else {
        draft.achievements.add(
          _AchievementDraft(title: picked.title, result: picked.result),
        );
      }
      _modalSyncVersion++;
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

  MetaGymPalette get _palette => MetaGymTheme.paletteOf(context);
  MetaGymColors get _colors => MetaGymColors.of(context);
  bool get _isLight => MetaGymTheme.isLightPalette(context);

  Future<void> _deleteEntry(JournalEntry entry) async {
    if (_saving) return;
    final accepted = await MetaGymNavigation.showDialogOnce<bool>(
      context: context,
      builder: (context) {
        final palette = MetaGymTheme.paletteOf(context);
        final colors = MetaGymColors.of(context);
        return AlertDialog(
          backgroundColor: colors.overlayGlass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.overlayGlassBorder, width: 1.1),
          ),
          title: Text(
            'Xóa nhật ký?',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Nhật ký ngày ${_shortDate(_parseIsoDate(entry.journalDate) ?? _today)} sẽ bị xóa.',
            style: TextStyle(color: palette.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Giữ lại',
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
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
    final palette = _palette;
    final colors = _colors;
    final isLight = _isLight;
    final showSaveBar =
        _tab == _JournalTab.journal &&
        _canEditSelectedDay &&
        _isDirty &&
        !_loading;

    return Scaffold(
      backgroundColor: palette.canvas,
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
                    backgroundColor: colors.surface,
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
                  14,
                  16,
                  14 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: isLight
                        ? const [
                            Color(0xFAE8EEF5),
                            Color(0xCCE8EEF5),
                            Color(0x00E8EEF5),
                          ]
                        : const [
                            Color(0xFA141315),
                            Color(0xCC141315),
                            Color(0x00141315),
                          ],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x45FF5E36),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: MetaGymTheme.brandOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _saving ? null : _saveToday,
                      icon: _saving
                          ? const SizedBox.shrink()
                          : const MetaGymSvgIcon(
                              MetaGymIcons.commonSave,
                              size: 18,
                              color: Colors.white,
                              adaptForLightMode: false,
                              fallbackIcon: Icons.check_rounded,
                            ),
                      label: _saving
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
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
                  color: isLight
                      ? colors.overlayGlass
                      : const Color(0xEC143B2D),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: palette.success.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Đã lưu nhật ký hôm nay',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isLight
                        ? palette.success
                        : const Color(0xFFA4F4C4),
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
    final palette = _palette;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'META GYM · NHẬT KÝ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Nhật ký tập luyện',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (_tab == _JournalTab.journal &&
              !_isSelectedToday &&
              !_loading) ...[
            MetaGymTap(
              key: const Key('journal-today-pill'),
              borderRadius: BorderRadius.circular(999),
              onTap: _jumpToToday,
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.chipActiveBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  'Hôm nay',
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
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
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.metricPanelBorder, width: 1.0),
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
    final palette = _palette;
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
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_isSelectedToday && _canWrite)
              _statusPill(label: 'Hôm nay', color: palette.success)
            else if (!_canWrite && _isSelectedToday)
              _statusPill(
                label: 'Chỉ xem (hết hạn gói)',
                color: palette.warning,
              )
            else if (!_isSelectedToday && _selectedDate.isBefore(_today))
              _statusPill(
                label: 'Ngày đã khóa',
                color: palette.textSecondary,
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
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.42)),
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
    final palette = _palette;
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

    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _calendarMode == _CalendarMode.week
                          ? 'LỊCH TUẦN'
                          : 'LỊCH THÁNG',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    Text(
                      _calendarTitleText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
                  color: palette.metricPanelBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.metricPanelBorder),
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
            const SizedBox(height: 8),
            Row(
              children: _weekdayShort
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 46,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              final date = gridStart.add(Duration(days: index));
              final selected = _isSameDay(date, _selectedDate);
              final isTodayCell = _isSameDay(date, _today);
              final outsideMonth =
                  _calendarMode == _CalendarMode.month &&
                  date.month != _selectedDate.month;
              final hasEntry = _hasRecordOnDate(date);
              final label = _calendarMode == _CalendarMode.week
                  ? _weekdayShort[index]
                  : '${date.day}';

              return MetaGymTap(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectDate(date),
                child: AnimatedContainer(
                  duration: MetaGymTheme.stateDurationOf(context),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF6D48), Color(0xFFFF5E36)],
                          )
                        : null,
                    color: selected
                        ? null
                        : hasEntry
                        ? palette.success.withValues(alpha: 0.14)
                        : palette.metricPanelBg.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: selected
                        ? null
                        : isTodayCell
                        ? Border.all(
                            color: MetaGymTheme.brandOrange.withValues(alpha: 0.72),
                            width: 1.2,
                          )
                        : hasEntry
                        ? Border.all(
                            color: palette.success.withValues(alpha: 0.42),
                            width: 1,
                          )
                        : Border.all(
                            color: palette.borderSolid.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
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
                              ? palette.success
                              : outsideMonth
                              ? palette.textSecondary.withValues(alpha: 0.5)
                              : palette.textPrimary,
                          fontSize: 12.5,
                          height: 1.15,
                          fontWeight:
                              selected ||
                                  hasEntry ||
                                  _calendarMode == _CalendarMode.week
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      if (hasEntry)
                        Positioned(
                          bottom: 4,
                          child: AnimatedContainer(
                            duration: MetaGymTheme.stateDurationOf(context),
                            curve: Curves.easeOutCubic,
                            width: 4.5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: selected ? Colors.white : palette.success,
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
                  onTapWeightSheet: editable
                      ? () => _openWeightBodyFatSheet(draft)
                      : null,
                  onTapTapeSheet: editable
                      ? (part) => _openTapeScannerSheet(draft, part)
                      : null,
                ),
          const SizedBox(height: 10),
          editable && _openCard == _EditCard.achievements
              ? _buildEditableAchievementCard(draft)
              : _buildSummaryAchievementCard(
                  items: draft.achievements,
                  notes: draft.notes,
                  interactive: editable,
                  onTapAddPr: editable ? () => _openAddPrSheet(draft) : null,
                ),
        ],
      );
    }

    final entry = _entryForDate(_selectedDate);
    final measurement = _measurementForDate(_selectedDate);
    if (entry == null && measurement == null) {
      final palette = _palette;
      return MetaGymGlassCard(
        solid: false,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.metricPanelBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.metricPanelBorder),
              ),
              alignment: Alignment.center,
              child: const MetaGymSvgIcon(
                MetaGymIcons.emptyProgress,
                size: 26,
                fallbackIcon: Icons.lock_clock_outlined,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _selectedDate.isAfter(_today)
                  ? 'Chưa đến ngày này.'
                  : 'Ngày này chưa có nhật ký và đã khóa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
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
    final palette = _palette;
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.chipActiveBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MetaGymTheme.primary.withValues(alpha: 0.36),
                    ),
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
                      Text(
                        'Ảnh thành quả',
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        interactive
                            ? '$count/3 ảnh đã lưu · Chạm để sửa'
                            : '$count ảnh đã lưu trong ngày',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (interactive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.chipActiveBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.36),
                      ),
                    ),
                    child: Text(
                      '+ Ảnh',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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
    final palette = _palette;
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
                  color: palette.chipActiveBg,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: MetaGymTheme.primary.withValues(alpha: 0.36),
                  ),
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
                    Text(
                      'Ảnh thành quả',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$total/3 ảnh · Chạm để thêm hoặc xóa',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Thu gọn ảnh thành quả',
                onPressed: () => setState(() => _openCard = null),
                icon: MetaGymSvgIcon(MetaGymIcons.commonChevronUp, fallbackIcon: Icons.keyboard_arrow_up_rounded),
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
                      color: palette.chipActiveBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MetaGymTheme.primary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MetaGymSvgIcon(MetaGymIcons.commonAdd, size: 24, fallbackIcon: Icons.add_rounded),
                        const SizedBox(height: 2),
                        Text(
                          'Thêm ảnh',
                          style: TextStyle(
                            color: palette.primaryText,
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
                          color: const Color(0xCC181B22),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const MetaGymSvgIcon(MetaGymIcons.commonClose, size: 16, color: Colors.white, adaptForLightMode: false, fallbackIcon: Icons.close_rounded),
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
    VoidCallback? onTapWeightSheet,
    ValueChanged<String>? onTapTapeSheet,
  }) {
    final palette = _palette;
    String fmt(String raw, String unit) =>
        raw.trim().isEmpty ? '—' : '${raw.trim()}$unit';
    final chestVal =
        double.tryParse(chest.trim().replaceAll(',', '.')) ??
        (_isFemale ? 88.0 : 98.0);
    final waistVal =
        double.tryParse(waist.trim().replaceAll(',', '.')) ??
        (_isFemale ? 64.0 : 78.0);
    final hipsVal =
        double.tryParse(hips.trim().replaceAll(',', '.')) ?? 94.0;
    final ratioText = _isFemale
        ? 'WHR ${(waistVal / hipsVal.clamp(1.0, 300.0)).toStringAsFixed(2)}'
        : 'V-Taper ${(chestVal / waistVal.clamp(1.0, 300.0)).toStringAsFixed(2)}';

    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MetaGymTap(
            borderRadius: BorderRadius.circular(12),
            onTap: interactive
                ? () => setState(() => _openCard = _EditCard.measurements)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: palette.chipActiveBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: MetaGymTheme.primary.withValues(alpha: 0.36),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const MetaGymSvgIcon(
                      MetaGymIcons.bodyMeasureTape,
                      size: 18,
                      fallbackIcon: Icons.straighten_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chỉ số cơ thể',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (interactive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.chipActiveBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: MetaGymTheme.brandOrange.withValues(alpha: 0.36),
                        ),
                      ),
                      child: Text(
                        'Chạm để nhập',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PrimaryMetricBox(
                  key: const Key('journal-open-weight-modal'),
                  label: 'Cân nặng',
                  value: fmt(weight, ' kg'),
                  interactive: interactive,
                  onTap: onTapWeightSheet,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PrimaryMetricBox(
                  key: const Key('journal-open-fat-modal'),
                  label: 'Body fat',
                  value: fmt(bodyFat, '%'),
                  interactive: interactive,
                  onTap: onTapWeightSheet,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MetaGymMetricPanel(
            padding: const EdgeInsets.all(10),
            onTap: interactive && onTapTapeSheet != null
                ? () => onTapTapeSheet('chest')
                : null,
            child: Row(
              children: [
                BodyAnatomyMeasureStage(
                  width: 98,
                  height: 142,
                  borderRadius: 14,
                  isFemale: _isFemale,
                  chestCm: chestVal,
                  waistCm: waistVal,
                  hipsCm: hipsVal,
                  showCallouts: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dáng người 3 vòng',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: palette.surfaceRaised.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: palette.metricPanelBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MiniGenderChip(
                                  key: const Key('journal-gender-male'),
                                  label: 'Nam',
                                  active: !_isFemale,
                                  onTap: () =>
                                      setState(() => _isFemale = false),
                                ),
                                const SizedBox(width: 2),
                                _MiniGenderChip(
                                  key: const Key('journal-gender-female'),
                                  label: 'Nữ',
                                  active: _isFemale,
                                  onTap: () =>
                                      setState(() => _isFemale = true),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.success.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: palette.success.withValues(alpha: 0.42),
                              ),
                            ),
                            child: Text(
                              ratioText,
                              style: TextStyle(
                                color: palette.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFeatures: MetaGymTheme.tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        interactive
                            ? 'Chạm hình hoặc số đo để kéo thước 3 vòng'
                            : 'Mô phỏng hình thể theo số đo đã lưu',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SecondaryMetricBox(
                  key: const Key('journal-open-tape-chest'),
                  label: 'Vòng ngực',
                  value: fmt(chest, ' cm'),
                  accentColor: palette.primaryText,
                  interactive: interactive,
                  onTap: onTapTapeSheet == null
                      ? null
                      : () => onTapTapeSheet('chest'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryMetricBox(
                  key: const Key('journal-open-tape-waist'),
                  label: 'Vòng eo',
                  value: fmt(waist, ' cm'),
                  accentColor: palette.success,
                  interactive: interactive,
                  onTap: onTapTapeSheet == null
                      ? null
                      : () => onTapTapeSheet('waist'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryMetricBox(
                  key: const Key('journal-open-tape-hips'),
                  label: 'Vòng hông',
                  value: fmt(hips, ' cm'),
                  accentColor: palette.reflection,
                  interactive: interactive,
                  onTap: onTapTapeSheet == null
                      ? null
                      : () => onTapTapeSheet('hip'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableMeasurementCard(_DayDraft draft) {
    final palette = _palette;
    Widget field({
      required Key fieldKey,
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
            style: TextStyle(color: palette.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextFormField(
                    key: fieldKey,
                    initialValue: initial,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '—',
                      hintStyle: TextStyle(
                        color: palette.textSecondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: palette.metricPanelBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: palette.metricPanelBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
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
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
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
              Expanded(
                child: Text(
                  'Chỉ số cơ thể',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Thu gọn chỉ số cơ thể',
                onPressed: () => setState(() => _openCard = null),
                icon: const MetaGymSvgIcon(
                  MetaGymIcons.commonChevronUp,
                  fallbackIcon: Icons.keyboard_arrow_up_rounded,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _QuickToolChip(
                icon: MetaGymIcons.bodyWeightScale,
                label: 'Đĩa tạ & Mỡ',
                color: palette.primaryText,
                onTap: () => _openWeightBodyFatSheet(draft),
              ),
              _QuickToolChip(
                icon: MetaGymIcons.bodyMeasureTape,
                label: 'Thước 3 vòng',
                color: palette.success,
                onTap: () => _openTapeScannerSheet(draft, 'chest'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: field(
                  fieldKey: ValueKey('meas-weight-$_modalSyncVersion'),
                  label: 'Cân nặng',
                  unit: 'kg',
                  initial: draft.weight,
                  onChanged: (v) => draft.weight = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  fieldKey: ValueKey('meas-fat-$_modalSyncVersion'),
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
                  fieldKey: ValueKey('meas-chest-$_modalSyncVersion'),
                  label: 'Vòng ngực',
                  unit: 'cm',
                  initial: draft.chest,
                  onChanged: (v) => draft.chest = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  fieldKey: ValueKey('meas-waist-$_modalSyncVersion'),
                  label: 'Vòng eo',
                  unit: 'cm',
                  initial: draft.waist,
                  onChanged: (v) => draft.waist = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: field(
                  fieldKey: ValueKey('meas-hips-$_modalSyncVersion'),
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
    VoidCallback? onTapAddPr,
  }) {
    final palette = _palette;
    final filled = items
        .where((item) => item.result.trim().isNotEmpty)
        .toList();
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MetaGymTap(
                  borderRadius: BorderRadius.circular(10),
                  onTap: interactive
                      ? () => setState(() => _openCard = _EditCard.achievements)
                      : null,
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: palette.chipActiveBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: MetaGymTheme.primary.withValues(alpha: 0.36),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const MetaGymSvgIcon(
                          MetaGymIcons.progressAchievementPr,
                          size: 18,
                          fallbackIcon: Icons.emoji_events_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thành tích của bạn',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              interactive
                                  ? 'Chạm để sửa · Hoặc thêm PR nhanh'
                                  : 'Thành tích đã lưu',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (interactive && onTapAddPr != null) ...[
                const SizedBox(width: 8),
                MetaGymTap(
                  key: const Key('journal-open-add-pr'),
                  borderRadius: BorderRadius.circular(999),
                  onTap: onTapAddPr,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: palette.chipActiveBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+ Thêm',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (filled.isEmpty)
            MetaGymTap(
              borderRadius: BorderRadius.circular(10),
              onTap: interactive
                  ? () => setState(() => _openCard = _EditCard.achievements)
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Chưa ghi thành tích',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            ...filled.map(
              (item) => Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: palette.borderSolid.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      item.result,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 13.5,
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
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: palette.borderSolid.withValues(alpha: 0.7),
                  ),
                ),
              ),
              child: Text(
                notes.trim(),
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableAchievementCard(_DayDraft draft) {
    final palette = _palette;
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thành tích của bạn',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              MetaGymTap(
                key: const Key('journal-open-add-pr-inline'),
                borderRadius: BorderRadius.circular(999),
                onTap: () => _openAddPrSheet(draft),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.chipActiveBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: MetaGymTheme.brandOrange.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '+ Mở máy tính PR',
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Thu gọn thành tích',
                onPressed: () => setState(() => _openCard = null),
                icon: const MetaGymSvgIcon(
                  MetaGymIcons.commonChevronUp,
                  fallbackIcon: Icons.keyboard_arrow_up_rounded,
                ),
              ),
            ],
          ),
          Text(
            'Tùy chọn · Chỉ lưu bài bạn đã ghi',
            style: TextStyle(color: palette.textSecondary, fontSize: 11),
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
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : SizedBox(
                            height: 48,
                            child: TextFormField(
                              key: ValueKey('custom-name-$index-$_modalSyncVersion'),
                              initialValue: row.title,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _inlineInputDecoration('Tên bài'),
                              onChanged: (v) => setState(() => row.title = v),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 116,
                    height: 48,
                    child: TextFormField(
                      key: ValueKey('ach-result-$index-$_modalSyncVersion'),
                      initialValue: row.result,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
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
                      icon: const MetaGymSvgIcon(
                        MetaGymIcons.commonClose,
                        size: 18,
                        fallbackIcon: Icons.close_rounded,
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
                foregroundColor: palette.primaryText,
                backgroundColor: palette.chipActiveBg,
                side: BorderSide(
                  color: MetaGymTheme.primary.withValues(alpha: 0.42),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => setState(() {
                draft.achievements.add(
                  _AchievementDraft(title: '', result: ''),
                );
              }),
              icon: const MetaGymSvgIcon(MetaGymIcons.commonAdd, size: 17, fallbackIcon: Icons.add_rounded),
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
            style: TextStyle(color: palette.textPrimary, fontSize: 12.5),
            decoration: _inlineInputDecoration('Ghi chú buổi tập (tùy chọn)'),
            onChanged: (v) => setState(() => draft.notes = v),
          ),
        ],
      ),
    );
  }

  InputDecoration _inlineInputDecoration(String hint) {
    final palette = _palette;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: palette.textSecondary.withValues(alpha: 0.65),
        fontSize: 12,
      ),
      filled: true,
      fillColor: palette.metricPanelBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.metricPanelBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: MetaGymTheme.brandOrange),
      ),
    );
  }

  Widget _buildProgressTab() {
    final palette = _palette;
    final colors = _colors;
    final latestMeasure = _measurements.isNotEmpty ? _measurements.first : null;
    final latestWeight =
        latestMeasure?.weightKg ?? _summary?.latestMeasurement?.weightKg;
    final workoutCount = _summary?.workoutCount;

    String weightDeltaLabel = 'Chưa đủ dữ liệu';
    if (_weightPoints.length >= 2) {
      final delta = _weightPoints.last.weightKg - _weightPoints.first.weightKg;
      final sign = delta <= 0 ? '↓' : '↑';
      weightDeltaLabel =
          '$sign ${delta.abs().toStringAsFixed(1)} kg · $_chartRange';
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
    final latestFat = latestMeasure?.bodyFatPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaGymHeroGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TỔNG QUAN TIẾN ĐỘ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Theo dõi chỉ số & PR',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusPill(
                    label: _weightPoints.length >= 2
                        ? '↑ Tiến bộ tốt'
                        : 'Đang theo dõi',
                    color: palette.success,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MetaGymMetricPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Cân nặng',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            latestWeight == null
                                ? '—'
                                : '${latestWeight.toStringAsFixed(1)} kg',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            weightDeltaLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.success,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetaGymMetricPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Mỡ cơ thể',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            latestFat == null
                                ? '—'
                                : '${latestFat.toStringAsFixed(1)}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            latestDate ?? 'Chưa đo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MetaGymMetricPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Số buổi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            workoutCount == null ? '—' : '$workoutCount buổi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.primaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_entries.length} nhật ký',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.success,
                              fontSize: 10.5,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MetaGymSvgIcon(
                        MetaGymIcons.statsChartLine,
                        size: 17,
                        fallbackIcon: Icons.show_chart_rounded,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Biểu đồ cân nặng',
                        style: TextStyle(
                          color: palette.textPrimary,
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
                          style: TextStyle(
                            color: palette.success,
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
                          dropdownColor: colors.surface,
                          style: TextStyle(
                            color: palette.primaryText,
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
              Text(
                'Thay đổi theo những lần bạn nhập số đo',
                style: TextStyle(color: palette.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 14),
              if (_weightPoints.length < 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Cần ít nhất 2 lần cân để vẽ biểu đồ.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
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
                              getDrawingHorizontalLine: (_) => FlLine(
                                color: palette.borderSolid.withValues(
                                  alpha: 0.7,
                                ),
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
                                      style: TextStyle(
                                        color: palette.textSecondary,
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
                                  interval: 1,
                                  getTitlesWidget: (value, _) {
                                    if ((value - value.roundToDouble()).abs() >
                                        0.01) {
                                      return const SizedBox.shrink();
                                    }
                                    final idx = value.round();
                                    final total = _weightPoints.length;
                                    if (idx < 0 || idx >= total) {
                                      return const SizedBox.shrink();
                                    }
                                    final step = (total / 4).ceil().clamp(1, 999);
                                    final isEdge = idx == 0 || idx == total - 1;
                                    if (!isEdge &&
                                        (idx % step != 0 ||
                                            total - 1 - idx < step / 2)) {
                                      return const SizedBox.shrink();
                                    }
                                    final d = _parseIsoDate(
                                      _weightPoints[idx].measuredAt,
                                    );
                                    return Text(
                                      d == null
                                          ? ''
                                          : DateFormat('d/M').format(d),
                                      style: TextStyle(
                                        color: palette.textSecondary,
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
                                          ? palette.success
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
                  Text(
                    'Số đo cơ thể',
                    style: TextStyle(
                      color: palette.textPrimary,
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
                    child: Text(
                      'Xem lịch sử ›',
                      style: TextStyle(
                        color: palette.primaryText,
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
                style: TextStyle(color: palette.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 10),
              _MeasureRow(
                label: 'Vòng ngực',
                value: chest == null ? '—' : '${chest.toStringAsFixed(1)} cm',
                dotColor: palette.primaryText,
              ),
              _MeasureRow(
                label: 'Vòng eo',
                value: waist == null ? '—' : '${waist.toStringAsFixed(1)} cm',
                dotColor: palette.success,
              ),
              _MeasureRow(
                label: 'Vòng hông',
                value: hips == null ? '—' : '${hips.toStringAsFixed(1)} cm',
                dotColor: palette.reflection,
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
                      color: palette.chipActiveBg,
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
                  Expanded(
                    child: Text(
                      'Thành tích tập luyện',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (highlights.isEmpty)
                Text(
                  'Ghi thành tích ở tab Nhật ký để theo dõi tiến bộ.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                )
              else
                for (final (idx, item) in highlights.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: idx > 0
                        ? BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: palette.borderSolid.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          )
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        Text(
                          item.result,
                          style: TextStyle(
                            color: palette.primaryText,
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

  Widget _buildBanner(String text, {required bool isError}) {
    final palette = _palette;
    final accent = isError ? palette.error : palette.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildErrorCard() => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: _palette.textPrimary, fontSize: 13),
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
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymTap(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: MetaGymTheme.stateDurationOf(context),
        curve: Curves.easeOutCubic,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6D48), Color(0xFFFF5E36)],
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x33FF5E36),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : palette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return IconButton(
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: onTap,
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: palette.metricPanelBg,
          shape: BoxShape.circle,
          border: Border.all(color: palette.metricPanelBorder),
        ),
        alignment: Alignment.center,
        child: MetaGymResolvedIcon(
          icon,
          size: 18,
          fallbackColor: palette.primaryText,
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymTap(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: AnimatedContainer(
        duration: MetaGymTheme.stateDurationOf(context),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6D48), Color(0xFFFF5E36)],
                )
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : palette.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _QuickToolChip extends StatelessWidget {
  const _QuickToolChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MetaGymTap(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MetaGymSvgIcon(
                icon,
                size: 14,
                color: color,
                adaptForLightMode: false,
                fallbackIcon: Icons.tune_rounded,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryMetricBox extends StatelessWidget {
  const _PrimaryMetricBox({
    required this.label,
    required this.value,
    this.interactive = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: interactive
              ? MetaGymTheme.brandOrange.withValues(alpha: 0.28)
              : palette.metricPanelBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (interactive)
                MetaGymSvgIcon(
                  MetaGymIcons.commonEdit,
                  size: 13,
                  color: palette.primaryText,
                  adaptForLightMode: false,
                  fallbackIcon: Icons.edit_outlined,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
    if (!interactive || onTap == null) return box;
    return MetaGymTap(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: box,
    );
  }
}

class _SecondaryMetricBox extends StatelessWidget {
  const _SecondaryMetricBox({
    required this.label,
    required this.value,
    required this.accentColor,
    this.interactive = false,
    this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final Color accentColor;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: interactive ? 0.42 : 0.30),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (interactive) ...[
                const SizedBox(width: 3),
                MetaGymSvgIcon(
                  MetaGymIcons.commonEdit,
                  size: 11,
                  color: accentColor,
                  adaptForLightMode: false,
                  fallbackIcon: Icons.edit_outlined,
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
    if (!interactive || onTap == null) return box;
    return MetaGymTap(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: box,
    );
  }
}

class _MiniGenderChip extends StatelessWidget {
  const _MiniGenderChip({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MetaGymTheme.stateDurationOf(context),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6D48), Color(0xFFFF5E36)],
                  )
                : null,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : palette.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.borderSolid.withValues(alpha: 0.7)),
        ),
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
                style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Container(
        color: palette.surfaceRaised,
        child: FutureBuilder<Uri>(
          future: _accessUrl,
          builder: (context, snapshot) => snapshot.hasData
              ? Image.network(
                  snapshot.data.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => MetaGymSvgIcon(MetaGymIcons.stateBrokenImage, fallbackIcon: Icons.broken_image_outlined),
                )
              : MetaGymSvgIcon(MetaGymIcons.mediaGallery, fallbackIcon: Icons.image_outlined),
        ),
      ),
    );
  }
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
