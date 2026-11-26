import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/equipment_detail_page.dart';
import 'package:provider/provider.dart';

class GymEquipmentPage extends StatefulWidget {
  const GymEquipmentPage({this.service, super.key});

  final CatalogService? service;

  @override
  State<GymEquipmentPage> createState() => _GymEquipmentPageState();
}

class _GymEquipmentPageState extends State<GymEquipmentPage> {
  final _search = TextEditingController();
  CatalogService? _service;
  GymProfile? _gym;
  List<CatalogItem> _equipment = const [];
  String? _category;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CatalogService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gym = await _service!.getGymProfile();
      final equipment = await _service!.getEquipment(
        search: _search.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _gym = gym;
        _equipment = equipment
            .where((item) => item.status == 'ACTIVE')
            .toList();
        if (!_equipment.any((item) => item.category == _category)) {
          _category = null;
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được thông tin phòng gym.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final categories =
        _equipment
            .map((item) => item.category)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    final visible = _equipment
        .where((item) => _category == null || item.category == _category)
        .toList();
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MetaGymCircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
        titleSpacing: 8,
        title: Text(
          'Phòng gym & thiết bị',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          RefreshIndicator(
            onRefresh: _load,
            color: MetaGymTheme.brandOrange,
            backgroundColor: colors.surface,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                MetaGymTheme.pageGutter,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                MetaGymTheme.pageGutter,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                if (_loading && _gym == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.brandOrange,
                      ),
                    ),
                  )
                else if (_error != null)
                  _surface(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: palette.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _load,
                          style: TextButton.styleFrom(
                            foregroundColor: palette.primaryText,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Thử lại',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_gym != null) ...[
                  _gymCard(_gym!),
                  if (_gym!.openingHours.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _surface(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _heading(
                            Icons.schedule_rounded,
                            'Giờ mở cửa',
                            color: palette.reflection,
                          ),
                          const SizedBox(height: 10),
                          for (final entry in _gym!.openingHours.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${entry.key}: ${entry.value}',
                                style: TextStyle(
                                  color: palette.textSecondary,
                                  fontSize: 14,
                                  height: 1.45,
                                  fontFeatures: MetaGymTheme.tabularFigures,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (_gym!.rules?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    _surface(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _heading(
                            Icons.verified_user_outlined,
                            'Nội quy',
                            color: palette.warning,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _gym!.rules!,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Máy tại phòng gym',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.metricPanelBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: palette.metricPanelBorder),
                        ),
                        child: Text(
                          '${visible.length} máy',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFeatures: MetaGymTheme.tabularFigures,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('equipment-search'),
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    cursorColor: MetaGymTheme.brandOrange,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm tên máy',
                      hintStyle: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13.5,
                      ),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: palette.primaryText,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Tìm máy',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: _load,
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          color: palette.textPrimary,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                        borderSide: BorderSide(color: palette.borderSolid),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                        borderSide: BorderSide(color: palette.borderSolid),
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
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _chip('Tất cả', null),
                            for (final category in categories)
                              _chip(category, category),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    _surface(
                      Row(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            color: palette.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Không có máy phù hợp.',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final item in visible) ...[
                      _equipmentRow(item),
                      const SizedBox(height: 10),
                    ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gymCard(GymProfile gym) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(18),
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
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: palette.primaryText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  gym.name,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 19,
                color: palette.primaryText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  gym.address,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          if (gym.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              gym.description!,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
          if (gym.phone?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              'Điện thoại: ${gym.phone}',
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                fontFeatures: MetaGymTheme.tabularFigures,
              ),
            ),
          ],
          if (gym.email?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Email: ${gym.email}',
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heading(
    IconData icon,
    String title, {
    Color? color,
  }) {
    final palette = MetaGymTheme.paletteOf(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? palette.primaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String? value) {
    final palette = MetaGymTheme.paletteOf(context);
    final colors = MetaGymColors.of(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final selected = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = value),
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        selectedColor: isLight ? palette.chipActiveBg : const Color(0xFF493025),
        backgroundColor: colors.surface,
        showCheckmark: false,
        side: BorderSide(
          color: selected ? MetaGymTheme.brandOrange : palette.borderSolid,
        ),
        labelStyle: TextStyle(
          color: selected ? palette.chipActiveText : palette.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _equipmentRow(CatalogItem item) {
    final palette = MetaGymTheme.paletteOf(context);
    return MetaGymGlassCard(
      solid: true,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: MetaGymTap(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
          onTap: () => MetaGymNavigation.pushOnce(
            context,
            MetaGymPageRoute<void>(
              builder: (_) =>
                  EquipmentDetailPage(equipmentId: item.id, service: _service!),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.chipActiveBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MetaGymTheme.primary.withValues(alpha: 0.36),
                    ),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: palette.primaryText,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.category != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.category!,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.videoUrl?.isNotEmpty == true) ...[
                  Icon(
                    Icons.play_circle_outline_rounded,
                    color: palette.reflection,
                    size: 21,
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _surface(Widget child) => MetaGymGlassCard(
    solid: true,
    padding: const EdgeInsets.all(16),
    child: child,
  );
}
