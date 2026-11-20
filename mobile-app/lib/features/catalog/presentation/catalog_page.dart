import 'package:flutter/material.dart';
import 'package:meta_gym_app/features/catalog/presentation/catalog_controller.dart';
import 'package:provider/provider.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CatalogController>().load(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    return RefreshIndicator(
      onRefresh: catalog.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: catalog.search,
            decoration: InputDecoration(
              labelText: 'Tìm thiết bị hoặc bài tập',
              suffixIcon: IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: () => catalog.search(_searchController.text),
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (catalog.state == CatalogViewState.loading)
            const Center(child: CircularProgressIndicator())
          else if (catalog.state == CatalogViewState.error) ...[
            Text(catalog.errorMessage ?? 'Không tải được nội dung.'),
            FilledButton(onPressed: catalog.load, child: const Text('Thử lại')),
          ] else if (catalog.state == CatalogViewState.empty)
            const Center(child: Text('Không có nội dung phù hợp.'))
          else ...[
            Text('Thiết bị', style: Theme.of(context).textTheme.titleLarge),
            ...catalog.equipment.map(
              (item) => ListTile(
                title: Text(item.name),
                subtitle: Text(item.category ?? item.description ?? ''),
              ),
            ),
            Text('Bài tập', style: Theme.of(context).textTheme.titleLarge),
            ...catalog.exercises.map(
              (item) => ListTile(
                title: Text(item.name),
                subtitle: Text(item.instructions ?? item.description ?? ''),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
