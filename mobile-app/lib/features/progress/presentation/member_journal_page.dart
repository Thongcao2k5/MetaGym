import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/membership/data/membership_service.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/domain/journal_entry.dart';
import 'package:provider/provider.dart';

class MemberJournalPage extends StatefulWidget {
  const MemberJournalPage({
    this.service, this.membershipService, this.photoService, this.picker,
    super.key,
  });

  final MemberJournalService? service;
  final MembershipService? membershipService;
  final MemberPhotoService? photoService;
  final ProgressPhotoPicker? picker;

  @override
  State<MemberJournalPage> createState() => _MemberJournalPageState();
}

class _MemberJournalPageState extends State<MemberJournalPage> {
  MemberJournalService? _service;
  MembershipService? _membershipService;
  MemberPhotoService? _photoService;
  ProgressPhotoPicker? _picker;
  List<JournalEntry> _entries = const [];
  List<JournalChartPoint> _chart = const [];
  String? _error;
  String? _accessError;
  bool _loading = true;
  bool _canWrite = false;
  bool _hasMore = false;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberJournalService>();
    _membershipService = widget.membershipService ?? context.read<MembershipService>();
    _photoService = widget.photoService ?? context.read<MemberPhotoService>();
    _picker = widget.picker ?? DeviceProgressPhotoPicker();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load({bool more = false}) async {
    if (more && (!_hasMore || _loading)) return;
    setState(() {
      _loading = true;
      _error = null;
      _accessError = null;
      if (!more) {
        _entries = const [];
        _chart = const [];
        _page = 0;
      }
    });
    try {
      final page = await _service!.getPage(_page + 1);
      if (more) {
        if (!mounted) return;
        setState(() {
          _entries = [..._entries, ...page];
          _page++;
          _hasMore = page.length == 20;
        });
      } else {
        final chart = await _service!.getChart();
        var canWrite = false;
        String? accessError;
        try {
          final memberships = await _membershipService!.getCurrentMemberships();
          canWrite = memberships.any((item) => item.status == 'ACTIVE');
        } catch (_) {
          accessError = 'Không kiểm tra được gói tập. Nhật ký tạm thời chỉ xem.';
        }
        if (!mounted) return;
        setState(() {
          _entries = page;
          _chart = chart;
          _page = 1;
          _hasMore = page.length == 20;
          _canWrite = canWrite;
          _accessError = accessError;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được nhật ký tập.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([JournalEntry? entry]) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _JournalEditor(
        service: _service!, photoService: _photoService!, picker: _picker!,
        entry: entry,
      ),
    ));
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete(JournalEntry entry) async {
    final accepted = await showDialog<bool>(context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhật ký?'),
        content: Text('Nhật ký ngày ${_dateLabel(entry.journalDate)} sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa')),
        ],
      ));
    if (accepted != true || !mounted) return;
    try {
      await _service!.delete(entry.id);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhật ký tập luyện')),
    floatingActionButton: _canWrite ? FloatingActionButton.extended(
      onPressed: () => _openEditor(),
      icon: const Icon(Icons.add), label: const Text('Ghi hôm nay'),
    ) : null,
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          if (_loading && _entries.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
          if (_accessError != null)
            Padding(padding: const EdgeInsets.only(bottom: 8),
              child: Text(_accessError!, style: TextStyle(
                color: Theme.of(context).colorScheme.error))),
          if (!_loading && _error == null && !_canWrite)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Bạn có thể xem nhật ký cũ. Cần gói tập đang hoạt động để ghi hoặc sửa.'),
            ),
          if (!_loading && _error == null && _entries.isEmpty)
            const ListTile(
              title: Text('Chưa có nhật ký tập.'),
              subtitle: Text('Ghi buổi tập đầu tiên để theo dõi quá trình của bạn.'),
            ),
          if (_chart.isNotEmpty) ...[
            Text('Ba vòng cơ thể', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _JournalChart(points: _chart),
            const SizedBox(height: 24),
          ],
          for (final entry in _entries) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dateLabel(entry.journalDate),
                      style: Theme.of(context).textTheme.titleMedium),
                    if (entry.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 8), Text(entry.notes!),
                    ],
                    const SizedBox(height: 8),
                    Text('${entry.achievements.length} thành tích · ${entry.photoMediaIds.length} ảnh'),
                    if (entry.chestCm != null || entry.waistCm != null || entry.hipsCm != null)
                      Text('Ngực ${entry.chestCm ?? '—'} · Eo ${entry.waistCm ?? '—'} · Mông ${entry.hipsCm ?? '—'} cm'),
                    if (entry.achievements.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final achievement in entry.achievements)
                        Text('${achievement.title}: ${achievement.result}'),
                    ],
                    if (entry.photoMediaIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final id in entry.photoMediaIds)
                          _JournalPhoto(id: id, service: _photoService!),
                      ]),
                    ],
                    if (_canWrite)
                      Row(children: [
                        TextButton(onPressed: () => _openEditor(entry),
                          child: const Text('Sửa')),
                        TextButton(onPressed: () => _delete(entry),
                          child: const Text('Xóa')),
                      ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_hasMore && !_loading)
            TextButton(onPressed: () => _load(more: true),
              child: const Text('Tải thêm')),
        ],
      ),
    ),
  );
}

String _dateLabel(String day) {
  final parts = day.split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : day;
}

class _JournalPhoto extends StatefulWidget {
  const _JournalPhoto({required this.id, required this.service});
  final String id;
  final MemberPhotoService service;

  @override
  State<_JournalPhoto> createState() => _JournalPhotoState();
}

class _JournalPhotoState extends State<_JournalPhoto> {
  late Future<Uri> _accessUrl;

  @override
  void initState() {
    super.initState();
    _accessUrl = widget.service.getAccessUrl(widget.id);
  }

  @override
  void didUpdateWidget(covariant _JournalPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.service != widget.service) {
      _accessUrl = widget.service.getAccessUrl(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uri>(
    future: _accessUrl,
    builder: (context, snapshot) => SizedBox(
      width: 80, height: 80,
      child: snapshot.hasData
          ? Image.network(snapshot.data.toString(), fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined))
          : const Icon(Icons.image_outlined),
    ),
  );
}

class _JournalChart extends StatelessWidget {
  const _JournalChart({required this.points});
  final List<JournalChartPoint> points;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 150, width: double.infinity,
          child: CustomPaint(painter: _JournalChartPainter(points))),
        const SizedBox(height: 12),
        const Wrap(spacing: 16, children: [
          _ChartLegend('Ngực', Color(0xFFFF5E36)),
          _ChartLegend('Eo', Color(0xFF70AEE8)),
          _ChartLegend('Mông', Color(0xFF2ECC71)),
        ]),
      ]),
    ),
  );
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.circle, size: 10, color: color),
    const SizedBox(width: 5), Text(label),
  ]);
}

class _JournalChartPainter extends CustomPainter {
  const _JournalChartPainter(this.points);
  final List<JournalChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final all = <double>[
      for (final point in points) ...[
        if (point.chestCm != null) point.chestCm!,
        if (point.waistCm != null) point.waistCm!,
        if (point.hipsCm != null) point.hipsCm!,
      ],
    ];
    if (all.isEmpty) return;
    var min = all.first;
    var max = all.first;
    for (final value in all) {
      if (value < min) min = value;
      if (value > max) max = value;
    }
    final range = max == min ? 1.0 : max - min;
    final width = size.width - 16;
    final height = size.height - 16;
    void series(Color color, double? Function(JournalChartPoint) get) {
      final paint = Paint()..color = color..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final dots = Paint()..color = color;
      final path = Path();
      var started = false;
      for (var index = 0; index < points.length; index++) {
        final value = get(points[index]);
        if (value == null) continue;
        final x = 8 + (points.length == 1 ? width / 2
            : width * index / (points.length - 1));
        final y = 8 + height * (1 - (value - min) / range);
        if (!started) { path.moveTo(x, y); started = true; }
        else { path.lineTo(x, y); }
        canvas.drawCircle(Offset(x, y), 3.5, dots);
      }
      canvas.drawPath(path, paint);
    }
    series(const Color(0xFFFF5E36), (point) => point.chestCm);
    series(const Color(0xFF70AEE8), (point) => point.waistCm);
    series(const Color(0xFF2ECC71), (point) => point.hipsCm);
  }

  @override
  bool shouldRepaint(covariant _JournalChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _JournalEditor extends StatefulWidget {
  const _JournalEditor({
    required this.service, required this.photoService, required this.picker,
    this.entry,
  });

  final MemberJournalService service;
  final MemberPhotoService photoService;
  final ProgressPhotoPicker picker;
  final JournalEntry? entry;

  @override
  State<_JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<_JournalEditor> {
  final _notes = TextEditingController();
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _hips = TextEditingController();
  final _achievements = TextEditingController();
  final _newImages = <SelectedProgressImage>[];
  final _uploadedIds = <String>[];
  List<String> _existingPhotos = const [];
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry == null) return;
    _notes.text = entry.notes ?? '';
    _chest.text = entry.chestCm?.toString() ?? '';
    _waist.text = entry.waistCm?.toString() ?? '';
    _hips.text = entry.hipsCm?.toString() ?? '';
    _achievements.text = entry.achievements
        .map((item) => '${item.title} | ${item.result}').join('\n');
    _existingPhotos = List.of(entry.photoMediaIds);
  }

  @override
  void dispose() {
    _notes.dispose(); _chest.dispose(); _waist.dispose(); _hips.dispose();
    _achievements.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_existingPhotos.length + _newImages.length >= 3) return;
    try {
      final image = await widget.picker.pick();
      if (image == null || !mounted) return;
      final validation = validateProgressImage(image);
      if (validation != null) {
        setState(() => _error = validation);
        return;
      }
      setState(() {
        _newImages.add(image);
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Không chọn được ảnh. Hãy thử lại.');
    }
  }

  double? _readMeasurement(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : double.tryParse(value.replaceAll(',', '.'));
  }

  Future<void> _save() async {
    if (_saving) return;
    final numbers = [_readMeasurement(_chest), _readMeasurement(_waist),
      _readMeasurement(_hips)];
    final inputs = [_chest, _waist, _hips];
    if (List.generate(3, (index) => inputs[index].text.trim().isNotEmpty &&
        (numbers[index] == null || numbers[index]! <= 0 || numbers[index]! > 9999.99))
        .contains(true)) {
      setState(() => _error = 'Số đo phải lớn hơn 0 và không quá 9999,99 cm.');
      return;
    }
    final achievements = <Map<String, String>>[];
    for (final line in _achievements.text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final separator = line.indexOf('|');
      if (separator < 1 || separator == line.length - 1) {
        setState(() => _error = 'Mỗi thành tích cần dạng: Tên | Kết quả.');
        return;
      }
      final title = line.substring(0, separator).trim();
      final result = line.substring(separator + 1).trim();
      if (title.isEmpty || result.isEmpty || title.length > 150 || result.length > 1000) {
        setState(() => _error = 'Tên hoặc kết quả thành tích không hợp lệ.');
        return;
      }
      achievements.add({'title': title, 'result': result});
    }
    if (_notes.text.trim().length > 5000) {
      setState(() => _error = 'Ghi chú tối đa 5000 ký tự.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      for (var index = _uploadedIds.length; index < _newImages.length; index++) {
        _uploadedIds.add(await widget.photoService.upload(_newImages[index]));
      }
      final payload = <String, Object?>{
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'chestCm': numbers[0], 'waistCm': numbers[1], 'hipsCm': numbers[2],
        'achievements': achievements,
        'photoMediaIds': [..._existingPhotos, ..._uploadedIds],
      };
      if (widget.entry == null) {
        await widget.service.create(payload);
      } else {
        await widget.service.update(widget.entry!.id, payload);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không lưu được nhật ký. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.entry == null
        ? 'Ghi nhật ký hôm nay' : 'Sửa nhật ký ${_dateLabel(widget.entry!.journalDate)}')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Ngày ghi được xác định tự động theo giờ phòng tập.'),
      const SizedBox(height: 16),
      TextField(controller: _notes, maxLines: 3, maxLength: 5000,
        decoration: const InputDecoration(labelText: 'Hôm nay bạn đã tập gì?')),
      const SizedBox(height: 12),
      Text('Số đo tùy chọn (cm)', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Row(children: [
        for (final (label, controller) in [
          ('Ngực', _chest), ('Eo', _waist), ('Mông', _hips),
        ]) ...[
          Expanded(child: TextField(controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label))),
          if (label != 'Mông') const SizedBox(width: 8),
        ],
      ]),
      const SizedBox(height: 20),
      Text('Thành tích', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      TextField(controller: _achievements, maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'Hít đất | 20 lần\nChạy bộ | 3 km',
          helperText: 'Mỗi dòng là một mục: Tên | Kết quả',
        )),
      const SizedBox(height: 20),
      Text('Ảnh (tối đa 3)', style: Theme.of(context).textTheme.titleMedium),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final id in _existingPhotos)
          InputChip(label: const Text('Ảnh đã lưu'),
            onDeleted: _saving ? null : () => setState(() => _existingPhotos.remove(id))),
        for (final image in _newImages)
          InputChip(avatar: Image.memory(image.bytes,
              width: 28, height: 28, fit: BoxFit.cover),
            label: Text(image.name, overflow: TextOverflow.ellipsis),
            onDeleted: _saving ? null : () => setState(() {
              final index = _newImages.indexOf(image);
              _newImages.removeAt(index);
              if (index < _uploadedIds.length) _uploadedIds.removeAt(index);
            })),
      ]),
      TextButton.icon(onPressed: _saving ||
          _existingPhotos.length + _newImages.length >= 3 ? null : _pickPhoto,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Thêm ảnh')),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_error!, style: TextStyle(
          color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 16),
      FilledButton(onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Đang lưu…' : 'Lưu nhật ký')),
    ]),
  );
}
