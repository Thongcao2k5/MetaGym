import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/catalog/data/catalog_service.dart';
import 'package:meta_gym_app/features/catalog/domain/catalog_models.dart';

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
      final equipment = await widget.service.getEquipmentDetail(
        widget.equipmentId,
      );
      if (mounted) setState(() => _equipment = equipment);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được chi tiết thiết bị.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _equipment;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết thiết bị')),
      body: item == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
                if (item != null) ...[
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (item.category != null) Text('Nhóm: ${item.category}'),
                  if (item.description?.isNotEmpty == true)
                    Text(item.description!),
                  if (item.targetMuscles.isNotEmpty)
                    Text('Nhóm cơ: ${item.targetMuscles.join(', ')}'),
                  const SizedBox(height: 16),
                  Text(
                    'Hướng dẫn sử dụng',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (item.usageSteps.isEmpty) const Text('Chưa có hướng dẫn.'),
                  for (var index = 0; index < item.usageSteps.length; index++)
                    ListTile(
                      leading: Text('${index + 1}.'),
                      title: Text(item.usageSteps[index]),
                    ),
                  if (item.safetyNotes?.isNotEmpty == true) ...[
                    Text(
                      'Lưu ý an toàn',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(item.safetyNotes!),
                  ],
                  if (item.videoUrl?.isNotEmpty == true)
                    SelectableText('Video hướng dẫn: ${item.videoUrl}'),
                ],
              ],
            ),
    );
  }
}
