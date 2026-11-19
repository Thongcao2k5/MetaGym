import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_messages_page.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';
import 'package:provider/provider.dart';

class AiConversationsPage extends StatefulWidget {
  const AiConversationsPage({
    this.service,
    this.bottomPadding,
    this.coachMode,
    super.key,
  });

  final AiService? service;
  final double? bottomPadding;
  final bool? coachMode;

  @override
  State<AiConversationsPage> createState() => _AiConversationsPageState();
}

class _AiConversationsPageState extends State<AiConversationsPage> {
  AiService? _service;
  List<AiConversation> _items = const [];
  bool _loading = true;
  bool _saving = false;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_service != null) return;
    _service = widget.service ?? context.read<AiService>();
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
      final items = await _service!.getConversations(1);
      if (mounted) {
        setState(() {
          _items = items;
          _page = 1;
          _hasMore = items.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hội thoại AI.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final items = await _service!.getConversations(_page + 1);
      if (mounted) {
        setState(() {
          _items = [..._items, ...items];
          _page++;
          _hasMore = items.length == 20;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải thêm được hội thoại AI.');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await _service!.create();
      if (mounted) setState(() => _items = [created, ..._items]);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tạo được hội thoại AI.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename(AiConversation item) async {
    final form = GlobalKey<FormState>();
    var title = item.title;
    final newTitle = await showDialog<String>(
      context: context,
      barrierColor: const Color(0xB8040609),
      builder: (context) => AlertDialog(
        backgroundColor: coachingWarmOverlaySurface,
        surfaceTintColor: Colors.transparent,
        shape: coachingDialogShape,
        title: const Text(
          'Đổi tên hội thoại',
          style: TextStyle(
            color: coachingWarmTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: title,
            maxLength: 150,
            style: const TextStyle(color: coachingWarmTextPrimary),
            decoration: coachingInputDecoration(label: 'Tên hội thoại'),
            onChanged: (value) => title = value,
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'Nhập tên hội thoại.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: coachingWarmTextSecondary,
              minimumSize: const Size(48, 44),
            ),
            child: const Text('Hủy'),
          ),
          CoachingCompactAccentButton(
            label: 'Lưu',
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, title.trim());
              }
            },
          ),
        ],
      ),
    );
    if (newTitle == null || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await _service!.rename(item.id, newTitle);
      if (mounted) {
        setState(
          () => _items = [
            for (final existing in _items)
              existing.id == item.id ? updated : existing,
          ],
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không đổi tên được hội thoại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(AiConversation item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB8040609),
      builder: (context) => AlertDialog(
        backgroundColor: coachingWarmOverlaySurface,
        surfaceTintColor: Colors.transparent,
        shape: coachingDialogShape,
        title: const Text(
          'Xóa hội thoại AI?',
          style: TextStyle(
            color: coachingWarmTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Hội thoại “${item.title}” sẽ không còn trong danh sách.',
          style: const TextStyle(
            color: coachingWarmTextSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: coachingWarmTextSecondary,
              minimumSize: const Size(48, 44),
            ),
            child: const Text('Hủy'),
          ),
          CoachingCompactAccentButton(
            label: 'Xóa',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service!.delete(item.id);
      if (mounted) {
        setState(
          () => _items = [
            for (final existing in _items)
              if (existing.id != item.id) existing,
          ],
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không xóa được hội thoại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _resolveCoachHeader(BuildContext context) {
    if (widget.coachMode != null) return widget.coachMode!;
    try {
      return context.watch<SessionController?>()?.user?.role == UserRole.coach;
    } on ProviderNotFoundException {
      return false;
    }
  }

  List<Widget> _buildBodyChildren() {
    return [
      CoachingPrimaryButton(
        label: _saving ? 'Đang xử lý…' : 'Tạo hội thoại',
        icon: Icons.auto_awesome_rounded,
        loading: _saving,
        onPressed: _saving ? null : _create,
      ),
      const SizedBox(height: 14),
      if (_error != null) ...[
        CoachingErrorBanner(message: _error!),
        CoachingSecondaryButton(
          label: 'Thử lại',
          expand: true,
          onPressed: _items.isEmpty ? _load : _loadMore,
        ),
        const SizedBox(height: 12),
      ],
      if (_items.isEmpty && _error == null)
        MetaGymGlassCard(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: coachingWarmNestedSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: coachingWarmInputBorder),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: MetaGymTheme.brandOrange,
                  size: 22,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Bạn chưa có hội thoại AI nào.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: coachingWarmTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Nhấn “Tạo hội thoại” bên trên để bắt đầu hỏi đáp cùng trợ lý AI của Meta Gym.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: coachingWarmTextSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      for (final item in _items)
        MetaGymGlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  AiMessagesPage(service: _service!, conversation: item),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: coachingWarmNestedSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: coachingWarmInputBorder),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: MetaGymTheme.reflectionBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: coachingWarmTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.updatedAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: coachingWarmTextSecondary,
                        fontSize: 12,
                        fontFeatures: MetaGymTheme.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Đổi tên',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: coachingWarmTextSecondary,
                  size: 20,
                ),
                onPressed: _saving ? null : () => _rename(item),
              ),
              IconButton(
                tooltip: 'Xóa hội thoại',
                icon: const Icon(
                  Icons.delete_outline,
                  color: coachingWarmTextSecondary,
                  size: 20,
                ),
                onPressed: _saving ? null : () => _delete(item),
              ),
            ],
          ),
        ),
      if (_hasMore)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: CoachingSecondaryButton(
            label: _loadingMore ? 'Đang tải…' : 'Tải thêm',
            expand: true,
            onPressed: _loadingMore ? null : _loadMore,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.paddingOf(context);
    final canPop = Navigator.of(context).canPop();
    final bottomInset = (widget.bottomPadding ?? 100.0) + 16.0;
    final useCoachHeader = _resolveCoachHeader(context);

    if (useCoachHeader) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Material(
          color: MetaGymTheme.darkCanvas,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const MetaGymBackground(),
              SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  color: MetaGymTheme.brandOrange,
                  backgroundColor: coachingWarmOverlaySurface,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      MetaGymTheme.pageGutter,
                      0,
                      MetaGymTheme.pageGutter,
                      bottomInset,
                    ),
                    children: [
                      const SizedBox(height: 6),
                      MetaGymBrandHeader(
                        eyebrow: 'META GYM · COACH',
                        title: 'Trợ lý AI',
                        subtitle: 'Hỏi đáp giáo trình, dinh dưỡng & lịch tập',
                        leading: canPop
                            ? MetaGymCircleIconButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                tooltip: 'Quay lại',
                                onTap: () => Navigator.of(context).maybePop(),
                              )
                            : null,
                        actions: [
                          MetaGymCircleIconButton(
                            icon: Icons.refresh_rounded,
                            tooltip: 'Tải lại',
                            onTap: _loading ? null : _load,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 64),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: MetaGymTheme.brandOrange,
                            ),
                          ),
                        )
                      else
                        ..._buildBodyChildren(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MetaGymTheme.scaffoldBackground,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 72,
          leading: canPop
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MetaGymCircleIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Back',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                )
              : null,
          titleSpacing: canPop ? 8 : 16,
          title: const Text(
            'Trợ lý AI',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: coachingWarmTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 19,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: MetaGymCircleIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Tải lại',
                  onTap: _loading ? null : _load,
                ),
              ),
            ),
          ],
          backgroundColor: Colors.transparent,
          foregroundColor: coachingWarmTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaGymTheme.brandOrange,
                    ),
                  )
                : RefreshIndicator(
                    color: MetaGymTheme.brandOrange,
                    backgroundColor: coachingWarmOverlaySurface,
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        media.top + kToolbarHeight + 12,
                        16,
                        bottomInset,
                      ),
                      children: _buildBodyChildren(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
