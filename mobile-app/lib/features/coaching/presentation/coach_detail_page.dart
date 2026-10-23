import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_selection_service.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_models.dart';

class CoachDetailPage extends StatefulWidget {
  const CoachDetailPage({
    required this.coachId,
    required this.service,
    super.key,
  });

  final String coachId;
  final CoachSelectionService service;

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
      appBar: AppBar(title: const Text('Chi tiết Coach')),
      body: coach == null && _loadError == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_loadError != null) ...[
                  Text(
                    _loadError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
                if (coach != null) ...[
                  Text(
                    coach.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (coach.biography?.isNotEmpty == true)
                    Text(coach.biography!),
                  if (coach.specialties.isNotEmpty)
                    Text('Chuyên môn: ${coach.specialties.join(', ')}'),
                  if (coach.qualifications?.isNotEmpty == true)
                    Text('Bằng cấp: ${coach.qualifications}'),
                  if (coach.experienceYears != null)
                    Text('Kinh nghiệm: ${coach.experienceYears} năm'),
                  if (coach.availabilityNote?.isNotEmpty == true)
                    Text(coach.availabilityNote!),
                  Text(
                    coach.availableSlots > 0
                        ? 'Còn ${coach.availableSlots} suất'
                        : 'Đã hết suất',
                  ),
                  if (_sent)
                    const Text('Yêu cầu đã được gửi.')
                  else if (coach.availableSlots > 0) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('coach-message'),
                      controller: _message,
                      maxLength: 2000,
                      maxLines: 3,
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        labelText: 'Lời nhắn (không bắt buộc)',
                      ),
                    ),
                    if (_submitError != null)
                      Text(
                        _submitError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    FilledButton(
                      onPressed: _sending ? null : _send,
                      child: Text(_sending ? 'Đang gửi…' : 'Gửi yêu cầu'),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
