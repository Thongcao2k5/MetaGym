import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';
import 'package:meta_gym_app/features/catalog/presentation/exercise_video_player.dart';

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
    final item = _equipment;
    return Scaffold(
      backgroundColor: MetaGymColors.of(context).canvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MetaGymColors.of(context).textPrimary,
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
          item?.name ?? 'Thiết bị',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: MetaGymColors.of(context).textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          if (item == null && _error == null)
            Center(
              child: CircularProgressIndicator(color: MetaGymTheme.brandOrange),
            )
          else
            ListView(
              padding: EdgeInsets.fromLTRB(
                MetaGymTheme.pageGutter,
                MediaQuery.paddingOf(context).top + 88,
                MetaGymTheme.pageGutter,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                if (_error != null)
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _error!,
                          style: TextStyle(
                            color: MetaGymColors.of(context).textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _load,
                          style: TextButton.styleFrom(
                            foregroundColor: MetaGymColors.of(context)
                                .primaryText,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: Icon(Icons.refresh_rounded, size: 18),
                          label: Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                if (item != null) ...[
                  if (item.videoUrl?.trim().isNotEmpty == true) ...[
                    ExerciseVideoPlayer(url: item.videoUrl!.trim()),
                    const SizedBox(height: 14),
                  ],
                  MetaGymHeroGlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.category?.isNotEmpty == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x24FF5E36),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x4DFF5E36),
                              ),
                            ),
                            child: Text(
                              item.category!,
                              style: TextStyle(
                                color: MetaGymColors.of(context).primaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (item.targetMuscles.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Nhóm cơ: ${item.targetMuscles.join(' · ')}',
                            style: TextStyle(
                              color: MetaGymColors.of(context).textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (item.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 10),
                          Text(
                            item.description!,
                            style: TextStyle(
                              color: MetaGymColors.of(context).textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item.usageSteps.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            Icons.format_list_numbered_rounded,
                            'Cách dùng máy',
                            color: MetaGymColors.of(context).primaryText,
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < item.usageSteps.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${i + 1}.',
                                    style: TextStyle(
                                      color: MetaGymColors.of(context)
                                          .primaryText,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: MetaGymTheme.tabularFigures,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.usageSteps[i],
                                      style: TextStyle(
                                        color: MetaGymColors.of(context)
                                            .textPrimary,
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (item.safetyNotes?.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    _InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            Icons.shield_outlined,
                            'Lưu ý an toàn',
                            color: MetaGymColors.of(context).warning,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.safetyNotes!,
                            style: TextStyle(
                              color: MetaGymColors.of(context).textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      MetaGymGlassCard(padding: const EdgeInsets.all(16), child: child);
}

class _SectionTitle extends StatelessWidget {
  _SectionTitle(this.icon, this.title, {this.color = MetaGymTheme.brandOrange});
  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            color: MetaGymColors.of(context).textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
