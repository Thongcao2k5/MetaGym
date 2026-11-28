import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/network/offline_sync_manager.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
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
  SyncRevisionBinding? _syncBinding;
  GymProfile? _gym;
  List<CatalogItem> _equipment = const [];
  String? _category;
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBinding ??= bindApiCacheSync(context, () {
      if (mounted) _load(silent: true);
    });
    if (_service != null) return;
    _service = widget.service ?? context.read<CatalogService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _syncBinding?.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final query = _search.text.trim();
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final gym = await _service!.getGymProfile();
      List<CatalogItem> equipment;
      try {
        equipment = await _service!.getEquipment(search: query);
      } on ApiException catch (error) {
        if (error.kind == ApiExceptionKind.network && query.isNotEmpty) {
          final allCached = await _service!.getEquipment();
          final lower = query.toLowerCase();
          equipment = allCached.where((item) {
            return item.name.toLowerCase().contains(lower) ||
                (item.category?.toLowerCase().contains(lower) ?? false);
          }).toList();
        } else {
          rethrow;
        }
      }
      if (!mounted) return;
      setState(() {
        _gym = gym;
        _equipment = equipment.where((item) {
          final status = item.status.toUpperCase();
          return status == 'ACTIVE' || status == 'MAINTENANCE';
        }).toList();
        if (!_equipment.any((item) => item.category == _category)) {
          _category = null;
        }
        _error = null;
      });
    } on ApiException catch (error) {
      if (!silent && mounted) setState(() => _error = error.message);
    } catch (_) {
      if (!silent && mounted) {
        setState(() => _error = 'Không tải được thông tin phòng gym.');
      }
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildStudioHeader(context, palette),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: colors.surface,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        MetaGymTheme.pageGutter,
                        8,
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
                                    MetaGymSvgIcon(
                                      MetaGymIcons.stateError,
                                      size: 20,
                                      fallbackIcon: Icons.error_outline_rounded,
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
                                  icon: const MetaGymSvgIcon(
                                    MetaGymIcons.commonRefresh,
                                    size: 18,
                                    fallbackIcon: Icons.refresh_rounded,
                                  ),
                                  label: const Text(
                                    'Thử lại',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_gym != null) ...[
                          _buildSearchBar(context, palette, colors),
                          if (categories.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 46),
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
                          const SizedBox(height: 12),
                          _gymCard(_gym!),
                          if (_gym!.rules?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            _buildRulesCard(palette, _gym!.rules!.trim()),
                          ],
                          const SizedBox(height: 18),
                          _buildEquipmentSectionHeader(
                            palette,
                            visible.length,
                          ),
                          const SizedBox(height: 10),
                          if (visible.isEmpty)
                            _surface(
                              Row(
                                children: [
                                  MetaGymSvgIcon(
                                    MetaGymIcons.stateEmptySearch,
                                    size: 20,
                                    fallbackIcon: Icons.search_off_rounded,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioHeader(BuildContext context, MetaGymPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          MetaGymCircleIconButton(
            icon: Icons.arrow_back_rounded,
            svgAsset: MetaGymIcons.commonBack,
            tooltip: 'Quay lại',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KHÁM PHÁ PHÒNG TẬP',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Phòng gym & Thiết bị',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          MetaGymCircleIconButton(
            icon: Icons.refresh_rounded,
            svgAsset: MetaGymIcons.commonRefresh,
            tooltip: 'Tải lại',
            onTap: _loading ? null : _load,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    MetaGymPalette palette,
    MetaGymColors colors,
  ) {
    final isLight = MetaGymTheme.isLightPalette(context);
    final fillColor = isLight
        ? colors.surface
        : MetaGymWarmGlassTokens.metricPanelFill;
    final borderColor = isLight
        ? palette.borderSolid
        : MetaGymWarmGlassTokens.metricPanelBorder;

    return TextField(
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
        hintText: 'Tìm tên máy hoặc nhóm cơ...',
        hintStyle: TextStyle(color: palette.textSecondary, fontSize: 13.5),
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: MetaGymSvgIcon(
            MetaGymIcons.commonSearch,
            size: 19,
            fallbackIcon: Icons.search_rounded,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIcon: IconButton(
          tooltip: 'Tìm máy',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: _load,
          icon: MetaGymSvgIcon(
            MetaGymIcons.commonChevronRight,
            size: 20,
            fallbackIcon: Icons.arrow_forward_rounded,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: MetaGymTheme.brandOrange,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _gymCard(GymProfile gym) {
    final palette = MetaGymTheme.paletteOf(context);
    final hasDescription = gym.description?.trim().isNotEmpty == true;
    final hasPhone = gym.phone?.trim().isNotEmpty == true;
    final hasEmail = gym.email?.trim().isNotEmpty == true;

    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.chipActiveBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MetaGymTheme.primary.withValues(alpha: 0.36),
                  ),
                ),
                alignment: Alignment.center,
                child: MetaGymSvgIcon(
                  MetaGymIcons.equipDumbbell,
                  size: 22,
                  fallbackIcon: Icons.fitness_center_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gym.name,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: MetaGymSvgIcon(
                            MetaGymIcons.locationPin,
                            size: 16,
                            fallbackIcon: Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            gym.address,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 13,
                              height: 1.4,
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
          if (hasDescription) ...[
            const SizedBox(height: 10),
            Text(
              gym.description!.trim(),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          if (hasPhone || hasEmail) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (hasPhone) _contactPill(palette, 'ĐT: ${gym.phone!.trim()}'),
                if (hasEmail)
                  _contactPill(palette, 'Email: ${gym.email!.trim()}'),
              ],
            ),
          ],
          if (gym.openingHours.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: palette.metricPanelBorder),
            const SizedBox(height: 12),
            Row(
              children: [
                MetaGymSvgIcon(
                  MetaGymIcons.timeClock,
                  size: 18,
                  fallbackIcon: Icons.schedule_rounded,
                ),
                const SizedBox(width: 7),
                Text(
                  'Giờ mở cửa',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in gym.openingHours.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _contactPill(MetaGymPalette palette, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.metricPanelBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.metricPanelBorder),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFeatures: MetaGymTheme.tabularFigures,
        ),
      ),
    );
  }

  Widget _buildRulesCard(MetaGymPalette palette, String rules) {
    return MetaGymGlassCard(
      solid: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: palette.warning.withValues(alpha: 0.34),
              ),
            ),
            alignment: Alignment.center,
            child: MetaGymSvgIcon(
              MetaGymIcons.exerciseSafetyShield,
              size: 20,
              fallbackIcon: Icons.verified_user_outlined,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nội quy phòng tập',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rules,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentSectionHeader(MetaGymPalette palette, int count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Danh mục thiết bị',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: palette.metricPanelBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.metricPanelBorder),
          ),
          child: Text(
            '$count máy',
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: MetaGymTheme.tabularFigures,
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
        selectedColor: MetaGymTheme.brandOrange,
        backgroundColor: isLight
            ? colors.surface
            : MetaGymWarmGlassTokens.metricPanelFill,
        showCheckmark: false,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? MetaGymTheme.brandOrange
                : (isLight
                      ? palette.borderSolid
                      : MetaGymWarmGlassTokens.metricPanelBorder),
          ),
        ),
        side: BorderSide(
          color: selected
              ? MetaGymTheme.brandOrange
              : (isLight
                    ? palette.borderSolid
                    : MetaGymWarmGlassTokens.metricPanelBorder),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : palette.textSecondary,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _equipmentRow(CatalogItem item) {
    final palette = MetaGymTheme.paletteOf(context);
    final isMaintenance = item.status.toUpperCase() == 'MAINTENANCE';
    final statusColor = isMaintenance ? palette.warning : palette.success;
    final subtitleParts = <String>[
      if (item.category?.trim().isNotEmpty == true) item.category!.trim(),
      if (item.targetMuscles.isNotEmpty) item.targetMuscles.take(3).join(', '),
    ];
    final subtitle = subtitleParts.join(' · ');

    return MetaGymGlassCard(
      solid: false,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: MetaGymTap(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
          onTap: () => MetaGymNavigation.pushOnce(
            context,
            MetaGymPageRoute<void>(
              builder: (_) => EquipmentDetailPage(
                equipmentId: item.id,
                service: _service!,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.chipActiveBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: MetaGymTheme.primary.withValues(alpha: 0.36),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: MetaGymSvgIcon(
                    equipmentIconAssetFor(item),
                    size: 30,
                    fallbackIcon: Icons.fitness_center_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.36),
                    ),
                  ),
                  child: Text(
                    isMaintenance ? 'Đang bảo trì' : 'Sẵn sàng',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (item.videoUrl?.trim().isNotEmpty == true) ...[
                  const SizedBox(width: 6),
                  MetaGymSvgIcon(
                    MetaGymIcons.exerciseVideoPlay,
                    size: 19,
                    fallbackIcon: Icons.play_circle_outline_rounded,
                  ),
                ],
                const SizedBox(width: 4),
                MetaGymSvgIcon(
                  MetaGymIcons.commonChevronRight,
                  size: 18,
                  fallbackIcon: Icons.chevron_right_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _surface(Widget child) => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(16),
    child: child,
  );
}
