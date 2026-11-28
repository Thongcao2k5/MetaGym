import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

/// Màn hình **5.7 Khám phá Coach** đồng bộ `tab5-profile-sub.js` (`member-coach-selection`)
/// và chuẩn Warm Smoked Liquid Glass (Dark + Light Daylight Studio).
class CoachSelectionPage extends StatefulWidget {
  const CoachSelectionPage({this.service, super.key});

  final CoachSelectionService? service;

  @override
  State<CoachSelectionPage> createState() => _CoachSelectionPageState();
}

class _CoachSelectionPageState extends State<CoachSelectionPage> {
  final _searchController = TextEditingController();
  CoachSelectionService? _service;
  bool _initialized = false;
  List<CoachProfile> _coaches = const [];
  String _selectedFilter = 'ALL';
  String _searchTerm = '';
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final provided =
        widget.service ?? optionalProvider<CoachSelectionService>(context);
    if (provided != null) {
      _service = provided;
    } else {
      final api = optionalProvider<ApiClient>(context);
      if (api != null) {
        _service = CoachSelectionApi(api);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_service != null) {
        _load();
      } else {
        setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final coaches = await service.getCoaches();
      if (mounted) setState(() => _coaches = coaches);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được Coach.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _specialtyFilters {
    final seen = <String>{};
    for (final coach in _coaches) {
      for (final item in coach.specialties) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) seen.add(trimmed);
      }
    }
    return seen.take(6).toList();
  }

  List<CoachProfile> get _filteredCoaches {
    final query = _searchTerm.trim().toLowerCase();
    return _coaches.where((coach) {
      if (_selectedFilter == 'AVAILABLE' && coach.availableSlots <= 0) {
        return false;
      }
      if (_selectedFilter != 'ALL' &&
          _selectedFilter != 'AVAILABLE' &&
          !coach.specialties.any(
            (item) =>
                item.trim().toLowerCase() == _selectedFilter.toLowerCase(),
          )) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack =
          '${coach.fullName} ${coach.specialties.join(' ')} ${coach.qualifications ?? ''}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Widget _buildHeader(BuildContext context, MetaGymColors colors) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          if (canPop) ...[
            MetaGymCircleIconButton(
              svgAsset: MetaGymIcons.commonBack,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HUẤN LUYỆN VIÊN',
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
                  'Khám phá Coach',
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final specialties = _specialtyFilters;
    final filtered = _filteredCoaches;

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
                _buildHeader(context, colors),
                Expanded(
                  child: _loading && _coaches.isEmpty
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
                              16,
                              4,
                              16,
                              MediaQuery.paddingOf(context).bottom + 32,
                            ),
                            children: [
                              if (_error != null) ...[
                                CoachingErrorBanner(message: _error!),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton.icon(
                                    onPressed: _load,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: MetaGymTheme.primary,
                                      foregroundColor: MetaGymTheme.onPrimary,
                                      minimumSize: const Size(120, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const MetaGymSvgIcon(MetaGymIcons.commonRefresh, size: 18, fallbackIcon: Icons.refresh_rounded),
                                    label: const Text(
                                      'Thử lại',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else if (_coaches.isEmpty)
                                MetaGymGlassCard(
                                  solid: false,
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    children: [
                                      const MetaGymIcon(
                                        MetaGymIcons.emptyCoach,
                                        size: MetaGymIconSize.lg,
                                        excludeFromSemantics: true,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Chưa có Coach để lựa chọn.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.textWarmMuted,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                // Ô tìm kiếm Warm Glass đồng bộ .input-box trong 5.7
                                TextField(
                                  key: const Key('coach-search-input'),
                                  controller: _searchController,
                                  onChanged: (value) =>
                                      setState(() => _searchTerm = value),
                                  cursorColor: MetaGymTheme.brandOrange,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Tìm tên hoặc chuyên môn Coach...',
                                    hintStyle: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13.5,
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: MetaGymIcon(
                                        MetaGymIcons.commonSearch,
                                        size: MetaGymIconSize.xs,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                      minWidth: 42,
                                      minHeight: 42,
                                    ),
                                    suffixIcon: _searchTerm.isNotEmpty
                                        ? IconButton(
                                            tooltip: 'Xóa tìm kiếm',
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _searchTerm = '');
                                            },
                                            icon: MetaGymSvgIcon(MetaGymIcons.commonClose, size: 18, fallbackIcon: Icons.close_rounded),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: colors.liquidGlass,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        MetaGymTheme.radiusInput,
                                      ),
                                      borderSide: BorderSide(
                                        color: colors.liquidGlassBorder,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        MetaGymTheme.radiusInput,
                                      ),
                                      borderSide: BorderSide(
                                        color: colors.liquidGlassBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        MetaGymTheme.radiusInput,
                                      ),
                                      borderSide: BorderSide(
                                        color: colors.focus,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 11),
                                // Hàng lọc ngang đồng bộ .filter-row
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _FilterChipButton(
                                        label: 'Tất cả',
                                        selected: _selectedFilter == 'ALL',
                                        onTap: () => setState(
                                          () => _selectedFilter = 'ALL',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _FilterChipButton(
                                        label: 'Còn suất',
                                        selected:
                                            _selectedFilter == 'AVAILABLE',
                                        onTap: () => setState(
                                          () => _selectedFilter = 'AVAILABLE',
                                        ),
                                      ),
                                      for (final spec in specialties) ...[
                                        const SizedBox(width: 8),
                                        _FilterChipButton(
                                          label: spec,
                                          selected: _selectedFilter == spec,
                                          onTap: () => setState(
                                            () => _selectedFilter = spec,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (filtered.isEmpty)
                                  MetaGymGlassCard(
                                    solid: false,
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                      children: [
                                        const MetaGymIcon(
                                          MetaGymIcons.stateEmptySearch,
                                          size: MetaGymIconSize.lg,
                                          excludeFromSemantics: true,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Không tìm thấy Coach',
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Thử tên hoặc chuyên môn khác.',
                                          style: TextStyle(
                                            color: colors.textWarmMuted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchTerm = '';
                                              _selectedFilter = 'ALL';
                                            });
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: colors.primaryText,
                                            minimumSize: const Size(96, 44),
                                          ),
                                          child: const Text(
                                            'Xóa bộ lọc',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  for (var i = 0; i < filtered.length; i++)
                                    _CoachDiscoveryCard(
                                      coach: filtered[i],
                                      paletteIndex: i,
                                      onTap: () =>
                                          MetaGymNavigation.pushOnce<void>(
                                            context,
                                            MetaGymPageRoute(
                                              builder: (_) => CoachDetailPage(
                                                coachId: filtered[i].id,
                                                service: _service!,
                                                paletteIndex: i,
                                              ),
                                            ),
                                          ),
                                    ),
                              ],
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

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        animationDuration: MetaGymTheme.stateDurationOf(context),
        color: selected
            ? MetaGymTheme.primary.withValues(alpha: 0.22)
            : colors.liquidGlass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: selected ? MetaGymTheme.primary : colors.liquidGlassBorder,
            width: selected ? 1.2 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? colors.primaryText : colors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachDiscoveryCard extends StatelessWidget {
  const _CoachDiscoveryCard({
    required this.coach,
    required this.onTap,
    this.paletteIndex = 0,
  });

  final CoachProfile coach;
  final VoidCallback onTap;
  final int paletteIndex;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final available = coach.availableSlots > 0;
    final metaParts = <String>[
      if (coach.specialties.isNotEmpty) coach.specialties.join(' · '),
      if (coach.experienceYears != null) '${coach.experienceYears} năm KN',
    ];
    final qualRaw = coach.qualifications?.trim() ?? '';
    final qualParts = qualRaw.isNotEmpty
        ? qualRaw
              .split(RegExp(r'\s*[·,]\s*'))
              .where((s) => s.isNotEmpty)
              .toList()
        : const <String>[];

    return MetaGymGlassCard(
      solid: false,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoachingAvatar(
                fullName: coach.fullName,
                avatarUrl: coach.avatarUrl,
                size: 48,
                round: true,
                paletteIndex: paletteIndex,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            coach.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CoachingPill(
                          label: available
                              ? 'Còn ${coach.availableSlots} suất'
                              : 'Hết suất',
                          tone: available
                              ? CoachingPillTone.green
                              : CoachingPillTone.amber,
                        ),
                      ],
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        metaParts.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textWarmMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const MetaGymIcon(
                          MetaGymIcons.socialStarRating,
                          size: MetaGymIconSize.xs,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '${coach.usedSlots}/${coach.memberLimit}',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: ' học viên đang đồng hành',
                                  style: TextStyle(color: colors.textSecondary),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: qualParts.isNotEmpty
                    ? Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: qualParts.first,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (qualParts.length > 1)
                              TextSpan(
                                text: ' · ${qualParts.skip(1).join(' · ')}',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      )
                    : Text(
                        'Huấn luyện 1:1 · 90 phút/buổi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: MetaGymTheme.brandOrange.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  'Xem hồ sơ ›',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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
