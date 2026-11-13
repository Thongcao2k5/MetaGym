import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_messages_page.dart';
import 'package:provider/provider.dart';

class AiConversationsPage extends StatefulWidget {
  const AiConversationsPage({this.service, this.bottomPadding, super.key});
  final AiService? service;
  final double? bottomPadding;
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
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên hội thoại'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: title,
            maxLength: 150,
            decoration: const InputDecoration(labelText: 'Tên hội thoại'),
            onChanged: (value) => title = value,
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? 'Nhập tên hội thoại.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, title.trim());
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
      builder: (context) => AlertDialog(
        title: const Text('Xóa hội thoại AI?'),
        content: Text(
          'Hội thoại “${item.title}” sẽ không còn trong danh sách.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = (widget.bottomPadding ?? 100.0) + 16.0;

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Trợ lý AI',
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            fontFamily: MetaGymTheme.fontFamily,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: MetaGymTheme.primary),
            )
          : RefreshIndicator(
              color: MetaGymTheme.primary,
              backgroundColor: MetaGymTheme.cardSurface,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.primary,
                      foregroundColor: Colors.white,
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
                        color: const Color(0x1FF15B64),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x4DF15B64)),
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
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _items.isEmpty ? _load : _loadMore,
                            child: const Text(
                              'Thử lại',
                              style: TextStyle(color: MetaGymTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_items.isEmpty && _error == null)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: MetaGymTheme.cardSurface,
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusCard,
                        ),
                        border: Border.all(color: MetaGymTheme.cardBorder),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: MetaGymTheme.elevatedSurface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: MetaGymTheme.cardBorder,
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: MetaGymTheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Bạn chưa có hội thoại AI nào.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: MetaGymTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Nhấn “Tạo hội thoại” bên trên để bắt đầu hỏi đáp cùng trợ lý AI của Meta Gym.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: MetaGymTheme.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  for (final item in _items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: MetaGymTheme.cardSurface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: MetaGymTheme.cardBorder),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: MetaGymTheme.elevatedSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: MetaGymTheme.cardBorder),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: MetaGymTheme.reflectionBlue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(
                            color: MetaGymTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          item.updatedAt,
                          style: const TextStyle(
                            color: MetaGymTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
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
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: MetaGymTheme.textSecondary,
                                size: 20,
                              ),
                              onPressed: _saving ? null : () => _rename(item),
                            ),
                            IconButton(
                              tooltip: 'Xóa hội thoại',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: MetaGymTheme.textSecondary,
                                size: 20,
                              ),
                              onPressed: _saving ? null : () => _delete(item),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_hasMore)
                    TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(
                        _loadingMore ? 'Đang tải…' : 'Tải thêm',
                        style: const TextStyle(color: MetaGymTheme.primary),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
