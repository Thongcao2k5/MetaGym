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
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: MetaGymCircleIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Quay lại',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        titleSpacing: 8,
        title: Text(
          item?.name ?? 'Thiết bị',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          if (item == null && _error == null)
            const Center(
              child: CircularProgressIndicator(color: MetaGymTheme.primary),
            )
          else
            ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 88,
                16,
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
                          style: const TextStyle(color: Colors.white),
                        ),
                        TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                if (item != null) ...[
                  if (item.videoUrl?.trim().isNotEmpty == true) ...[
                    ExerciseVideoPlayer(url: item.videoUrl!.trim()),
                    const SizedBox(height: 14),
                  ],
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.category?.isNotEmpty == true)
                          Text(
                            item.category!,
                            style: const TextStyle(
                              color: Color(0xFFFFB923),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (item.targetMuscles.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Nhóm cơ: ${item.targetMuscles.join(' · ')}',
                            style: const TextStyle(color: Color(0xFFE4DAD1)),
                          ),
                        ],
                        if (item.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 10),
                          Text(
                            item.description!,
                            style: const TextStyle(
                              color: Color(0xFFE4DAD1),
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
                          const _SectionTitle(
                            Icons.format_list_numbered_rounded,
                            'Cách dùng máy',
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
                                    style: const TextStyle(
                                      color: Color(0xFFFFB923),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.usageSteps[i],
                                      style: const TextStyle(
                                        color: Color(0xFFE4DAD1),
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
                          const _SectionTitle(
                            Icons.shield_outlined,
                            'Lưu ý an toàn',
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.safetyNotes!,
                            style: const TextStyle(
                              color: Color(0xFFE4DAD1),
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
  Widget build(BuildContext context) => MetaGymGlassCard(
    padding: EdgeInsets.zero,
    child: ColoredBox(
      color: const Color(0xA0211E1C),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.icon, this.title);
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: const Color(0xFFFFB923)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
