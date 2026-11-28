import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';

import 'flow_action.dart';
import 'flow_service.dart';

class FlowActionPage extends StatefulWidget {
  const FlowActionPage({
    required this.action,
    required this.service,
    super.key,
  });

  final FlowAction action;
  final FlowService service;

  @override
  State<FlowActionPage> createState() => _FlowActionPageState();
}

class _FlowActionPageState extends State<FlowActionPage> {
  late final Map<String, TextEditingController> _ids = {
    for (final name in widget.action.pathParameters)
      name: TextEditingController(),
  };
  late final _query = TextEditingController(
    text: widget.action.sampleQuery ?? '{}',
  );
  late final _body = TextEditingController(
    text: (widget.action.sampleBody ?? '{}')
        .replaceFirst(
          '"clientMessageId":""',
          '"clientMessageId":"${_newUuid()}"',
        )
        .replaceFirst(
          '"clientRequestId":""',
          '"clientRequestId":"${_newUuid()}"',
        ),
  );
  bool _loading = false;
  String? _error;
  String? _response;
  bool _empty = false;

  @override
  void dispose() {
    for (final controller in _ids.values) {
      controller.dispose();
    }
    _query.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (widget.action.method == 'DELETE') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: const Text('Thao tác này thay đổi dữ liệu trên máy chủ.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _response = null;
      _empty = false;
    });
    try {
      final path = widget.action.resolvePath(
        _ids.map((key, value) => MapEntry(key, value.text)),
      );
      final query = _parseMap(_query.text, 'Tham số truy vấn');
      final body = widget.action.method == 'GET'
          ? null
          : _parseMap(_body.text, 'Dữ liệu gửi');
      final result = await widget.service.run(
        widget.action,
        path,
        body: body,
        query: query.isEmpty ? null : query,
      );
      if (!mounted) return;
      final content = <String, Object?>{'data': result.data};
      if (result.pagination != null) content['pagination'] = result.pagination;
      setState(() {
        _response = const JsonEncoder.withIndent('  ').convert(content);
        _empty =
            result.data == null ||
            (result.data is List && (result.data as List).isEmpty);
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${error.message}'
              '${error.code == null ? '' : ' (${error.code})'}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể xử lý phản hồi. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _parseMap(String value, String label) {
    final parsed = jsonDecode(value);
    if (parsed is! Map<String, dynamic>) {
      throw FormatException('$label phải là đối tượng JSON.');
    }
    return parsed;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.action.title)),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: MetaGymBackground()),
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
        SelectableText('${widget.action.method} ${widget.action.path}'),
        const SizedBox(height: 16),
        for (final entry in _ids.entries) ...[
          TextField(
            key: Key('flow-id-${entry.key}'),
            controller: entry.value,
            decoration: InputDecoration(
              labelText: entry.key,
              hintText: 'Dán mã ${entry.key} từ kết quả bước trước',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          key: const Key('flow-query'),
          controller: _query,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Tham số truy vấn (JSON)',
            border: OutlineInputBorder(),
          ),
        ),
        if (widget.action.method != 'GET') ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('flow-body'),
            controller: _body,
            minLines: 4,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Dữ liệu gửi (JSON)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('flow-run'),
          onPressed: _loading ? null : _run,
          child: Text(_loading ? 'Đang xử lý…' : 'Thực hiện'),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _error!,
              key: const Key('flow-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_response != null) ...[
          const SizedBox(height: 20),
          Text('Kết quả', style: Theme.of(context).textTheme.titleMedium),
          if (_empty) const Text('Chưa có dữ liệu.'),
          SelectableText(_response!, key: const Key('flow-response')),
        ],
          ],
        ),
      ],
    ),
  );
}

String _newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final value = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}
