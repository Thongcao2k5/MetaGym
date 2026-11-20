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
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
        title: const Text(
          'Phòng gym & thiết bị',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          RefreshIndicator(
            onRefresh: _load,
            color: MetaGymTheme.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + kToolbarHeight + 12,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                if (_loading && _gym == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.primary,
                      ),
                    ),
                  )
                else if (_error != null)
                  _surface(
                    Column(
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
                  )
                else if (_gym != null) ...[
                  _gymCard(_gym!),
                  if (_gym!.openingHours.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _surface(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _heading(Icons.schedule_rounded, 'Giờ mở cửa'),
                          const SizedBox(height: 10),
                          for (final entry in _gym!.openingHours.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${entry.key}: ${entry.value}',
                                style: const TextStyle(
                                  color: Color(0xFFE4DAD1),
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
                          _heading(Icons.info_outline_rounded, 'Nội quy'),
                          const SizedBox(height: 10),
                          Text(
                            _gym!.rules!,
                            style: const TextStyle(
                              color: Color(0xFFE4DAD1),
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
                      const Expanded(
                        child: Text(
                          'Máy tại phòng gym',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${visible.length} máy',
                        style: const TextStyle(
                          color: Color(0xFFB8B0A8),
                          fontSize: 12,
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
                    decoration: InputDecoration(
                      hintText: 'Tìm tên máy',
                      filled: true,
                      fillColor: const Color(0xED2B2622),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFFB45CFF),
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Tìm máy',
                        onPressed: _load,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xA3A79D92)),
                      ),
                    ),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _chip('Tất cả', null),
                          for (final category in categories)
                            _chip(category, category),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    _surface(
                      const Text(
                        'Không có máy phù hợp.',
                        style: TextStyle(color: Colors.white),
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

  Widget _gymCard(GymProfile gym) => _surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gym.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 19,
              color: MetaGymTheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                gym.address,
                style: const TextStyle(color: Color(0xFFE4DAD1), height: 1.4),
              ),
            ),
          ],
        ),
        if (gym.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          Text(
            gym.description!,
            style: const TextStyle(color: Color(0xFFE4DAD1), height: 1.5),
          ),
        ],
        if (gym.phone?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Text(
            'Điện thoại: ${gym.phone}',
            style: const TextStyle(color: Color(0xFFB8B0A8)),
          ),
        ],
        if (gym.email?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            'Email: ${gym.email}',
            style: const TextStyle(color: Color(0xFFB8B0A8)),
          ),
        ],
      ],
    ),
  );

  Widget _heading(IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 20, color: const Color(0xFFB45CFF)),
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

  Widget _chip(String label, String? value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _category == value,
      onSelected: (_) => setState(() => _category = value),
      selectedColor: const Color(0xFF493025),
      backgroundColor: const Color(0xE42B2622),
      showCheckmark: false,
      side: BorderSide(
        color: _category == value
            ? MetaGymTheme.primary
            : const Color(0xA3A79D92),
      ),
      labelStyle: TextStyle(
        color: _category == value ? Colors.white : const Color(0xFFB8B0A8),
      ),
    ),
  );

  Widget _equipmentRow(CatalogItem item) => MetaGymGlassCard(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      child: MetaGymTap(
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
                  color: const Color(0x553A214C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: Color(0xFFB45CFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.category != null)
                      Text(
                        item.category!,
                        style: const TextStyle(
                          color: Color(0xFFB8B0A8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (item.videoUrl?.isNotEmpty == true)
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Color(0xFFB45CFF),
                  size: 21,
                ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFC7BDB5)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _surface(Widget child) => MetaGymGlassCard(
    padding: EdgeInsets.zero,
    child: ColoredBox(
      color: const Color(0xA0211E1C),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}
