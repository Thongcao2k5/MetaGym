import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/progress/data/coach_progress_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/domain/meal_log.dart';
import 'package:meta_gym_app/features/progress/domain/progress_comment.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';
import 'package:provider/provider.dart';

class CoachProgressPage extends StatefulWidget {
  const CoachProgressPage({
    required this.memberId,
    required this.memberName,
    this.service,
    super.key,
  });
  final String memberId;
  final String memberName;
  final CoachProgressService? service;
  @override
  State<CoachProgressPage> createState() => _CoachProgressPageState();
}

class _CoachProgressPageState extends State<CoachProgressPage> {
  CoachProgressService? _service;
  ProgressSummary? _summary;
  List<WorkoutLog> _workouts = const [];
  List<MealLog> _meals = const [];
  List<BodyMeasurement> _measurements = const [];
  List<ProgressPhoto> _photos = const [];
  List<ProgressComment> _comments = const [];
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<CoachProgressService>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _summary = null;
      _workouts = const [];
      _meals = const [];
      _measurements = const [];
      _photos = const [];
      _comments = const [];
    });
    try {
      final summary = await _service!.getSummary(widget.memberId);
      final workouts = await _service!.getWorkouts(widget.memberId);
      final meals = await _service!.getMeals(widget.memberId);
      final measurements = await _service!.getMeasurements(widget.memberId);
      final photos = await _service!.getPhotos(widget.memberId);
      final comments = await _service!.getComments(widget.memberId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _workouts = workouts;
          _meals = meals;
          _measurements = measurements;
          _photos = photos;
          _comments = comments;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không còn quyền xem tiến độ.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _comment({String? targetKey, String? targetId}) async {
    final content = await showDialog<String>(
      context: context,
      builder: (_) => const _ProgressCommentDialog(),
    );
    if (content == null || !mounted) return;
    try {
      await _service!.comment({
        'memberId': widget.memberId,
        'content': content,
        if (targetKey != null && targetId != null) targetKey: targetId,
      });
      final comments = await _service!.getComments(widget.memberId);
      if (mounted) setState(() => _comments = comments);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 403 || error.statusCode == 404) {
        await _load();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không gửi được nhận xét.')),
        );
      }
    }
  }

  Widget _section(String title, List<Widget> items, int count) => ExpansionTile(
    title: Text(title),
    subtitle: Text('$count bản ghi'),
    children: items.isEmpty
        ? [const ListTile(title: Text('Chưa có dữ liệu.'))]
        : [
            ...items,
            if (count == 100)
              const ListTile(
                title: Text('Đang hiển thị 100 bản ghi mới nhất.'),
              ),
          ],
  );

  Widget _record(
    String title,
    String subtitle,
    String targetKey,
    String id, {
    VoidCallback? onOpen,
  }) => ListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: onOpen,
    trailing: TextButton(
      onPressed: () => _comment(targetKey: targetKey, targetId: id),
      child: const Text('Nhận xét'),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Tiến độ · ${widget.memberName}')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                ] else if (_summary case final summary?) ...[
                  Text(
                    'Tổng quan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('Buổi tập: ${summary.workoutCount}'),
                  Text('Bữa ăn: ${summary.mealCount}'),
                  Text('Ảnh tiến trình: ${summary.progressPhotoCount}'),
                  Text(
                    summary.latestMeasurement == null
                        ? 'Chưa có số đo.'
                        : 'Cân nặng mới nhất: ${summary.latestMeasurement!.weightKg} kg',
                  ),
                  const Text('Biểu đồ theo hội viên chưa có API riêng.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _comment(),
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Nhận xét chung'),
                  ),
                  _section('Nhật ký tập', [
                    for (final log in _workouts)
                      _record(
                        '${log.durationMinutes ?? 0} phút',
                        formatProgressTime(log.performedAt),
                        'workoutLogId',
                        log.id,
                      ),
                  ], _workouts.length),
                  _section('Nhật ký ăn', [
                    for (final meal in _meals)
                      _record(
                        meal.mealName,
                        formatProgressTime(meal.eatenAt),
                        'mealLogId',
                        meal.id,
                      ),
                  ], _meals.length),
                  _section('Số đo', [
                    for (final measurement in _measurements)
                      _record(
                        '${measurement.weightKg} kg',
                        formatProgressTime(measurement.measuredAt),
                        'measurementId',
                        measurement.id,
                      ),
                  ], _measurements.length),
                  _section('Ảnh tiến trình', [
                    for (final photo in _photos)
                      _record(
                        photo.poseLabel,
                        formatProgressTime(photo.takenAt),
                        'progressPhotoId',
                        photo.id,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _CoachPhotoPage(
                              service: _service!,
                              photo: photo,
                            ),
                          ),
                        ),
                      ),
                  ], _photos.length),
                  _section('Nhận xét đã gửi', [
                    for (final comment in _comments)
                      ListTile(
                        title: Text(comment.content),
                        subtitle: Text(formatProgressTime(comment.createdAt)),
                      ),
                  ], _comments.length),
                ],
              ],
            ),
          ),
  );
}

class _CoachPhotoPage extends StatefulWidget {
  const _CoachPhotoPage({required this.service, required this.photo});
  final CoachProgressService service;
  final ProgressPhoto photo;
  @override
  State<_CoachPhotoPage> createState() => _CoachPhotoPageState();
}

class _ProgressCommentDialog extends StatefulWidget {
  const _ProgressCommentDialog();
  @override
  State<_ProgressCommentDialog> createState() => _ProgressCommentDialogState();
}

class _ProgressCommentDialogState extends State<_ProgressCommentDialog> {
  final _content = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Gửi nhận xét'),
    content: TextField(
      key: const Key('progress-comment'),
      controller: _content,
      maxLength: 5000,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Nội dung',
        errorText: _invalid ? 'Vui lòng nhập nhận xét.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      FilledButton(
        onPressed: () {
          final content = _content.text.trim();
          if (content.isEmpty) {
            setState(() => _invalid = true);
            return;
          }
          Navigator.pop(context, content);
        },
        child: const Text('Gửi nhận xét'),
      ),
    ],
  );
}

class _CoachPhotoPageState extends State<_CoachPhotoPage> {
  Uri? _url;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _url = null;
      _error = null;
    });
    try {
      final url = await widget.service.getPhotoAccessUrl(widget.photo.mediaId);
      if (mounted) setState(() => _url = url);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không mở được ảnh.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ảnh tiến trình')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${widget.photo.poseLabel} · ${formatProgressTime(widget.photo.takenAt)}',
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ],
        if (_url case final url?)
          Image.network(
            url.toString(),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Column(
              children: [
                const Text('Ảnh lỗi hoặc URL đã hết hạn.'),
                TextButton(onPressed: _load, child: const Text('Tải lại ảnh')),
              ],
            ),
          ),
      ],
    ),
  );
}
