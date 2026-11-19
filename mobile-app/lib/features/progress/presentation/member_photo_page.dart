import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/domain/progress_time.dart';
import 'package:provider/provider.dart';

AppBar _buildPhotoAppBar(BuildContext context, String title) => AppBar(
  automaticallyImplyLeading: false,
  leadingWidth: 72,
  leading: Navigator.of(context).canPop()
      ? Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MetaGymCircleIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Quay lại',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        )
      : null,
  titleSpacing: Navigator.of(context).canPop() ? 8 : 16,
  title: Text(
    title,
    style: const TextStyle(
      color: MetaGymTheme.textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  ),
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
);

InputDecoration _warmPhotoInputDecoration(String label) => InputDecoration(
  labelText: label,
  labelStyle: const TextStyle(color: Color(0xFFB8B0A8)),
  counterStyle: const TextStyle(color: Color(0xFFB8B0A8)),
  filled: true,
  fillColor: const Color(0x80211E1C),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
    borderSide: const BorderSide(color: Color(0x9A8C8176)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
    borderSide: const BorderSide(color: Color(0x9A8C8176)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
    borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.4),
  ),
);

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
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PhotoFormPage(service: _service!, picker: _picker!),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: _buildPhotoAppBar(context, 'Ảnh tiến trình'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MetaGymTheme.brandOrange,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text(
          'Thêm ảnh',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          RefreshIndicator(
            color: MetaGymTheme.brandOrange,
            backgroundColor: const Color(0xFF282320),
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, topInset, 16, 96),
              children: [
                if (_loading && _photos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.brandOrange,
                      ),
                    ),
                  ),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF24161A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF642B32)),
                    ),
                    child: Row(
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
                            style: const TextStyle(color: Color(0xFFFFB2B6)),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: MetaGymTheme.brandOrange,
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: () => _load(more: _photos.isNotEmpty),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_loading && _error == null && _photos.isEmpty)
                  const MetaGymGlassCard(
                    padding: EdgeInsets.all(20),
                    child: ListTile(
                      leading: Icon(
                        Icons.photo_camera_outlined,
                        color: MetaGymTheme.brandOrange,
                      ),
                      title: Text(
                        'Bạn chưa có ảnh tiến trình.',
                        style: TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                for (final photo in _photos)
                  MetaGymGlassCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0x80211E1C),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x9A8C8176)),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          color: MetaGymTheme.brandOrange,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        photo.poseLabel,
                        style: const TextStyle(
                          color: MetaGymTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        formatProgressTime(photo.takenAt),
                        style: const TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 12.5,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFC8C2BC),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _PhotoDetailPage(
                            service: _service!,
                            photo: photo,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_loading && _photos.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: MetaGymTheme.brandOrange,
                      ),
                    ),
                  ),
                if (_hasMore && !_loading)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: MetaGymTheme.brandOrange,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => _load(more: true),
                    child: const Text('Tải thêm'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: _buildPhotoAppBar(context, 'Thêm ảnh tiến trình'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 32),
            children: [
              MetaGymGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MetaGymTheme.textPrimary,
                        backgroundColor: const Color(0x80211E1C),
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Color(0x9A8C8176)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusInput,
                          ),
                        ),
                      ),
                      onPressed: _saving ? null : _pick,
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: MetaGymTheme.brandOrange,
                      ),
                      label: const Text(
                        'Chọn ảnh',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_image != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${_image!.name} · ${(_image!.bytes.length / 1024).toStringAsFixed(0)} KB',
                        style: const TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('photo-date'),
                      controller: _date,
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                      keyboardType: TextInputType.datetime,
                      decoration: _warmPhotoInputDecoration(
                        'Ngày chụp (dd/MM/yyyy HH:mm)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _pose,
                      dropdownColor: const Color(0xFF2B2622),
                      style: const TextStyle(color: MetaGymTheme.textPrimary),
                      decoration: _warmPhotoInputDecoration('Góc chụp'),
                      items: const [
                        DropdownMenuItem(
                          value: 'FRONT',
                          child: Text('Mặt trước'),
                        ),
                        DropdownMenuItem(value: 'SIDE', child: Text('Mặt bên')),
                        DropdownMenuItem(value: 'BACK', child: Text('Mặt sau')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
                      ],
                      onChanged: (value) => setState(() => _pose = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLength: 5000,
                      maxLines: 3,
                      style: const TextStyle(color: MetaGymTheme.textPrimary),
                      decoration: _warmPhotoInputDecoration('Ghi chú'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF24161A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF642B32)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFFB2B6)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: MetaGymTheme.brandOrange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            MetaGymTheme.radiusInput,
                          ),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Đang tải lên…' : 'Lưu ảnh',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBodyBehindAppBar: true,
      appBar: _buildPhotoAppBar(context, 'Xem ảnh tiến trình'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            padding: EdgeInsets.fromLTRB(16, topInset, 16, 32),
            children: [
              MetaGymGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${widget.photo.poseLabel} · ${formatProgressTime(widget.photo.takenAt)}',
                      style: const TextStyle(
                        color: MetaGymTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.photo.notes?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.photo.notes!,
                        style: const TextStyle(
                          color: Color(0xFFC8C2BC),
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.brandOrange,
                          ),
                        ),
                      ),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF24161A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF642B32)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Color(0xFFFFB2B6)),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: MetaGymTheme.brandOrange,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: _load,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_url case final url?) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          url.toString(),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Column(
                            children: [
                              const Text(
                                'Ảnh lỗi hoặc URL đã hết hạn.',
                                style: TextStyle(color: Color(0xFFC8C2BC)),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: MetaGymTheme.brandOrange,
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: _load,
                                child: const Text('Tải lại ảnh'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
