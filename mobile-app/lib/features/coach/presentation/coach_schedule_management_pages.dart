import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:provider/provider.dart';

const List<String> _kWorkSlotCatalog = <String>[
  '06:00',
  '07:30',
  '08:00',
  '09:00',
  '09:30',
  '10:30',
  '11:00',
  '12:00',
  '12:30',
  '14:00',
  '15:30',
  '17:00',
  '17:30',
  '18:30',
  '19:00',
];

const List<({String id, String label, List<String> slots})> _kSchedulePresets =
    [
      (
        id: 'morning-early',
        label: 'Ca sáng sớm (06:00 – 12:00)',
        slots: ['06:00', '07:30', '09:00', '10:30'],
      ),
      (
        id: 'morning-std',
        label: 'Ca sáng (08:00 – 14:00)',
        slots: ['08:00', '09:30', '11:00', '12:30'],
      ),
      (
        id: 'afternoon',
        label: 'Ca chiều tối (14:00 – 20:00)',
        slots: ['14:00', '15:30', '17:00', '18:30'],
      ),
      (
        id: 'full-day',
        label: 'Cả ngày (8 ca 90p)',
        slots: [
          '06:00',
          '07:30',
          '09:00',
          '10:30',
          '14:00',
          '15:30',
          '17:30',
          '19:00',
        ],
      ),
    ];

const Map<int, String> _kFullWeekdayLabels = <int, String>{
  1: 'Thứ 2',
  2: 'Thứ 3',
  3: 'Thứ 4',
  4: 'Thứ 5',
  5: 'Thứ 6',
  6: 'Thứ 7',
  7: 'Chủ nhật',
};

String _twoDigits(int value) => value.toString().padLeft(2, '0');

DateTime _toGymLocal(DateTime utcOrLocal) =>
    utcOrLocal.toUtc().add(const Duration(hours: 7));

String _formatIsoYmd(DateTime d) =>
    '${d.year}-${_twoDigits(d.month)}-${_twoDigits(d.day)}';

String _formatDmyDate(DateTime d) =>
    '${_twoDigits(d.day)}/${_twoDigits(d.month)}/${d.year}';

String _weekdayShort(int weekday) => weekday == 7 ? 'CN' : 'T${weekday + 1}';

String _format90MinRange(String startClock) {
  final parts = startClock.split(':');
  if (parts.length != 2) return startClock;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return startClock;
  final totalEnd = h * 60 + m + 90;
  final eh = (totalEnd ~/ 60) % 24;
  final em = totalEnd % 60;
  return '$startClock – ${_twoDigits(eh)}:${_twoDigits(em)}';
}

T? _tryReadOpt<T>(BuildContext context) {
  try {
    return context.read<T?>();
  } on ProviderNotFoundException {
    return null;
  } catch (_) {
    return null;
  }
}

/// Màn hình **2.2 Lịch làm việc cố định (Tuần)** (`detail.js`).
class CoachWorkWeekPage extends StatefulWidget {
  const CoachWorkWeekPage({
    this.apiClient,
    this.coachId,
    this.initialDays,
    this.hasActiveMembers,
    this.previewMode = false,
    this.useSolidGlassFallback = false,
    this.onSaved,
    super.key,
  });

  final ApiClient? apiClient;
  final String? coachId;
  final List<CoachRecord>? initialDays;
  final bool? hasActiveMembers;
  final bool previewMode;
  final bool useSolidGlassFallback;
  final ValueChanged<List<CoachRecord>>? onSaved;

  @override
  State<CoachWorkWeekPage> createState() => _CoachWorkWeekPageState();
}

class _CoachWorkWeekPageState extends State<CoachWorkWeekPage> {
  ApiClient? _client;
  bool _initialized = false;
  bool _loading = true;
  bool _saving = false;
  bool _hasActiveMembers = false;
  int _expandedWeekday = 1;
  String? _loadError;
  String? _saveError;

  final Map<int, List<String>> _daySlots = <int, List<String>>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(
        MetaGymBackground.darkAppBackgroundAsset,
        context,
      ).catchError((_) {});
      precacheImage(
        MetaGymBackground.lightAppBackgroundAsset,
        context,
      ).catchError((_) {});
    }
    if (_initialized) return;
    _initialized = true;
    _client = widget.apiClient ?? _tryReadOpt<ApiClient>(context);
    _hasActiveMembers = widget.hasActiveMembers ?? false;
    _load();
  }

  Future<void> _load() async {
    if (widget.previewMode) {
      _applyDaysList(const [
        {
          'weekday': 1,
          'starts': [
            '06:00',
            '07:30',
            '09:00',
            '10:30',
            '14:00',
            '15:30',
            '17:30',
            '19:00',
          ],
        },
        {
          'weekday': 2,
          'starts': ['06:00', '07:30', '09:00', '10:30', '14:00', '15:30'],
        },
        {
          'weekday': 3,
          'starts': ['06:00', '07:30', '09:00', '10:30', '14:00', '15:30'],
        },
        {
          'weekday': 4,
          'starts': ['06:00', '07:30', '09:00', '10:30', '14:00', '15:30'],
        },
        {
          'weekday': 5,
          'starts': ['06:00', '07:30', '09:00', '10:30', '14:00', '15:30'],
        },
        {
          'weekday': 6,
          'starts': ['07:30', '09:00', '10:30', '14:00', '15:30', '17:30'],
        },
      ]);
      if (!mounted) return;
      setState(() {
        _hasActiveMembers = widget.hasActiveMembers ?? true;
        _loading = false;
        _loadError = null;
      });
      return;
    }

    if (widget.initialDays != null) {
      _applyDaysList(widget.initialDays!);
      setState(() {
        _loading = false;
        _loadError = null;
      });
      return;
    }

    final client = _client;
    final coachId =
        widget.coachId ??
        _tryReadOpt<SessionController>(context)?.user?.id ??
        '';
    if (client == null || coachId.isEmpty) {
      _applyDefaultDays();
      setState(() {
        _loading = false;
        _loadError = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final api = CoachV2Api(client);
      final membersService = widget.hasActiveMembers == null
          ? _tryReadOpt<CoachMembersService>(context)
          : null;
      final schedule = await api.get('/coaches/$coachId/work-slots');
      final days = (schedule['days'] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      bool activeMembersFlag = _hasActiveMembers;
      if (membersService != null && membersService is CoachMembersApi) {
        try {
          final members = await membersService.getMembers();
          activeMembersFlag = members.any((m) => m.status == 'ACTIVE');
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        if (days.isEmpty) {
          _applyDefaultDays();
        } else {
          _applyDaysList(days);
        }
        _hasActiveMembers = activeMembersFlag;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Không tải được lịch làm việc tuần.';
      });
    }
  }

  void _applyDefaultDays() {
    _daySlots.clear();
    for (var wd = 1; wd <= 6; wd++) {
      _daySlots[wd] = List<String>.from(_kSchedulePresets[0].slots);
    }
  }

  void _applyDaysList(List<CoachRecord> days) {
    _daySlots.clear();
    for (final row in days) {
      final wd = (row['weekday'] as num?)?.toInt();
      if (wd == null || wd < 1 || wd > 7) continue;
      final starts =
          (row['starts'] as List? ?? const [])
              .map((e) => e.toString())
              .where((s) => s.trim().isNotEmpty)
              .toList()
            ..sort();
      if (starts.isNotEmpty) {
        _daySlots[wd] = starts;
      }
    }
  }

  void _toggleDay(int weekday, bool active) {
    setState(() {
      _saveError = null;
      if (active) {
        _daySlots[weekday] ??= List<String>.from(_kSchedulePresets[0].slots);
        _expandedWeekday = weekday;
      } else {
        _daySlots.remove(weekday);
      }
    });
  }

  void _toggleSlot(int weekday, String slot) {
    setState(() {
      _saveError = null;
      final current = List<String>.from(_daySlots[weekday] ?? const []);
      if (current.contains(slot)) {
        current.remove(slot);
      } else {
        current.add(slot);
        current.sort();
      }
      _daySlots[weekday] = current;
    });
  }

  void _applyPresetToWeekdays(List<String> slots) {
    setState(() {
      _saveError = null;
      for (var wd = 1; wd <= 6; wd++) {
        _daySlots[wd] = List<String>.from(slots);
      }
    });
  }

  String _summarizeSlots(List<String> slots) {
    if (slots.isEmpty) return 'Chưa chọn ca dạy';
    final first = _format90MinRange(slots.first);
    final last = _format90MinRange(slots.last);
    if (slots.length == 1) return first;
    final startPart = first.split(' – ').first;
    final endPart = last.split(' – ').last;
    return '$startPart – $endPart · ${slots.length} ca 90p';
  }

  Future<void> _save() async {
    final activeCount = _daySlots.length;
    if (activeCount < 6) {
      setState(() {
        _saveError = 'Cần mở tối thiểu 6 ngày/tuần để đảm bảo quy chuẩn Coach.';
      });
      return;
    }
    for (final entry in _daySlots.entries) {
      if (entry.value.length < 4) {
        setState(() {
          _saveError =
              '${_kFullWeekdayLabels[entry.key]} cần tối thiểu 4 khung giờ 90 phút.';
          _expandedWeekday = entry.key;
        });
        return;
      }
    }

    final payloadDays = <CoachRecord>[
      for (var wd = 1; wd <= 7; wd++)
        if (_daySlots.containsKey(wd))
          {'weekday': wd, 'starts': _daySlots[wd]!},
    ];

    if (widget.previewMode || _client == null) {
      widget.onSaved?.call(payloadDays);
      if (mounted) {
        showCoachingSnackBar(
          context,
          'Đã lưu lịch làm việc tuần ($activeCount/7 ngày).',
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await CoachV2Api(_client!)
          .put('/coach/work-slots', {'days': payloadDays});
      widget.onSaved?.call(payloadDays);
      if (!mounted) return;
      showCoachingSnackBar(
        context,
        'Đã lưu lịch làm việc tuần ($activeCount/7 ngày).',
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _saveError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _saveError = 'Không lưu được lịch làm việc tuần.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final activeCount = _daySlots.length;
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MetaGymBackground(useSolidFallback: widget.useSolidGlassFallback),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _SchedulePageHeader(
                  eyebrow: 'THIẾT LẬP LỊCH DẠY',
                  title: 'Lịch làm việc tuần',
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: colors.overlayGlass,
                          onRefresh: _load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              4,
                              gutter,
                              MediaQuery.paddingOf(context).bottom + 118,
                            ),
                            children: [
                              if (_loadError != null) ...[
                                CoachingErrorBanner(message: _loadError!),
                                CoachingSecondaryButton(
                                  label: 'Thử lại',
                                  expand: true,
                                  onPressed: _load,
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_saveError != null) ...[
                                CoachingErrorBanner(message: _saveError!),
                                const SizedBox(height: 4),
                              ],
                              // Hero Card: Quy chuẩn lịch Coach
                              MetaGymHeroGlassCard(
                                useSolidFallback: widget.useSolidGlassFallback,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const MetaGymIcon(
                                          MetaGymIcons.actionCoachWorkweek,
                                          size: MetaGymIconSize.sm,
                                          excludeFromSemantics: true,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Quy chuẩn lịch Coach',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          flex: 0,
                                          child: CoachingPill(
                                            label: '$activeCount / 7 ngày',
                                            tone: activeCount >= 6
                                                ? CoachingPillTone.green
                                                : CoachingPillTone.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text.rich(
                                      TextSpan(
                                        style: TextStyle(
                                          color: colors.textWarmMuted,
                                          fontSize: 12.5,
                                          height: 1.45,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'Cần mở tối thiểu ',
                                          ),
                                          TextSpan(
                                            text: '6 ngày/tuần',
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: ', mỗi ngày tối thiểu ',
                                          ),
                                          TextSpan(
                                            text: '4 khung 90 phút liên tiếp',
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const TextSpan(text: '.'),
                                        ],
                                      ),
                                    ),
                                    if (_hasActiveMembers) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.warning.withValues(
                                            alpha: isLight ? 0.12 : 0.14,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: colors.warning.withValues(
                                              alpha: 0.36,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Lưu ý backend: Đang có gói HV hiệu lực → lịch cố định có thể tạm khóa thay đổi (409) để bảo toàn ca đặt trước.',
                                          style: TextStyle(
                                            color: isLight
                                                ? const Color(0xFF935104)
                                                : colors.warning,
                                            fontSize: 12,
                                            height: 1.4,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Quick presets strip
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Áp dụng mẫu nhanh (Thứ 2 – Thứ 7)',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final preset in _kSchedulePresets)
                                      _SchedulePillButton(
                                        key: Key(
                                          'workweek-preset-${preset.id}',
                                        ),
                                        label: preset.label,
                                        selected: false,
                                        onTap: () => _applyPresetToWeekdays(
                                          preset.slots,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // 7 weekday card
                              MetaGymGlassCard(
                                solid: widget.useSolidGlassFallback,
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    for (var wd = 1; wd <= 7; wd++) ...[
                                      if (wd > 1)
                                        Divider(
                                          height: 1,
                                          color: colors.metricPanelBorder
                                              .withValues(alpha: 0.45),
                                        ),
                                      _buildWeekdayRow(colors, isLight, wd),
                                    ],
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
          // Sticky bottom CTA dock
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                gutter,
                12,
                gutter,
                MediaQuery.paddingOf(context).bottom + 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.canvas.withValues(alpha: 0.0),
                    colors.canvas.withValues(alpha: 0.90),
                    colors.canvas,
                  ],
                  stops: const [0.0, 0.30, 1.0],
                ),
              ),
              child: CoachingPrimaryButton(
                key: const Key('workweek-save-btn'),
                label: _saving ? 'Đang lưu…' : 'Lưu lịch làm việc tuần',
                icon: Icons.check_rounded,
                onPressed: _loading || _saving ? null : _save,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow(MetaGymColors colors, bool isLight, int weekday) {
    final active = _daySlots.containsKey(weekday);
    final slots = _daySlots[weekday] ?? const <String>[];
    final expanded = _expandedWeekday == weekday && active;
    final dayLabel = _kFullWeekdayLabels[weekday]!;
    final visibleChips = slots.take(4).toList();
    final extraCount = mathMaxZero(slots.length - visibleChips.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: active
              ? () => setState(() {
                  _expandedWeekday = expanded ? -1 : weekday;
                })
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active
                                ? _summarizeSlots(slots)
                                : 'Ngày nghỉ định kỳ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: active
                                  ? (slots.length >= 4
                                        ? colors.success
                                        : colors.warning)
                                  : colors.textSecondary,
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      key: Key('workweek-toggle-$weekday'),
                      value: active,
                      activeTrackColor: colors.success,
                      activeThumbColor: Colors.white,
                      onChanged: (val) => _toggleDay(weekday, val),
                    ),
                  ],
                ),
                if (active && visibleChips.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final clock in visibleChips)
                        _SlotMicroPill(
                          label: clock,
                          highlight: true,
                          isLight: isLight,
                          colors: colors,
                        ),
                      if (extraCount > 0)
                        _SlotMicroPill(
                          label: '+$extraCount ca chiều',
                          highlight: false,
                          isLight: isLight,
                          colors: colors,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: colors.metricPanelBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.metricPanelBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn các khung bắt đầu ca (tối thiểu 4 ca)',
                  style: TextStyle(
                    color: colors.textWarmMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final clock in _kWorkSlotCatalog)
                      _SchedulePillButton(
                        label: clock,
                        selected: slots.contains(clock),
                        compact: true,
                        onTap: () => _toggleSlot(weekday, clock),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

int mathMaxZero(int val) => val < 0 ? 0 : val;

/// Màn hình **2.3 Chặn khung giờ bận** (`detail.js`).
class CoachBlockedSlotsPage extends StatefulWidget {
  const CoachBlockedSlotsPage({
    this.apiClient,
    this.coachId,
    this.initialDays,
    this.initialBlocks,
    this.previewMode = false,
    this.useSolidGlassFallback = false,
    this.onChanged,
    super.key,
  });

  final ApiClient? apiClient;
  final String? coachId;
  final List<CoachRecord>? initialDays;
  final List<CoachRecord>? initialBlocks;
  final bool previewMode;
  final bool useSolidGlassFallback;
  final VoidCallback? onChanged;

  @override
  State<CoachBlockedSlotsPage> createState() => _CoachBlockedSlotsPageState();
}

class _CoachBlockedSlotsPageState extends State<CoachBlockedSlotsPage> {
  static const List<String> _quickReasons = <String>[
    'Họp chuyên môn nội bộ',
    'Lịch bận cá nhân',
    'Kiểm tra thể lực định kỳ',
  ];

  final TextEditingController _reasonController = TextEditingController(
    text: 'Họp chuyên môn huấn luyện viên',
  );

  ApiClient? _client;
  bool _initialized = false;
  bool _loading = true;
  bool _mutating = false;
  String? _loadError;
  String? _formError;

  late DateTime _selectedDate;
  String _selectedSlot = '14:00';
  List<CoachRecord> _workDays = const [];
  List<CoachRecord> _blocks = [];

  @override
  void initState() {
    super.initState();
    final gymNow = _toGymLocal(DateTime.now());
    _selectedDate = DateTime(
      gymNow.year,
      gymNow.month,
      gymNow.day,
    ).add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(
        MetaGymBackground.darkAppBackgroundAsset,
        context,
      ).catchError((_) {});
      precacheImage(
        MetaGymBackground.lightAppBackgroundAsset,
        context,
      ).catchError((_) {});
    }
    if (_initialized) return;
    _initialized = true;
    _client = widget.apiClient ?? _tryReadOpt<ApiClient>(context);
    _load();
  }

  Future<void> _load() async {
    if (widget.previewMode) {
      final base = _toGymLocal(DateTime.now());
      final d1 = DateTime(
        base.year,
        base.month,
        base.day,
      ).add(const Duration(days: 1));
      final d2 = DateTime(
        base.year,
        base.month,
        base.day,
      ).add(const Duration(days: 3));
      setState(() {
        _workDays = const [
          {
            'weekday': 1,
            'starts': ['06:00', '09:00', '14:00', '18:00', '19:30'],
          },
          {
            'weekday': 2,
            'starts': ['06:00', '09:00', '14:00', '18:00', '19:30'],
          },
          {
            'weekday': 3,
            'starts': ['06:00', '09:00', '14:00', '18:00', '19:30'],
          },
          {
            'weekday': 4,
            'starts': ['06:00', '09:00', '14:00', '18:00', '19:30'],
          },
          {
            'weekday': 5,
            'starts': ['06:00', '09:00', '14:00', '18:00', '19:30'],
          },
          {
            'weekday': 6,
            'starts': ['06:00', '09:00', '14:00', '18:00', '19:30'],
          },
        ];
        _blocks = [
          {
            'startsAt': '${_formatIsoYmd(d1)}T14:00:00+07:00',
            'reason': 'Họp chuyên môn nội bộ · Học viên không thể đặt',
          },
          {
            'startsAt': '${_formatIsoYmd(d2)}T09:00:00+07:00',
            'reason': 'Kiểm tra thể lực định kỳ cá nhân',
          },
        ];
        _selectedDate = d1;
        _ensureSelectedSlotValid();
        _loading = false;
        _loadError = null;
      });
      return;
    }

    if (widget.initialBlocks != null) {
      setState(() {
        _workDays = widget.initialDays ?? const [];
        _blocks = List<CoachRecord>.from(widget.initialBlocks!);
        _ensureSelectedSlotValid();
        _loading = false;
        _loadError = null;
      });
      return;
    }

    final client = _client;
    if (client == null) {
      setState(() {
        _workDays = widget.initialDays ?? const [];
        _blocks = const [];
        _ensureSelectedSlotValid();
        _loading = false;
        _loadError = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    final coachId =
        widget.coachId ??
        _tryReadOpt<SessionController>(context)?.user?.id ??
        '';

    try {
      final api = CoachV2Api(client);
      final blocks = await api.list('/coach-bookings/blocks');
      List<CoachRecord> days = widget.initialDays ?? const [];
      if (days.isEmpty && coachId.isNotEmpty) {
        try {
          final schedule = await api.get('/coaches/$coachId/work-slots');
          days = (schedule['days'] as List? ?? const [])
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _workDays = days;
        _blocks = List<CoachRecord>.from(blocks);
        _ensureSelectedSlotValid();
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Không tải được danh sách khung giờ đã khóa.';
      });
    }
  }

  List<String> _slotsForSelectedDate() {
    for (final row in _workDays) {
      if ((row['weekday'] as num?)?.toInt() == _selectedDate.weekday) {
        final starts =
            (row['starts'] as List? ?? const [])
                .map((e) => e.toString())
                .where((s) => s.trim().isNotEmpty)
                .toList()
              ..sort();
        if (starts.isNotEmpty) return starts;
      }
    }
    return const ['06:00', '09:00', '14:00', '18:00', '19:30'];
  }

  void _ensureSelectedSlotValid() {
    final slots = _slotsForSelectedDate();
    if (slots.isNotEmpty && !slots.contains(_selectedSlot)) {
      _selectedSlot = slots.first;
    }
  }

  String _isoFor(DateTime date, String slot) =>
      '${_formatIsoYmd(date)}T$slot:00+07:00';

  bool _isSlotBlockedOnDate(DateTime date, String slot) {
    final targetPrefix = '${_formatIsoYmd(date)}T$slot';
    for (final row in _blocks) {
      final raw = row['startsAt'] as String? ?? '';
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        final local = _toGymLocal(parsed);
        final localKey =
            '${_formatIsoYmd(local)}T${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
        if (localKey == targetPrefix) return true;
      } else if (raw.startsWith(targetPrefix)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pickDate() async {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final gymToday = _toGymLocal(DateTime.now());
    final first = DateTime(gymToday.year, gymToday.month, gymToday.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(first) ? first : _selectedDate,
      firstDate: first,
      lastDate: first.add(const Duration(days: 190)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isLight
              ? ColorScheme.light(
                  primary: MetaGymTheme.brandOrange,
                  onPrimary: Colors.white,
                  surface: colors.overlayGlass,
                  onSurface: colors.textPrimary,
                )
              : ColorScheme.dark(
                  primary: MetaGymTheme.brandOrange,
                  onPrimary: Colors.white,
                  surface: colors.overlayGlass,
                  onSurface: colors.textPrimary,
                  surfaceContainerHigh: colors.surfaceRaised,
                ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _formError = null;
      _ensureSelectedSlotValid();
    });
  }

  Future<void> _submitBlock() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _formError = 'Vui lòng nhập lý do khóa ca.');
      return;
    }

    final startsAtIso = _isoFor(_selectedDate, _selectedSlot);
    if (widget.previewMode || _client == null) {
      setState(() {
        _formError = null;
        if (!_isSlotBlockedOnDate(_selectedDate, _selectedSlot)) {
          _blocks = [
            {'startsAt': startsAtIso, 'reason': reason},
            ..._blocks,
          ];
        }
      });
      widget.onChanged?.call();
      if (mounted) {
        showCoachingSnackBar(
          context,
          'Đã khóa ca ${_format90MinRange(_selectedSlot)} ngày ${_formatDmyDate(_selectedDate)}.',
        );
      }
      return;
    }

    setState(() {
      _mutating = true;
      _formError = null;
    });
    try {
      await CoachV2Api(_client!).put('/coach-bookings/blocks', {
        'startsAt': startsAtIso,
        'blocked': true,
        'reason': reason,
      });
      widget.onChanged?.call();
      if (!mounted) return;
      showCoachingSnackBar(
        context,
        'Đã khóa ca ${_format90MinRange(_selectedSlot)} ngày ${_formatDmyDate(_selectedDate)}.',
      );
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _formError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Không khóa được khung giờ này.');
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _unblock(CoachRecord block) async {
    final startsAt = block['startsAt'] as String? ?? '';
    if (startsAt.isEmpty || _mutating) return;

    if (widget.previewMode || _client == null) {
      setState(() {
        _blocks = _blocks.where((row) => row['startsAt'] != startsAt).toList();
      });
      widget.onChanged?.call();
      if (mounted) showCoachingSnackBar(context, 'Đã mở lại khung giờ.');
      return;
    }

    setState(() => _mutating = true);
    try {
      await CoachV2Api(
        _client!,
      ).put('/coach-bookings/blocks', {'startsAt': startsAt, 'blocked': false});
      widget.onChanged?.call();
      if (!mounted) return;
      showCoachingSnackBar(context, 'Đã mở lại khung giờ.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) showCoachingSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        showCoachingSnackBar(context, 'Không mở lại được khung giờ.');
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  String _formatBlockHeadline(String rawStartsAt) {
    final parsed = DateTime.tryParse(rawStartsAt);
    if (parsed == null) return rawStartsAt;
    final gym = _toGymLocal(parsed);
    final clock = '${_twoDigits(gym.hour)}:${_twoDigits(gym.minute)}';
    return '${_weekdayShort(gym.weekday)}, ${_twoDigits(gym.day)}/${_twoDigits(gym.month)} · ${_format90MinRange(clock)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final slots = _slotsForSelectedDate();
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MetaGymBackground(useSolidFallback: widget.useSolidGlassFallback),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _SchedulePageHeader(
                  eyebrow: 'KHÓA LỊCH CÁ NHÂN',
                  title: 'Chặn khung giờ bận',
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).maybePop()
                      : null,
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : RefreshIndicator(
                          color: MetaGymTheme.brandOrange,
                          backgroundColor: colors.overlayGlass,
                          onRefresh: _load,
                          child: ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              gutter,
                              4,
                              gutter,
                              MediaQuery.paddingOf(context).bottom + 40,
                            ),
                            children: [
                              if (_loadError != null) ...[
                                CoachingErrorBanner(message: _loadError!),
                                CoachingSecondaryButton(
                                  label: 'Thử lại',
                                  expand: true,
                                  onPressed: _load,
                                ),
                                const SizedBox(height: 12),
                              ],
                              MetaGymGlassCard(
                                solid: widget.useSolidGlassFallback,
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const MetaGymIcon(
                                          MetaGymIcons.actionCoachBlockSlot,
                                          size: MetaGymIconSize.sm,
                                          excludeFromSemantics: true,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Khóa 1 ca 90 phút bận cá nhân',
                                            maxLines: 1,
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
                                    const SizedBox(height: 12),
                                    Text(
                                      'Ngày cần khóa',
                                      style: TextStyle(
                                        color: colors.textWarmMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      key: const Key('blocked-slot-date-btn'),
                                      onTap: _pickDate,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minHeight: 48,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 11,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.metricPanelBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: colors.metricPanelBorder,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${_weekdayShort(_selectedDate.weekday)}, ${_formatDmyDate(_selectedDate)}',
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  fontFeatures: MetaGymTheme
                                                      .tabularFigures,
                                                ),
                                              ),
                                            ),
                                            const MetaGymIcon(
                                              MetaGymIcons.workoutPlanCalendar,
                                              size: MetaGymIconSize.sm,
                                              excludeFromSemantics: true,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Chọn ca 90 phút theo lịch tuần',
                                      style: TextStyle(
                                        color: colors.textWarmMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final slot in slots)
                                          Builder(
                                            builder: (context) {
                                              final alreadyBlocked =
                                                  _isSlotBlockedOnDate(
                                                    _selectedDate,
                                                    slot,
                                                  );
                                              return _SchedulePillButton(
                                                label: alreadyBlocked
                                                    ? '${_format90MinRange(slot)} · Đã khóa'
                                                    : _format90MinRange(slot),
                                                selected: _selectedSlot == slot,
                                                disabled: alreadyBlocked,
                                                onTap: alreadyBlocked
                                                    ? null
                                                    : () => setState(
                                                        () => _selectedSlot =
                                                            slot,
                                                      ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Lý do khóa ca',
                                      style: TextStyle(
                                        color: colors.textWarmMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final preset in _quickReasons)
                                          _SchedulePillButton(
                                            label: preset,
                                            compact: true,
                                            selected:
                                                _reasonController.text.trim() ==
                                                preset,
                                            onTap: () => setState(() {
                                              _reasonController.text = preset;
                                              _formError = null;
                                            }),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      key: const Key('blocked-slot-reason'),
                                      controller: _reasonController,
                                      maxLength: 300,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Nhập lý do khóa khung giờ…',
                                        hintStyle: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 13.5,
                                        ),
                                        filled: true,
                                        fillColor: colors.metricPanelBg,
                                        counterText: '',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            MetaGymTheme.radiusInput,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.metricPanelBorder,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            MetaGymTheme.radiusInput,
                                          ),
                                          borderSide: BorderSide(
                                            color: colors.metricPanelBorder,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            MetaGymTheme.radiusInput,
                                          ),
                                          borderSide: const BorderSide(
                                            color: MetaGymTheme.brandOrange,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_formError != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _formError!,
                                        style: TextStyle(
                                          color: colors.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    CoachingPrimaryButton(
                                      key: const Key('blocked-slot-submit'),
                                      label: _mutating
                                          ? 'Đang xử lý…'
                                          : 'Khóa ca 90 phút này',
                                      icon: Icons.lock_clock_rounded,
                                      onPressed: _mutating
                                          ? null
                                          : _submitBlock,
                                    ),
                                  ],
                                ),
                              ),

                              // Active blocks header
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Các ca 90 phút đang khóa',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_blocks.length} ca',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures:
                                            MetaGymTheme.tabularFigures,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (_blocks.isEmpty)
                                MetaGymGlassCard(
                                  solid: widget.useSolidGlassFallback,
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: colors.metricPanelBg,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colors.metricPanelBorder,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const MetaGymIcon(
                                          MetaGymIcons.actionCoachBlockSlot,
                                          size: MetaGymIconSize.md,
                                          excludeFromSemantics: true,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Chưa có khung giờ nào đang bị khóa.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Chọn ngày và ca 90 phút phía trên để chặn lịch cá nhân.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.textWarmMuted,
                                          fontSize: 12.5,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                for (var i = 0; i < _blocks.length; i++)
                                  MetaGymGlassCard(
                                    solid: widget.useSolidGlassFallback,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(13),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatBlockHeadline(
                                                  _blocks[i]['startsAt']
                                                          as String? ??
                                                      '',
                                                ),
                                                style: TextStyle(
                                                  color: colors.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  fontFeatures: MetaGymTheme
                                                      .tabularFigures,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                (_blocks[i]['reason']
                                                                as String?)
                                                            ?.trim()
                                                            .isNotEmpty ==
                                                        true
                                                    ? (_blocks[i]['reason']
                                                              as String)
                                                          .trim()
                                                    : 'Học viên không thể đặt khung giờ này',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.textWarmMuted,
                                                  fontSize: 12.5,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Tooltip(
                                          message: 'Mở lại ca',
                                          child: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Material(
                                              color: Colors.transparent,
                                              shape: const CircleBorder(),
                                              clipBehavior: Clip.antiAlias,
                                              child: MetaGymTap(
                                                key: Key(
                                                  'blocked-slot-delete-$i',
                                                ),
                                                onTap: _mutating
                                                    ? null
                                                    : () =>
                                                          _unblock(_blocks[i]),
                                                customBorder:
                                                    const CircleBorder(),
                                                child: Center(
                                                  child: Container(
                                                    width: 36,
                                                    height: 36,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: colors.error
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                      border: Border.all(
                                                        color: colors.error
                                                            .withValues(
                                                              alpha: 0.42,
                                                            ),
                                                      ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: const MetaGymIcon(
                                                      MetaGymIcons.commonDelete,
                                                      size: MetaGymIconSize.xs,
                                                      excludeFromSemantics:
                                                          true,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
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
        ],
      ),
    );
  }
}

class _SchedulePageHeader extends StatelessWidget {
  const _SchedulePageHeader({
    required this.eyebrow,
    required this.title,
    this.onBack,
  });

  final String eyebrow;
  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 10),
      child: Row(
        children: [
          if (onBack != null) ...[
            _ScheduleCircleSvgButton(
              svgAsset: MetaGymIcons.commonBack,
              fallbackIcon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              isLight: isLight,
              onTap: onBack,
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 11,
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
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
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

class _ScheduleCircleSvgButton extends StatelessWidget {
  const _ScheduleCircleSvgButton({
    required this.svgAsset,
    required this.fallbackIcon,
    required this.tooltip,
    required this.isLight,
    required this.onTap,
  });

  final String svgAsset;
  final IconData fallbackIcon;
  final String tooltip;
  final bool isLight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: MetaGymTap(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.circleButtonBg,
                    gradient: isLight
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFFFF), Color(0xFFE5ECF5)],
                          )
                        : null,
                    border: Border.all(
                      color: colors.circleButtonBorder,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MetaGymIcon(
                        svgAsset,
                        size: MetaGymIconSize.md,
                        excludeFromSemantics: true,
                      ),
                      ExcludeSemantics(
                        child: Icon(
                          fallbackIcon,
                          size: 20,
                          color: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchedulePillButton extends StatelessWidget {
  const _SchedulePillButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.disabled = false,
    super.key,
  });

  final String label;
  final bool selected;
  final bool compact;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = disabled
        ? colors.metricPanelBg.withValues(alpha: 0.55)
        : selected
        ? colors.chipActiveBg
        : (isLight ? colors.surface : colors.liquidGlass);
    final border = disabled
        ? colors.metricPanelBorder
        : selected
        ? MetaGymTheme.brandOrange
        : (isLight ? colors.borderStrong : colors.liquidGlassBorder);
    final fg = disabled
        ? colors.textSecondary
        : selected
        ? (isLight ? colors.chipActiveText : colors.textPrimary)
        : colors.textWarmMuted;

    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: label,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
          side: BorderSide(color: border, width: selected ? 1.2 : 1.0),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 11 : 13,
              vertical: compact ? 7 : 9,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotMicroPill extends StatelessWidget {
  const _SlotMicroPill({
    required this.label,
    required this.highlight,
    required this.isLight,
    required this.colors,
  });

  final String label;
  final bool highlight;
  final bool isLight;
  final MetaGymColors colors;

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? colors.success.withValues(alpha: isLight ? 0.14 : 0.16)
        : colors.metricPanelBg;
    final border = highlight
        ? colors.success.withValues(alpha: 0.36)
        : colors.metricPanelBorder;
    final fg = highlight ? colors.success : colors.textWarmMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: MetaGymTheme.tabularFigures,
        ),
      ),
    );
  }
}
