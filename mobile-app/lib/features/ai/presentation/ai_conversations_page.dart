import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_messages_page.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/presentation/coaching_ui.dart';

/// Màn hình Trợ lý AI:
/// - **Coach (`coachMode: true`)**: Mở trực tiếp trải nghiệm **4.1 Trợ lý AI Coach**
///   (Meta Kong + chat + nút `+` tạo mới + bấm tiêu đề để đổi/sửa/xóa hội thoại).
/// - **Member**: Hiển thị danh sách hội thoại AI + CRUD & mở `AiMessagesPage`.
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
  AiConversation? _activeConversation;
  bool _loading = true;
  bool _saving = false;
  bool _loadingMore = false;
  int _page = 1;
  bool _hasMore = false;
  String? _error;

  bool _resolveCoachHeader(BuildContext context) {
    if (widget.coachMode != null) return widget.coachMode!;
    return optionalProvider<SessionController>(context)?.user?.role ==
        UserRole.coach;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextService = widget.service ?? optionalProvider<AiService>(context);
    if (!identical(_service, nextService)) {
      _service = nextService;
      if (_service != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load();
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Chưa kết nối dịch vụ AI.';
        });
      }
    }
  }

  Future<void> _load() async {
    final service = _service;
    if (service == null) return;
    final isCoach = _resolveCoachHeader(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var items = await service.getConversations(1);
      if (isCoach && items.isEmpty) {
        final created = await service.create();
        items = [created];
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _page = 1;
        _hasMore = items.length == 20;
        if (items.isEmpty) {
          _activeConversation = null;
        } else if (_activeConversation == null ||
            !items.any((c) => c.id == _activeConversation!.id)) {
          _activeConversation = items.first;
        } else {
          _activeConversation = items.firstWhere(
            (c) => c.id == _activeConversation!.id,
          );
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được hội thoại AI.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_service == null || _loadingMore) return;
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
    if (_saving || _service == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await _service!.create();
      if (mounted) {
        setState(() {
          _items = [created, ..._items];
          _activeConversation = created;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tạo được hội thoại AI.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename(AiConversation item) async {
    if (_saving || _service == null) return;
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final form = GlobalKey<FormState>();
    var title = item.title;
    final newTitle = await MetaGymNavigation.showDialogOnce<String>(
      context: context,
      barrierColor: colors.scrim,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isLight ? colors.surface : colors.overlayGlass,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
          side: BorderSide(color: colors.overlayGlassBorder, width: 1.1),
        ),
        title: Text(
          'Đổi tên hội thoại',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: title,
            maxLength: 150,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Tên hội thoại',
              labelStyle: TextStyle(color: colors.textWarmMuted),
              filled: true,
              fillColor: colors.metricPanelBg,
              counterStyle: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                borderSide: BorderSide(color: colors.metricPanelBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                borderSide: BorderSide(color: colors.metricPanelBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                borderSide: const BorderSide(
                  color: MetaGymTheme.primary,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (value) => title = value,
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'Nhập tên hội thoại.' : null,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.textSecondary,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.primary,
              foregroundColor: MetaGymTheme.onPrimary,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              ),
            ),
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, title.trim());
              }
            },
            child: const Text('Lưu'),
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
        setState(() {
          _items = [
            for (final existing in _items)
              existing.id == item.id ? updated : existing,
          ];
          if (_activeConversation?.id == item.id) {
            _activeConversation = updated;
          }
        });
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
    if (_saving || _service == null) return;
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final confirmed = await MetaGymNavigation.showDialogOnce<bool>(
      context: context,
      barrierColor: colors.scrim,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isLight ? colors.surface : colors.overlayGlass,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
          side: BorderSide(color: colors.overlayGlassBorder, width: 1.1),
        ),
        title: Text(
          'Xóa hội thoại AI?',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Hội thoại “${item.title}” sẽ không còn trong danh sách.',
          style: TextStyle(color: colors.textWarmMuted, height: 1.45),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.textSecondary,
              minimumSize: const Size(48, 48),
            ),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.dangerCoral,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
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
        setState(() {
          _items = [
            for (final existing in _items)
              if (existing.id != item.id) existing,
          ];
          if (_activeConversation?.id == item.id) {
            _activeConversation = _items.firstOrNull;
          }
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không xóa được hội thoại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCoachThreadsSheet() async {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isLight ? colors.surface : colors.overlayGlass,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hội thoại AI Coach',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      unawaited(_create());
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.primary,
                      foregroundColor: MetaGymTheme.onPrimary,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tạo mới'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in _items)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        leading: Icon(
                          item.id == _activeConversation?.id
                              ? Icons.radio_button_checked_rounded
                              : Icons.chat_bubble_outline_rounded,
                          color: item.id == _activeConversation?.id
                              ? colors.primaryText
                              : colors.textSecondary,
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          setState(() => _activeConversation = item);
                          Navigator.pop(sheetCtx);
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Đổi tên',
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                unawaited(_rename(item));
                              },
                              icon: Icon(
                                Icons.edit_outlined,
                                color: colors.textSecondary,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xóa hội thoại',
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                unawaited(_delete(item));
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: colors.error,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCoachHeader = _resolveCoachHeader(context);
    if (isCoachHeader) {
      return _buildCoachDirectWorkspace(context);
    }
    return _buildMemberConversationsList(context);
  }

  Widget _buildCoachDirectWorkspace(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final active = _activeConversation;

    if (!_loading && active != null && _service != null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: colors.canvas,
          resizeToAvoidBottomInset: true,
          body: AiMessagesView(
            service: _service!,
            conversation: active,
            coachMode: true,
            bottomPadding: widget.bottomPadding,
            creatingConversation: _saving,
            onCreateConversation: _create,
            onOpenHistory: _openCoachThreadsSheet,
          ),
        ),
      );
    }

    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  0,
                  gutter,
                  widget.bottomPadding ?? 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),
                    MetaGymBrandHeader(
                      eyebrow: 'META GYM · COACH',
                      title: 'Trợ lý AI',
                      subtitle: 'Hỏi đáp giáo trình, dinh dưỡng & lịch tập',
                      leading: (ModalRoute.of(context)?.canPop ?? false)
                          ? MetaGymCircleIconButton(
                              svgAsset: MetaGymIcons.commonBack,
                              icon: Icons.arrow_back_ios_new_rounded,
                              tooltip: 'Quay lại',
                              onTap: () => Navigator.of(context).maybePop(),
                            )
                          : null,
                      actions: _service == null
                          ? const []
                          : [
                              MetaGymCircleIconButton(
                                svgAsset: MetaGymIcons.commonAdd,
                                icon: Icons.add_rounded,
                                tooltip: 'Hội thoại AI mới',
                                onTap: _saving ? null : _create,
                              ),
                            ],
                    ),
                    Expanded(
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: MetaGymTheme.primary,
                              ),
                            )
                          : Center(
                              child: MetaGymHeroGlassCard(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_error != null) ...[
                                      Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.error,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      CoachingSecondaryButton(
                                        label: 'Thử lại',
                                        onPressed: _load,
                                        expand: true,
                                      ),
                                    ] else ...[
                                      Text(
                                        'Bắt đầu cùng Meta Kong AI',
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: MetaGymTheme.primary,
                                          foregroundColor:
                                              MetaGymTheme.onPrimary,
                                          minimumSize: const Size(
                                            double.infinity,
                                            48,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        onPressed: _saving ? null : _create,
                                        icon: const Icon(
                                          Icons.auto_awesome_rounded,
                                        ),
                                        label: const Text('Tạo hội thoại'),
                                      ),
                                    ],
                                  ],
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
      ),
    );
  }

  Widget _buildMemberConversationsList(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bottomInset = (widget.bottomPadding ?? 100.0) + 16.0;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final gutter = MediaQuery.sizeOf(context).width >= 600
        ? MetaGymTheme.tabletGutter
        : MetaGymTheme.pageGutter;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const MetaGymBackground(),
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: MetaGymTheme.primary,
                backgroundColor: colors.overlayGlass,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottomInset),
                  children: [
                    const SizedBox(height: 6),
                    MetaGymBrandHeader(
                      eyebrow: 'META GYM',
                      title: 'Trợ lý AI',
                      leading: canPop
                          ? MetaGymCircleIconButton(
                              svgAsset: MetaGymIcons.commonBack,
                              icon: Icons.arrow_back_ios_new_rounded,
                              tooltip: 'Quay lại',
                              onTap: () => Navigator.of(context).maybePop(),
                            )
                          : null,
                      actions: [
                        MetaGymCircleIconButton(
                          svgAsset: MetaGymIcons.commonRefresh,
                          icon: Icons.refresh_rounded,
                          tooltip: 'Tải lại',
                          onTap: _loading ? null : _load,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: MetaGymTheme.primary,
                          ),
                        ),
                      )
                    else ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: MetaGymTheme.primary,
                          foregroundColor: MetaGymTheme.onPrimary,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                        onPressed: _saving ? null : _create,
                        label: Text(_saving ? 'Đang xử lý…' : 'Tạo hội thoại'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.error.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colors.error.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: colors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                onPressed: _items.isEmpty ? _load : _loadMore,
                                child: Text(
                                  'Thử lại',
                                  style: TextStyle(color: colors.primaryText),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_items.isEmpty && _error == null)
                        MetaGymGlassCard(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colors.metricPanelBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.metricPanelBorder,
                                  ),
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: colors.primaryText,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Bạn chưa có hội thoại AI nào.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nhấn “Tạo hội thoại” bên trên để bắt đầu hỏi đáp cùng trợ lý AI của Meta Gym.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.textWarmMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      for (final item in _items)
                        MetaGymGlassCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(
                              14,
                              4,
                              6,
                              4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors.metricPanelBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.metricPanelBorder,
                                ),
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: colors.reflection,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              item.updatedAt,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => MetaGymNavigation.pushOnce<void>(
                              context,
                              MetaGymPageRoute(
                                builder: (_) => AiMessagesPage(
                                  service: _service!,
                                  conversation: item,
                                  coachMode: false,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Đổi tên',
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: colors.textWarmMuted,
                                    size: 20,
                                  ),
                                  onPressed: _saving
                                      ? null
                                      : () => _rename(item),
                                ),
                                IconButton(
                                  tooltip: 'Xóa hội thoại',
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: colors.textWarmMuted,
                                    size: 20,
                                  ),
                                  onPressed: _saving
                                      ? null
                                      : () => _delete(item),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_hasMore)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _loadingMore ? null : _loadMore,
                          child: Text(
                            _loadingMore ? 'Đang tải…' : 'Tải thêm',
                            style: TextStyle(color: colors.primaryText),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
