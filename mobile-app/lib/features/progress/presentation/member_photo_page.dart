import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:provider/provider.dart';

class MemberPhotoPage extends StatefulWidget {
  const MemberPhotoPage({this.service, this.picker, super.key});
  final MemberPhotoService? service;
  final ProgressPhotoPicker? picker;
  @override
  State<MemberPhotoPage> createState() => _MemberPhotoPageState();
}

class _MemberPhotoPageState extends State<MemberPhotoPage> {
  MemberPhotoService? _service;
  ProgressPhotoPicker? _picker;
  List<ProgressPhoto> _photos = const [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<MemberPhotoService>();
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
      if (!more) {
        _photos = const [];
        _page = 0;
      }
    });
    try {
      final next = await _service!.getPage(_page + 1);
      if (mounted) {
        setState(() {
          _photos = [..._photos, ...next];
          _page++;
          _hasMore = next.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được ảnh tiến trình.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final saved = await MetaGymNavigation.pushOnce<bool>(
      context,
      MetaGymPageRoute(
        builder: (_) => _PhotoFormPage(service: _service!, picker: _picker!),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ảnh tiến trình')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.add_a_photo_outlined),
      label: const Text('Thêm ảnh'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_loading && _photos.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => _load(more: _photos.isNotEmpty),
              child: const Text('Thử lại'),
            ),
          ],
          if (!_loading && _error == null && _photos.isEmpty)
            const ListTile(title: Text('Bạn chưa có ảnh tiến trình.')),
          for (final photo in _photos)
            Card(
              child: ListTile(
                title: Text(photo.poseLabel),
                subtitle: Text(formatProgressTime(photo.takenAt)),
                leading: const Icon(Icons.image_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => MetaGymNavigation.pushOnce(
                  context,
                  MetaGymPageRoute<void>(
                    builder: (_) =>
                        _PhotoDetailPage(service: _service!, photo: photo),
                  ),
                ),
              ),
            ),
          if (_loading && _photos.isNotEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_hasMore && !_loading)
            TextButton(
              onPressed: () => _load(more: true),
              child: const Text('Tải thêm'),
            ),
        ],
      ),
    ),
  );
}

class _PhotoFormPage extends StatefulWidget {
  const _PhotoFormPage({required this.service, required this.picker});
  final MemberPhotoService service;
  final ProgressPhotoPicker picker;
  @override
  State<_PhotoFormPage> createState() => _PhotoFormPageState();
}

class _PhotoFormPageState extends State<_PhotoFormPage> {
  final _date = TextEditingController();
  final _notes = TextEditingController();
  SelectedProgressImage? _image;
  String? _uploadedMediaId;
  String? _pose;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _date.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final image = await widget.picker.pick();
      if (image == null || !mounted) return;
      setState(() {
        _image = image;
        _uploadedMediaId = null;
        _error = validateProgressImage(image);
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không chọn được ảnh.');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final image = _image;
    final date = parseProgressTime(_date.text);
    final validation = image == null
        ? 'Hãy chọn ảnh PNG hoặc JPEG.'
        : validateProgressImage(image);
    if (validation != null || date == null) {
      setState(
        () => _error = validation ?? 'Nhập ngày giờ hợp lệ (dd/MM/yyyy HH:mm).',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _uploadedMediaId ??= await widget.service.upload(image!);
      await widget.service.create({
        'mediaId': _uploadedMediaId,
        'takenAt': date.toUtc().toIso8601String(),
        'pose': _pose,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được ảnh lên.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thêm ảnh tiến trình')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _saving ? null : _pick,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Chọn ảnh'),
        ),
        if (_image != null)
          Text(
            '${_image!.name} · ${(_image!.bytes.length / 1024).toStringAsFixed(0)} KB',
          ),
        TextField(
          key: const Key('photo-date'),
          controller: _date,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            labelText: 'Ngày chụp (dd/MM/yyyy HH:mm)',
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _pose,
          decoration: const InputDecoration(labelText: 'Góc chụp'),
          items: const [
            DropdownMenuItem(value: 'FRONT', child: Text('Mặt trước')),
            DropdownMenuItem(value: 'SIDE', child: Text('Mặt bên')),
            DropdownMenuItem(value: 'BACK', child: Text('Mặt sau')),
            DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
          ],
          onChanged: (value) => setState(() => _pose = value),
        ),
        TextField(
          controller: _notes,
          maxLength: 5000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Ghi chú'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang tải lên…' : 'Lưu ảnh'),
        ),
      ],
    ),
  );
}

class _PhotoDetailPage extends StatefulWidget {
  const _PhotoDetailPage({required this.service, required this.photo});
  final MemberPhotoService service;
  final ProgressPhoto photo;
  @override
  State<_PhotoDetailPage> createState() => _PhotoDetailPageState();
}

class _PhotoDetailPageState extends State<_PhotoDetailPage> {
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
      final url = await widget.service.getAccessUrl(widget.photo.mediaId);
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
    appBar: AppBar(title: const Text('Xem ảnh tiến trình')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${widget.photo.poseLabel} · ${formatProgressTime(widget.photo.takenAt)}',
        ),
        if (widget.photo.notes?.isNotEmpty ?? false) Text(widget.photo.notes!),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ],
        if (_url case final url?) ...[
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
      ],
    ),
  );
}
