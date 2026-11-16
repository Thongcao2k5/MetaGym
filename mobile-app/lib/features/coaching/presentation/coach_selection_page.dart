import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_detail_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:provider/provider.dart';

class CoachSelectionPage extends StatefulWidget {
  const CoachSelectionPage({this.service, super.key});

  final CoachSelectionService? service;

  @override
  State<CoachSelectionPage> createState() => _CoachSelectionPageState();
}

class _CoachSelectionPageState extends State<CoachSelectionPage> {
  final _searchController = TextEditingController();
  CoachSelectionService? _service;
  List<CoachProfile> _coaches = const [];
  String _selectedFilter = 'ALL';
  String _searchTerm = '';
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachSelectionService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final coaches = await _service!.getCoaches();
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
      final haystack = '${coach.fullName} ${coach.specialties.join(' ')}'
          .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _handleBottomNavTap(BuildContext context, int index) {
    final router = GoRouter.maybeOf(context);
    switch (index) {
      case 0:
        if (router != null) {
          router.go('/member');
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      case 1:
        break;
      case 2:
        router?.push('/member/features/ai');
      case 3:
        router?.push('/member/features/messages');
      case 4:
        router?.push('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final specialties = _specialtyFilters;
    final filtered = _filteredCoaches;
    final bottomPadding = MetaGymBottomNav.contentBottomPadding(context);

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          'Khám phá Coach',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBar: MetaGymBottomNav(
        currentIndex: 1,
        warmGlass: true,
        onTap: (index) => _handleBottomNavTap(context, index),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: _loading && _coaches.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: const Color(0xFF181B22),
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                      children: [
                        const Text(
                          'Xem chuyên môn và lịch làm việc trước khi chọn gói phù hợp.',
                          style: TextStyle(
                            color: Color(0xFFC5C8CF),
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_error != null) ...[
                          CoachingErrorBanner(message: _error!),
                          TextButton(
                            onPressed: _load,
                            style: TextButton.styleFrom(
                              foregroundColor: MetaGymTheme.brandOrange,
                            ),
                            child: const Text('Thử lại'),
                          ),
                        ] else if (_coaches.isEmpty)
                          const MetaGymGlassCard(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'Chưa có Coach để lựa chọn.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        else ...[
                          TextField(
                            key: const Key('coach-search-input'),
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _searchTerm = value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Tìm tên hoặc chuyên môn Coach',
                              hintStyle: const TextStyle(
                                color: MetaGymTheme.textSecondary,
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: MetaGymTheme.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: _searchTerm.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Xóa tìm kiếm',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchTerm = '');
                                      },
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        color: MetaGymTheme.textSecondary,
                                        size: 18,
                                      ),
                                    )
                                  : null,
                              filled: true,
                              fillColor: MetaGymTheme.cardSurface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  MetaGymTheme.radiusInput,
                                ),
                                borderSide: const BorderSide(
                                  color: MetaGymTheme.darkBorderStrong,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  MetaGymTheme.radiusInput,
                                ),
                                borderSide: const BorderSide(
                                  color: MetaGymTheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChipButton(
                                  label: 'Tất cả',
                                  selected: _selectedFilter == 'ALL',
                                  onTap: () =>
                                      setState(() => _selectedFilter = 'ALL'),
                                ),
                                const SizedBox(width: 8),
                                _FilterChipButton(
                                  label: 'Còn suất',
                                  selected: _selectedFilter == 'AVAILABLE',
                                  onTap: () => setState(
                                    () => _selectedFilter = 'AVAILABLE',
                                  ),
                                ),
                                for (final spec in specialties) ...[
                                  const SizedBox(width: 8),
                                  _FilterChipButton(
                                    label: spec,
                                    selected: _selectedFilter == spec,
                                    onTap: () =>
                                        setState(() => _selectedFilter = spec),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (filtered.isEmpty)
                            CoachingGraphiteCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const Text(
                                    'Không tìm thấy Coach',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Thử tên hoặc chuyên môn khác.',
                                    style: TextStyle(
                                      color: MetaGymTheme.textSecondary,
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
                                    child: const Text('Xóa bộ lọc'),
                                  ),
                                ],
                              ),
                            )
                          else
                            for (final coach in filtered)
                              _CoachDiscoveryCard(
                                coach: coach,
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => CoachDetailPage(
                                      coachId: coach.id,
                                      service: _service!,
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
    return Material(
      color: selected
          ? MetaGymTheme.primary.withValues(alpha: 0.2)
          : MetaGymTheme.elevatedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected
              ? MetaGymTheme.primary
              : MetaGymTheme.darkBorderStrong,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? MetaGymTheme.textPrimary
                  : const Color(0xFFCDD0D5),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachDiscoveryCard extends StatelessWidget {
  const _CoachDiscoveryCard({required this.coach, required this.onTap});

  final CoachProfile coach;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = coach.availableSlots > 0;
    return CoachingGraphiteCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachingAvatar(
                fullName: coach.fullName,
                avatarUrl: coach.avatarUrl,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.fullName,
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (coach.specialties.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        coach.specialties.join(' · '),
                        style: const TextStyle(
                          color: MetaGymTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MetaGymTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Xem hồ sơ, lịch làm việc và gói huấn luyện.',
            style: TextStyle(
              color: MetaGymTheme.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CoachingPill(
                label: available
                    ? 'Còn ${coach.availableSlots} suất'
                    : 'Hết suất',
                tone: available
                    ? CoachingPillTone.green
                    : CoachingPillTone.amber,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: MetaGymTheme.elevatedSurface,
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                  border: Border.all(color: MetaGymTheme.darkBorderStrong),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Xem hồ sơ',
                      style: TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: MetaGymTheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
