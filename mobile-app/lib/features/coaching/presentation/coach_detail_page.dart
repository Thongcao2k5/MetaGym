import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:provider/provider.dart';

class CoachDetailPage extends StatefulWidget {
  const CoachDetailPage({
    required this.coachId,
    required this.service,
    this.messagingService,
    this.currentUserId,
    super.key,
  });

  final String coachId;
  final CoachSelectionService service;
  final MessagingService? messagingService;
  final String? currentUserId;

  @override
  State<CoachDetailPage> createState() => _CoachDetailPageState();
}

class _CoachDetailPageState extends State<CoachDetailPage> {
  final _message = TextEditingController();
  CoachProfile? _coach;
  String? _loadError;
  String? _submitError;
  bool _sending = false;
  bool _sent = false;
  bool _openingChat = false;
  String? _chatError;

  Future<void> _openChat() async {
    if (_openingChat) return;
    final messaging =
        widget.messagingService ?? context.read<MessagingService>();
    final currentUserId =
        widget.currentUserId ?? context.read<SessionController>().user!.id;
    setState(() {
      _openingChat = true;
      _chatError = null;
    });
    try {
      final conversation = await messaging.startConversation(
        coachId: widget.coachId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConversationDetailPage(
            conversation: conversation,
            service: messaging,
            currentUserId: currentUserId,
            picker: DeviceProgressPhotoPicker(),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _chatError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _chatError = 'Không mở được cuộc trò chuyện.');
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _coach = null;
      _loadError = null;
    });
    try {
      final coach = await widget.service.getCoach(widget.coachId);
      if (mounted) setState(() => _coach = coach);
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Không tải được chi tiết Coach.');
      }
    }
  }

  Future<void> _send() async {
    if (_sending || _sent) return;
    setState(() {
      _sending = true;
      _submitError = null;
    });
    try {
      final message = _message.text.trim();
      await widget.service.sendRequest(
        widget.coachId,
        message.isEmpty ? null : message,
      );
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _submitError = error.message);
    } catch (_) {
      if (mounted) setState(() => _submitError = 'Không gửi được yêu cầu.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coach = _coach;
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Chi tiết Coach',
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
            child: coach == null && _loadError == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: [
                      if (_loadError != null) ...[
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
                                  _loadError!,
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
                      ],
                      if (coach != null) ...[
                        MetaGymGlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundColor: MetaGymTheme.brandOrange
                                        .withValues(alpha: 0.2),
                                    child: Text(
                                      coach.fullName.isNotEmpty
                                          ? coach.fullName[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        color: MetaGymTheme.brandOrange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 26,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          coach.fullName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: coach.availableSlots > 0
                                                ? const Color(0x3334C759)
                                                : const Color(0x33FF453A),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                  ),
                                ],
                              ),
                              if (coach.biography?.isNotEmpty == true) ...[
                                const SizedBox(height: 16),
                                Text(
                                  coach.biography!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              const Divider(color: Color(0x26FFFFFF)),
                              const SizedBox(height: 12),
                              if (coach.specialties.isNotEmpty) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.fitness_center,
                                      color: MetaGymTheme.brandOrange,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Chuyên môn: ${coach.specialties.join(', ')}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (coach.qualifications?.isNotEmpty == true) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium,
                                      color: Color(0xFFFF9F0A),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Bằng cấp: ${coach.qualifications}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (coach.experienceYears != null) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.history,
                                      color: Color(0xFF8EB9E5),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Kinh nghiệm: ${coach.experienceYears} năm',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (coach.availabilityNote?.isNotEmpty ==
                                  true) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event_note,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        coach.availabilityNote!,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _openingChat ? null : _openChat,
                          child: const Text('Nhắn tin với Coach'),
                        ),
                        if (_chatError != null) Text(_chatError!),
                        if (context.read<ApiClient?>() != null)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: coach.availableSlots > 0
                                  ? MetaGymTheme.brandOrange
                                  : Colors.grey.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CoachOffersPage(coachId: widget.coachId),
                              ),
                            ),
                            child: const Text('Xem gói Coach'),
                          )
                        else if (_sent)
                          MetaGymGlassCard(
                            padding: const EdgeInsets.all(16),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF34C759),
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Yêu cầu đã được gửi.',
                                    style: TextStyle(
                                      color: Color(0xFF34C759),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (coach.availableSlots > 0) ...[
                          MetaGymGlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  key: const Key('coach-message'),
                                  controller: _message,
                                  maxLength: 2000,
                                  maxLines: 3,
                                  enabled: !_sending,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Lời nhắn (không bắt buộc)',
                                    labelStyle: TextStyle(
                                      color: Colors.white70,
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x38D4E4FF),
                                      ),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: MetaGymTheme.brandOrange,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_submitError != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _submitError!,
                                    style: const TextStyle(
                                      color: Color(0xFFFF6961),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: MetaGymTheme.brandOrange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _sending ? null : _send,
                                  child: Text(
                                    _sending ? 'Đang gửi…' : 'Gửi yêu cầu',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
