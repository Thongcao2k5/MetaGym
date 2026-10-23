import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
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
  final _searchController = TextEditingController();
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
    _searchController.dispose();
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
        search: _searchController.text.trim(),
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
      if (mounted) setState(() => _error = 'Không tải được thông tin gym.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gym = _gym;
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
      appBar: AppBar(title: const Text('Phòng gym và thiết bị')),
      body: _loading && gym == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
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
                  if (gym != null) ...[
                    Text(
                      gym.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(gym.address),
                    if (gym.description?.isNotEmpty == true)
                      Text(gym.description!),
                    if (gym.phone?.isNotEmpty == true)
                      Text('Điện thoại: ${gym.phone}'),
                    if (gym.email?.isNotEmpty == true)
                      Text('Email: ${gym.email}'),
                    const SizedBox(height: 16),
                    Text(
                      'Giờ mở cửa',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (gym.openingHours.isEmpty)
                      const Text('Chưa cập nhật giờ mở cửa.'),
                    for (final entry in gym.openingHours.entries)
                      Text('${entry.key}: ${entry.value}'),
                    const SizedBox(height: 16),
                    Text(
                      'Nội quy',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      gym.rules?.isNotEmpty == true
                          ? gym.rules!
                          : 'Chưa cập nhật nội quy.',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Thiết bị',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextField(
                      key: const Key('equipment-search'),
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        labelText: 'Tìm thiết bị',
                        suffixIcon: IconButton(
                          tooltip: 'Tìm kiếm',
                          onPressed: _load,
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    if (categories.isNotEmpty)
                      DropdownButton<String>(
                        value: _category,
                        hint: const Text('Tất cả nhóm thiết bị'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          for (final category in categories)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                        ],
                        onChanged: (value) => setState(() => _category = value),
                      ),
                    if (visible.isEmpty)
                      const ListTile(title: Text('Không có thiết bị phù hợp.')),
                    for (final item in visible)
                      ListTile(
                        title: Text(item.name),
                        subtitle: Text(item.category ?? item.description ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EquipmentDetailPage(
                              equipmentId: item.id,
                              service: _service!,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
