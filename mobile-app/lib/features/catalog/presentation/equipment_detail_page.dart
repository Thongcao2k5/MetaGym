import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_video_player.dart';

/// Maps a [CatalogItem] category/name to the closest equipment duotone SVG asset.
String equipmentIconAssetFor(CatalogItem item) {
  final normalized = '${item.category ?? ''} ${item.name}'.toLowerCase();
  if (normalized.contains('cáp') || normalized.contains('cable')) {
    return MetaGymIcons.equipCable;
  }
  if (normalized.contains('chạy') || normalized.contains('treadmill')) {
    return MetaGymIcons.equipTreadmill;
  }
  if (normalized.contains('cardio') ||
      normalized.contains('đạp') ||
      normalized.contains('xe') ||
      normalized.contains('bike')) {
    return MetaGymIcons.equipCardio;
  }
  if (normalized.contains('tạ đơn') || normalized.contains('dumbbell')) {
    return MetaGymIcons.equipDumbbell;
  }
  if (normalized.contains('tạ đòn') || normalized.contains('barbell')) {
    return MetaGymIcons.equipBarbell;
  }
  if (normalized.contains('ghế') || normalized.contains('bench')) {
    return MetaGymIcons.equipBench;
  }
  if (normalized.contains('kettlebell')) {
    return MetaGymIcons.equipKettlebell;
  }
  if (normalized.contains('smith') ||
      normalized.contains('máy') ||
      normalized.contains('machine') ||
      normalized.contains('press') ||
      normalized.contains('pulldown')) {
    return MetaGymIcons.equipMachine;
  }
  if (normalized.contains('free weight')) {
    return MetaGymIcons.equipFreeWeight;
  }
  return MetaGymIcons.equipDumbbell;
}

class EquipmentDetailPage extends StatefulWidget {
  const EquipmentDetailPage({
    required this.equipmentId,
    required this.service,
    super.key,
  });

  final String equipmentId;
  final CatalogService service;

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  CatalogItem? _equipment;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _equipment = null;
      _error = null;
    });
    try {
      final item = await widget.service.getEquipmentDetail(widget.equipmentId);
      if (mounted) setState(() => _equipment = item);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được thông tin máy.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final item = _equipment;
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
                _buildStudioHeader(context, palette, item),
                Expanded(
                  child: item == null && _error == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            MetaGymTheme.pageGutter,
                            8,
                            MetaGymTheme.pageGutter,
                            MediaQuery.paddingOf(context).bottom + 24,
                          ),
                          children: [
                            if (_error != null) _buildErrorCard(palette),
                            if (item != null) ...[
                              if (item.videoUrl?.trim().isNotEmpty == true) ...[
                                ExerciseVideoPlayer(
                                  url: item.videoUrl!.trim(),
                                ),
                                const SizedBox(height: 14),
                              ],
                              _buildHeroCard(palette, item),
                              if (item.usageSteps.isNotEmpty ||
                                  item.instructions?.trim().isNotEmpty ==
                                      true) ...[
                                const SizedBox(height: 14),
                                _buildUsageStepsCard(palette, item),
                              ],
                              if (item.safetyNotes?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 14),
                                _buildSafetyCard(palette, item),
                              ],
                            ],
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

  Widget _buildStudioHeader(
    BuildContext context,
    MetaGymPalette palette,
    CatalogItem? item,
  ) {
    return Padding(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HƯỚNG DẪN THIẾT BỊ',
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
                  item?.name ?? 'Chi tiết thiết bị',
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
        ],
      ),
    );
  }

  Widget _buildErrorCard(MetaGymPalette palette) {
    return _InfoCard(
      child: Column(
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
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(MetaGymPalette palette, CatalogItem item) {
    final isMaintenance = item.status.toUpperCase() == 'MAINTENANCE';
    final statusColor = isMaintenance ? palette.warning : palette.success;
    final hasCategory = item.category?.trim().isNotEmpty == true;
    final hasDescription = item.description?.trim().isNotEmpty == true;

    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: palette.chipActiveBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MetaGymTheme.primary.withValues(alpha: 0.34),
                  ),
                ),
                alignment: Alignment.center,
                child: MetaGymSvgIcon(
                  equipmentIconAssetFor(item),
                  size: 28,
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
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (hasCategory) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.category!.trim(),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Text(
                        isMaintenance
                            ? '● Đang bảo trì'
                            : '● Sẵn sàng sử dụng',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.targetMuscles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < item.targetMuscles.length; i++)
                  _MuscleTagPill(
                    label: item.targetMuscles[i],
                    highlighted: i == 0,
                  ),
              ],
            ),
          ],
          if (hasDescription) ...[
            const SizedBox(height: 12),
            Text(
              item.description!.trim(),
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageStepsCard(MetaGymPalette palette, CatalogItem item) {
    final steps = item.usageSteps;
    final instructions = item.instructions?.trim();

    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetaGymSvgIcon(
                MetaGymIcons.exerciseStepGuide,
                size: 20,
                fallbackIcon: Icons.format_list_numbered_rounded,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hướng dẫn sử dụng từng bước',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (steps.isNotEmpty)
            for (var i = 0; i < steps.length; i++)
              Container(
                margin: EdgeInsets.only(bottom: i < steps.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: palette.metricPanelBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.metricPanelBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.chipActiveBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: MetaGymTheme.brandOrange.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                      child: Text(
                        'Bước ${i + 1}',
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13.5,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )
          else if (instructions != null && instructions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: palette.metricPanelBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.metricPanelBorder),
              ),
              child: Text(
                instructions,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard(MetaGymPalette palette, CatalogItem item) {
    return MetaGymGlassCard(
      solid: false,
      borderColor: palette.warning.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MetaGymSvgIcon(
                MetaGymIcons.exerciseSafetyShield,
                size: 20,
                fallbackIcon: Icons.shield_outlined,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Lưu ý an toàn',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: palette.warning.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              item.safetyNotes!,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleTagPill extends StatelessWidget {
  const _MuscleTagPill({required this.label, required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? palette.chipActiveBg : palette.metricPanelBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
              : palette.metricPanelBorder,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? palette.primaryText : palette.textSecondary,
          fontSize: 12,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => MetaGymGlassCard(
    solid: false,
    padding: const EdgeInsets.all(16),
    child: child,
  );
}
