import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/training/data/member_nutrition_service.dart';
import 'package:meta_gym_app/features/training/domain/nutrition_models.dart';
import 'package:provider/provider.dart';

class MemberNutritionPage extends StatefulWidget {
  const MemberNutritionPage({this.service, super.key});

  final MemberNutritionService? service;

  @override
  State<MemberNutritionPage> createState() => _MemberNutritionPageState();
}

class _MemberNutritionPageState extends State<MemberNutritionPage> {
  MemberNutritionService? _service;
  NutritionGuide? _active;
  List<NutritionGuide> _history = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberNutritionService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _active = null;
      _history = const [];
      _error = null;
    });
    try {
      final active = await _service!.getActive();
      final history = await _service!.getHistory();
      if (!mounted) return;
      setState(() {
        _active = active?.status == 'ACTIVE' ? active : null;
        _history = history
            .where(
              (guide) => guide.status == 'ARCHIVED' && guide.id != active?.id,
            )
            .toList();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được dinh dưỡng.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: MetaGymTheme.darkCanvas,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Dinh dưỡng',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            SafeArea(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.brandOrange,
                      ),
                    )
                  : RefreshIndicator(
                      color: MetaGymTheme.brandOrange,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          if (_error != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF453A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0x66FF453A),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFFF6961),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFFF857D),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _load,
                              style: TextButton.styleFrom(
                                foregroundColor: MetaGymTheme.brandOrange,
                              ),
                              child: const Text('Thử lại'),
                            ),
                          ] else ...[
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 12, top: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.restaurant_menu,
                                    color: MetaGymTheme.brandOrange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hiện hành',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (_active == null)
                              const MetaGymGlassCard(
                                padding: EdgeInsets.all(16),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.no_meals,
                                    color: Colors.white38,
                                  ),
                                  title: Text(
                                    'Bạn chưa có hướng dẫn dinh dưỡng.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              )
                            else
                              MetaGymGlassCard(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0x3334C759),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.eco,
                                            color: Color(0xFF34C759),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _active!.title,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_active!.statusLabel} · Phiên bản ${_active!.version}',
                                                style: const TextStyle(
                                                  color: Color(0xFF34C759),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _active!.publicationLabel,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(color: Color(0x26FFFFFF)),
                                    const SizedBox(height: 10),
                                    Text(
                                      _active!.content,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.history,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Lịch sử',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (_history.isEmpty)
                              const MetaGymGlassCard(
                                padding: EdgeInsets.all(16),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.history_toggle_off,
                                    color: Colors.white38,
                                  ),
                                  title: Text(
                                    'Chưa có hướng dẫn cũ.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              )
                            else
                              for (final guide in _history)
                                MetaGymGlassCard(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      iconColor: MetaGymTheme.brandOrange,
                                      collapsedIconColor: Colors.white54,
                                      title: Text(
                                        guide.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${guide.statusLabel} · ${guide.publicationLabel}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 13,
                                        ),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            16,
                                            16,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              guide.content,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
}
