import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_conversation.dart';
import 'package:provider/provider.dart';

class AiConversationsPage extends StatefulWidget {
  const AiConversationsPage({this.service, super.key});
  final AiService? service;
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trợ lý AI')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton(
                  onPressed: _saving ? null : _create,
                  child: Text(_saving ? 'Đang xử lý…' : 'Tạo hội thoại'),
                ),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: _items.isEmpty ? _load : _loadMore,
                    child: const Text('Thử lại'),
                  ),
                ],
                if (_items.isEmpty && _error == null)
                  const ListTile(title: Text('Bạn chưa có hội thoại AI nào.')),
                for (final item in _items)
                  Card(
                    child: ListTile(
                      title: Text(item.title),
                      subtitle: Text(item.updatedAt),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: Text(item.title)),
                            body: const Center(
                              child: Text('Hỏi đáp AI sẽ có ở UI27.'),
                            ),
                          ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Đổi tên',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _saving ? null : () => _rename(item),
                          ),
                          IconButton(
                            tooltip: 'Xóa hội thoại',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _saving ? null : () => _delete(item),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_hasMore)
                  TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: Text(_loadingMore ? 'Đang tải…' : 'Tải thêm'),
                  ),
              ],
            ),
          ),
  );
}
