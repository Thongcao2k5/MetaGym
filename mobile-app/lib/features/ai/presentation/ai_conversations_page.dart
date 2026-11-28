import 'package:meta_gym_app/core/navigation/meta_gym_navigation.dart';
import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_messages_page.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';

String _formatAiTimestamp(String raw) {
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(local.year, local.month, local.day);
  if (target == today) {
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  if (today.difference(target).inDays == 1) {
    return 'Hôm qua';
  }
  final dd = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$dd/$mo';
}

const _aiQuickTopics = <String>[
  'Gợi ý bữa phụ 25g đạm',
  'Chỉnh form Bench Press',
  'Lịch phục hồi vai',
];

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

  Future<void> _create({String? initialPrompt}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await _service!.create();
      if (!mounted) return;
      setState(() => _items = [created, ..._items]);
      if (initialPrompt != null && initialPrompt.trim().isNotEmpty) {
        await Navigator.of(context).push(
          MetaGymPageRoute<void>(
            builder: (_) => AiMessagesPage(
              service: _service!,
              conversation: created,
              initialPrompt: initialPrompt.trim(),
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tạo được hội thoại AI.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename(AiConversation item) async {
    if (_saving) return;
    final form = GlobalKey<FormState>();
    var title = item.title;
    final newTitle = await MetaGymNavigation.showDialogOnce<String>(
      context: context,
      barrierColor: MetaGymTheme.isLightPalette(context)
          ? const Color(0x7511151A)
          : MetaGymTheme.scrim,
      builder: (context) {
        final palette = MetaGymTheme.paletteOf(context);
        final isLight = MetaGymTheme.isLightPalette(context);
        return AlertDialog(
          backgroundColor: isLight
              ? palette.surfaceSolid
              : const Color(0xF0241F1B),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
              width: 1.1,
            ),
          ),
          title: Text(
            'Đổi tên hội thoại',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Form(
            key: form,
            child: TextFormField(
              initialValue: title,
              maxLength: 150,
              style: TextStyle(color: palette.textPrimary),
              decoration: InputDecoration(
                labelText: 'Tên hội thoại',
                labelStyle: TextStyle(color: palette.textWarmMuted),
                filled: true,
                fillColor: palette.metricPanelBg,
                counterStyle: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                  borderSide: BorderSide(color: palette.metricPanelBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                  borderSide: BorderSide(color: palette.metricPanelBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                  borderSide: const BorderSide(
                    color: MetaGymTheme.brandOrange,
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
                foregroundColor: palette.textWarmMuted,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                ),
              ),
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, title.trim());
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
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
    if (_saving) return;
    final confirmed = await MetaGymNavigation.showDialogOnce<bool>(
      context: context,
      barrierColor: MetaGymTheme.isLightPalette(context)
          ? const Color(0x7511151A)
          : MetaGymTheme.scrim,
      builder: (context) {
        final palette = MetaGymTheme.paletteOf(context);
        final isLight = MetaGymTheme.isLightPalette(context);
        return AlertDialog(
          backgroundColor: isLight
              ? palette.surfaceSolid
              : const Color(0xF0241F1B),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isLight ? palette.borderSolid : const Color(0xA3A79D92),
              width: 1.1,
            ),
          ),
          title: Text(
            'Xóa hội thoại AI?',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Hội thoại “${item.title}” sẽ không còn trong danh sách.',
            style: TextStyle(color: palette.textWarmMuted, height: 1.45),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: palette.textWarmMuted,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.error,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
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
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final bottomInset = (widget.bottomPadding ?? 100.0) + 16.0;
    final canPop = Navigator.of(context).canPop();
    final isCoachHeader = _resolveCoachHeader(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: MetaGymTheme.primary,
              backgroundColor: isLight
                  ? palette.surfaceSolid
                  : const Color(0xFF282320),
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
                    eyebrow: isCoachHeader ? 'META GYM · COACH' : 'META GYM',
                    title: 'Trợ lý AI',
                    subtitle: isCoachHeader
                        ? 'Hỏi đáp giáo trình, dinh dưỡng & lịch tập'
                        : 'Meta Kong · Cố vấn tập luyện & dinh dưỡng',
                    inlineSubtitle: !isCoachHeader,
                    leading: canPop
                        ? MetaGymCircleIconButton(
                            svgAsset: MetaGymIcons.commonBack,
                            icon: Icons.arrow_back_rounded,
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
                    _buildCompanionHero(palette, isLight),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isLight
                              ? palette.error.withValues(alpha: 0.10)
                              : const Color(0xD4331E1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: palette.error.withValues(
                              alpha: isLight ? 0.45 : 0.60,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            MetaGymSvgIcon(
                              MetaGymIcons.stateError,
                              size: 20,
                              fallbackIcon: Icons.error_outline_rounded,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: isLight
                                      ? palette.error
                                      : const Color(0xFFFFB2B6),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: _items.isEmpty ? _load : _loadMore,
                              child: Text(
                                'Thử lại',
                                style: TextStyle(color: palette.primaryText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_items.isEmpty && _error == null)
                      MetaGymGlassCard(
                        solid: false,
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/mascot/meta_kong_empty.webp',
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: palette.metricPanelBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.metricPanelBorder,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const MetaGymSvgIcon(
                                  MetaGymIcons.navAiEmblem,
                                  size: 22,
                                  fallbackIcon: Icons.auto_awesome_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Bạn chưa có hội thoại AI nào.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nhấn “Tạo hội thoại” bên trên để bắt đầu hỏi đáp cùng trợ lý AI của Meta Gym.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textWarmMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    for (final item in _items)
                      MetaGymGlassCard(
                        solid: false,
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
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isLight
                                  ? const Color(0xFFFFEBE3)
                                  : const Color(0xFF222834),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: MetaGymTheme.primary.withValues(
                                  alpha: isLight ? 0.42 : 0.48,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const MetaGymSvgIcon(
                              MetaGymIcons.navAiEmblem,
                              size: 20,
                              fallbackIcon: Icons.auto_awesome_rounded,
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            _formatAiTimestamp(item.updatedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                              fontFeatures: MetaGymTheme.tabularFigures,
                            ),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MetaGymPageRoute<void>(
                              builder: (_) => AiMessagesPage(
                                service: _service!,
                                conversation: item,
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
                                icon: const MetaGymSvgIcon(
                                  MetaGymIcons.commonEdit,
                                  size: 20,
                                  fallbackIcon: Icons.edit_outlined,
                                ),
                                onPressed: _saving ? null : () => _rename(item),
                              ),
                              IconButton(
                                tooltip: 'Xóa hội thoại',
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: const MetaGymSvgIcon(
                                  MetaGymIcons.commonDelete,
                                  size: 20,
                                  fallbackIcon: Icons.delete_outline,
                                ),
                                onPressed: _saving ? null : () => _delete(item),
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
                          style: TextStyle(color: palette.primaryText),
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

  Widget _buildCompanionHero(MetaGymPalette palette, bool isLight) {
    return MetaGymHeroGlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/mascot/meta_kong_hero.webp',
                width: 56,
                height: 56,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFFFEBE3)
                        : const Color(0xFF222834),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: MetaGymTheme.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const MetaGymSvgIcon(
                    MetaGymIcons.navAiEmblem,
                    size: 24,
                    fallbackIcon: Icons.auto_awesome_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta Kong · Trợ lý AI Meta Gym',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hỏi đáp bài tập, kỹ thuật & thực đơn cá nhân hóa mỗi ngày.',
                      style: TextStyle(
                        color: palette.textWarmMuted,
                        fontSize: 12,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const MetaGymSvgIcon(
              MetaGymIcons.navAiEmblem,
              size: 20,
              color: Colors.white,
              adaptForLightMode: false,
              fallbackIcon: Icons.auto_awesome_rounded,
            ),
            onPressed: _saving ? null : () => _create(),
            label: Text(
              _saving ? 'Đang xử lý…' : 'Tạo hội thoại',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (idx, topic) in _aiQuickTopics.indexed) ...[
                  if (idx > 0) const SizedBox(width: 8),
                  MetaGymTap(
                    onTap: _saving
                        ? null
                        : () => _create(initialPrompt: topic),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isLight
                            ? palette.surfaceRaised
                            : const Color(0x88241F1B),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isLight
                              ? palette.borderSolid
                              : const Color(0x5CA79D92),
                        ),
                      ),
                      child: Text(
                        topic,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
