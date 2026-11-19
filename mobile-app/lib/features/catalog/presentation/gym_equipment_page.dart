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
        foregroundColor: const Color(0xFFF7F9FC),
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
        title: const Text(
          'Phòng gym & thiết bị',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFFF7F9FC),
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
            backgroundColor: const Color(0xFF282320),
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
                            const Icon(
                              Icons.error_outline_rounded,
                              color: MetaGymTheme.dangerCoral,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFF7F9FC),
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
                            foregroundColor: MetaGymTheme.brandOrange,
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
                            color: MetaGymTheme.reflectionBlue,
                          ),
                          const SizedBox(height: 10),
                          for (final entry in _gym!.openingHours.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${entry.key}: ${entry.value}',
                                style: const TextStyle(
                                  color: Color(0xFFC8C2BC),
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
                            color: MetaGymTheme.coachAvatarBackground,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _gym!.rules!,
                            style: const TextStyle(
                              color: Color(0xFFC8C2BC),
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
                      const Expanded(
                        child: Text(
                          'Máy tại phòng gym',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFFF7F9FC),
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
                          color: const Color(0x80211E1C),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x9A8C8176)),
                        ),
                        child: Text(
                          '${visible.length} máy',
                          style: const TextStyle(
                            color: Color(0xFFC8C2BC),
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
                    style: const TextStyle(
                      color: MetaGymTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm tên máy',
                      hintStyle: const TextStyle(
                        color: Color(0xFFB8B0A8),
                        fontSize: 13.5,
                      ),
                      filled: true,
                      fillColor: const Color(0xC42B2622),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: MetaGymTheme.brandOrange,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Tìm máy',
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: _load,
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: MetaGymTheme.textPrimary,
                          size: 20,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                        borderSide: const BorderSide(
                          color: Color(0xA3A79D92),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                        borderSide: const BorderSide(
                          color: Color(0xA3A79D92),
                        ),
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
                      const Row(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            color: Color(0xFFC8C2BC),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Không có máy phù hợp.',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
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

  Widget _gymCard(GymProfile gym) => MetaGymHeroGlassCard(
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
                color: const Color(0x24FF5E36),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x4DFF5E36)),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: MetaGymTheme.brandOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                gym.name,
                style: const TextStyle(
                  color: Color(0xFFF7F9FC),
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
            const Icon(
              Icons.location_on_outlined,
              size: 19,
              color: MetaGymTheme.brandOrange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                gym.address,
                style: const TextStyle(
                  color: Color(0xFFF7F9FC),
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
            style: const TextStyle(
              color: Color(0xFFC8C2BC),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
        if (gym.phone?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Text(
            'Điện thoại: ${gym.phone}',
            style: const TextStyle(
              color: Color(0xFFC8C2BC),
              fontSize: 13,
              fontFeatures: MetaGymTheme.tabularFigures,
            ),
          ),
        ],
        if (gym.email?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            'Email: ${gym.email}',
            style: const TextStyle(color: Color(0xFFC8C2BC), fontSize: 13),
          ),
        ],
      ],
    ),
  );

  Widget _heading(
    IconData icon,
    String title, {
    Color color = MetaGymTheme.brandOrange,
  }) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFF7F9FC),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
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
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      selectedColor: const Color(0xFF493025),
      backgroundColor: const Color(0xC42B2622),
      showCheckmark: false,
      side: BorderSide(
        color: _category == value
            ? MetaGymTheme.brandOrange
            : const Color(0xA3A79D92),
      ),
      labelStyle: TextStyle(
        color: _category == value
            ? const Color(0xFFF7F9FC)
            : const Color(0xFFC8C2BC),
        fontWeight: _category == value ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
  );

  Widget _equipmentRow(CatalogItem item) => MetaGymGlassCard(
    padding: EdgeInsets.zero,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
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
                  color: const Color(0x24FF5E36),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x4DFF5E36)),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: MetaGymTheme.brandOrange,
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
                      style: const TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.category != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.category!,
                        style: const TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.videoUrl?.isNotEmpty == true) ...[
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: MetaGymTheme.reflectionBlue,
                  size: 21,
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFC8C2BC)),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _surface(Widget child) =>
      MetaGymGlassCard(padding: const EdgeInsets.all(16), child: child);
}
