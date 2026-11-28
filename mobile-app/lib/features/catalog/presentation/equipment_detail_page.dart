import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_video_player.dart';

/// Maps the 7-muscle-group catalog entries (16 equipment SVGs & 21 videos)
/// to their exact custom duotone SVG asset, preferring [CatalogItem.videoUrl]
/// when present and falling back to distinctive Vietnamese/English names.
String? catalog7GroupIconFor(CatalogItem item) {
  final video = (item.videoUrl ?? '').trim().toLowerCase();
  if (video.endsWith('lower_back_01_hyperextension_480p.mp4')) {
    return MetaGymIcons.equip7HyperextensionCurved;
  }
  if (video.endsWith('lower_back_02_crossed_arms_480p.mp4') ||
      video.endsWith('lower_back_03_weighted_480p.mp4')) {
    return MetaGymIcons.equip7HyperextensionAngular;
  }
  if (video.endsWith('lats_01_normal_grip_480p.mp4') ||
      video.endsWith('lats_02_wide_grip_480p.mp4') ||
      video.endsWith('lats_03_close_grip_480p.mp4')) {
    return MetaGymIcons.equip7LatPulldown;
  }
  if (video.endsWith('glutes_01_smith_hip_thrust_480p.mp4')) {
    return MetaGymIcons.equip7SmithHipThrust;
  }
  if (video.endsWith('glutes_02_cable_kickback_480p.mp4')) {
    return MetaGymIcons.equip7CableAnkleStation;
  }
  if (video.endsWith('glutes_03_multi_hip_abduction_480p.mp4')) {
    return MetaGymIcons.equip7MultiHip;
  }
  if (video.endsWith('chest_01_pec_deck_480p.mp4')) {
    return MetaGymIcons.equip7PecDeck;
  }
  if (video.endsWith('chest_02_cable_fly_480p.mp4')) {
    return MetaGymIcons.equip7DualCable;
  }
  if (video.endsWith('chest_03_chest_press_480p.mp4')) {
    return MetaGymIcons.equip7ChestPress;
  }
  if (video.endsWith('triceps_01_seated_dip_480p.mp4')) {
    return MetaGymIcons.equip7SeatedDip;
  }
  if (video.endsWith('triceps_02_extension_machine_480p.mp4')) {
    return MetaGymIcons.equip7SeatedTricepsExtension;
  }
  if (video.endsWith('triceps_03_rope_pushdown_480p.mp4')) {
    return MetaGymIcons.equip7CableRopeStation;
  }
  if (video.endsWith('biceps_01_low_cable_curl_480p.mp4') ||
      video.endsWith('biceps_03_wide_grip_cable_curl_480p.mp4')) {
    return MetaGymIcons.equip7CableLowBar;
  }
  if (video.endsWith('biceps_02_cable_preacher_480p.mp4')) {
    return MetaGymIcons.equip7CablePreacher;
  }
  if (video.endsWith('quads_01_bilateral_extension_480p.mp4') ||
      video.endsWith('quads_02_single_leg_extension_480p.mp4')) {
    return MetaGymIcons.equip7LegExtension;
  }
  if (video.endsWith('quads_03_smith_squat_480p.mp4')) {
    return MetaGymIcons.equip7SmithSquat;
  }

  final nameOnly = item.name.trim().toLowerCase();
  final normalized = '$nameOnly ${(item.category ?? '').trim().toLowerCase()}';
  if (normalized.contains('khung cong') ||
      normalized.contains('duỗi lưng trên ghế 45')) {
    return MetaGymIcons.equip7HyperextensionCurved;
  }
  if (normalized.contains('khung tam giác') ||
      normalized.contains('ghế duỗi lưng 45') ||
      normalized.contains('tay trước ngực') ||
      normalized.contains('duỗi lưng có tạ')) {
    return MetaGymIcons.equip7HyperextensionAngular;
  }
  if (nameOnly == 'máy kéo xô' || normalized.contains('kéo xô tay')) {
    return MetaGymIcons.equip7LatPulldown;
  }
  if (normalized.contains('nâng hông bằng máy smith') ||
      normalized.contains('smith và ghế nâng hông') ||
      normalized.contains('smith hip thrust')) {
    return MetaGymIcons.equip7SmithHipThrust;
  }
  if (normalized.contains('dây cổ chân') ||
      normalized.contains('đá chân sau bằng cáp') ||
      normalized.contains('cable kickback')) {
    return MetaGymIcons.equip7CableAnkleStation;
  }
  if (normalized.contains('multi hip') || normalized.contains('dạng hông')) {
    return MetaGymIcons.equip7MultiHip;
  }
  if (normalized.contains('ép ngực trên máy') ||
      normalized.contains('máy ép ngực pec deck')) {
    return MetaGymIcons.equip7PecDeck;
  }
  if (normalized.contains('máy cáp đôi') ||
      normalized.contains('ép ngực bằng cáp') ||
      normalized.contains('cable fly')) {
    return MetaGymIcons.equip7DualCable;
  }
  if (normalized.contains('máy đẩy ngực') ||
      normalized.contains('đẩy ngực trên máy') ||
      normalized.contains('chest press')) {
    return MetaGymIcons.equip7ChestPress;
  }
  if (normalized.contains('máy dip ngồi') ||
      normalized.contains('dip trên máy ngồi') ||
      normalized.contains('seated dip')) {
    return MetaGymIcons.equip7SeatedDip;
  }
  if (normalized.contains('máy duỗi tay sau') ||
      normalized.contains('duỗi tay sau trên máy') ||
      normalized.contains('triceps extension')) {
    return MetaGymIcons.equip7SeatedTricepsExtension;
  }
  if (normalized.contains('dây thừng') ||
      normalized.contains('rope pushdown')) {
    return MetaGymIcons.equip7CableRopeStation;
  }
  if (normalized.contains('cáp thấp') ||
      normalized.contains('thanh thẳng') ||
      normalized.contains('low cable curl')) {
    return MetaGymIcons.equip7CableLowBar;
  }
  if (normalized.contains('preacher') ||
      normalized.contains('trên ghế với cáp')) {
    return MetaGymIcons.equip7CablePreacher;
  }
  if (normalized.contains('duỗi đùi trước') ||
      normalized.contains('leg extension')) {
    return MetaGymIcons.equip7LegExtension;
  }
  if (nameOnly == 'máy smith' ||
      normalized.contains('squat bằng máy smith') ||
      normalized.contains('smith squat')) {
    return MetaGymIcons.equip7SmithSquat;
  }
  return null;
}

/// Maps a [CatalogItem] category/name to the closest equipment duotone SVG asset.
String equipmentIconAssetFor(CatalogItem item) {
  final normalized = '${item.name} ${item.category ?? ''}'.toLowerCase();

  // Explicit Realleader M3 model codes always map to their exact M3 assets.
  if (normalized.contains('m3-1016') || normalized.contains('m3_1016')) {
    return MetaGymIcons.equipM3BackExtension;
  }
  if (normalized.contains('m3-1017') || normalized.contains('m3_1017')) {
    return MetaGymIcons.equipM3PecFlyRearDelt;
  }
  if (normalized.contains('m3-1018') || normalized.contains('m3_1018')) {
    return MetaGymIcons.equipM3SeatedLegCurl;
  }
  if (normalized.contains('m3-1019') || normalized.contains('m3_1019')) {
    return MetaGymIcons.equipM3StandingCalfRaise;
  }
  if (normalized.contains('m3-1020') || normalized.contains('m3_1020')) {
    return MetaGymIcons.equipM3ChinDipAssist;
  }
  if (normalized.contains('m3-1021') || normalized.contains('m3_1021')) {
    return MetaGymIcons.equipM3RotaryTorso;
  }
  if (normalized.contains('m3-1023') || normalized.contains('m3_1023')) {
    return MetaGymIcons.equipM3GluteSeated;
  }
  if (normalized.contains('m3-1022') || normalized.contains('m3_1022')) {
    return MetaGymIcons.equipM3GluteStanding;
  }

  final mapped7 = catalog7GroupIconFor(item);
  if (mapped7 != null) return mapped7;

  // Video-matched equipment items (non-M3).
  if (normalized.contains('reverse machine fly') ||
      normalized.contains('reverse fly') ||
      normalized.contains('mở vai sau')) {
    return MetaGymIcons.equipVideoReverseMachineFly;
  }
  if (normalized.contains('pec deck') ||
      (normalized.contains('ép ngực') &&
          !normalized.contains('m3-1017') &&
          !normalized.contains('m3_1017') &&
          !normalized.contains('vai sau'))) {
    return MetaGymIcons.equipVideoPecDeckFly;
  }
  if ((normalized.contains('seated leg curl') ||
          normalized.contains('cuốn đùi sau')) &&
      !normalized.contains('m3-1018') &&
      !normalized.contains('m3_1018')) {
    return MetaGymIcons.equipVideoSeatedLegCurl;
  }
  if ((normalized.contains('assisted pull') ||
          normalized.contains('kéo xà trợ lực')) &&
      !normalized.contains('m3-1020') &&
      !normalized.contains('m3_1020')) {
    return MetaGymIcons.equipVideoAssistedPullUp;
  }

  // Remaining Realleader M3 name fallbacks.
  if (normalized.contains('back extension') ||
      normalized.contains('duỗi lưng')) {
    return MetaGymIcons.equipM3BackExtension;
  }
  if (normalized.contains('pec fly') ||
      normalized.contains('rear delt') ||
      normalized.contains('ép ngực')) {
    return MetaGymIcons.equipM3PecFlyRearDelt;
  }
  if (normalized.contains('leg curl') || normalized.contains('cuốn đùi')) {
    return MetaGymIcons.equipM3SeatedLegCurl;
  }
  if (normalized.contains('calf raise') ||
      normalized.contains('nhón bắp chân')) {
    return MetaGymIcons.equipM3StandingCalfRaise;
  }
  if (normalized.contains('chin dip') ||
      normalized.contains('chin/dip') ||
      normalized.contains('dip assist') ||
      normalized.contains('xà đơn') ||
      normalized.contains('xà kép')) {
    return MetaGymIcons.equipM3ChinDipAssist;
  }
  if (normalized.contains('rotary torso') ||
      normalized.contains('torso rotation') ||
      normalized.contains('xoay eo')) {
    return MetaGymIcons.equipM3RotaryTorso;
  }
  if (normalized.contains('glute seated') ||
      normalized.contains('glute_seated')) {
    return MetaGymIcons.equipM3GluteSeated;
  }
  if (normalized.contains('glute standing') ||
      normalized.contains('glute_standing') ||
      normalized.contains('tập mông') ||
      normalized.contains('glute')) {
    return MetaGymIcons.equipM3GluteStanding;
  }

  // Generic equipment category fallbacks.
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
                                  loop: true,
                                  autoPlay: true,
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
                width: 60,
                height: 60,
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
                  size: 36,
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
