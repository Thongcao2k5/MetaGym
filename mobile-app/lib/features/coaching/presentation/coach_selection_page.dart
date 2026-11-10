import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_detail_page.dart';
import 'package:provider/provider.dart';

class CoachSelectionPage extends StatefulWidget {
  const CoachSelectionPage({this.service, super.key});

  final CoachSelectionService? service;

  @override
  State<CoachSelectionPage> createState() => _CoachSelectionPageState();
}

class _CoachSelectionPageState extends State<CoachSelectionPage> {
  CoachSelectionService? _service;
  List<CoachProfile> _coaches = const [];
  String? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachSelectionService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final coaches = await _service!.getCoaches();
      if (mounted) setState(() => _coaches = coaches);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được Coach.');
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
        'Chọn Coach',
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
          child: _loading && _coaches.isEmpty
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
                            border: Border.all(color: const Color(0x66FF453A)),
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
                      ] else if (_coaches.isEmpty)
                        const MetaGymGlassCard(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Chưa có Coach để lựa chọn.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                      if (_error == null)
                        for (final coach in _coaches)
                          MetaGymGlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: MetaGymTheme.brandOrange
                                    .withValues(alpha: 0.2),
                                child: Text(
                                  coach.fullName.isNotEmpty
                                      ? coach.fullName[0].toUpperCase()
                                      : 'C',
                                  style: const TextStyle(
                                    color: MetaGymTheme.brandOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              title: Text(
                                coach.fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  coach.specialties.join(', '),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: coach.availableSlots > 0
                                          ? const Color(0x3334C759)
                                          : const Color(0x33FF453A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      coach.availableSlots > 0
                                          ? 'Còn ${coach.availableSlots} suất'
                                          : 'Đã hết suất',
                                      style: TextStyle(
                                        color: coach.availableSlots > 0
                                            ? const Color(0xFF34C759)
                                            : const Color(0xFFFF6961),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CoachDetailPage(
                                    coachId: coach.id,
                                    service: _service!,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}
