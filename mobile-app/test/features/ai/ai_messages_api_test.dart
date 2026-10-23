import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/ai/domain/ai_message.dart';

void main() {
  test('AI answer rejects a completed response without a reply', () {
    expect(
      () => AiAnswerResult.fromJson({
        'requestId': 'request-1',
        'status': 'COMPLETED',
        'reply': null,
      }),
      throwsFormatException,
    );
  });

  test('sends a stable request ID and treats HTTP 202 as processing', () async {
    final adapter = _AiAdapter();
    final api = AiApi(
      ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      ),
    );
    final result = await api.sendQuestion('ai-1', 'Tôi nên tập gì?', 'uuid-1');
    expect(adapter.path, '/ai-conversations/ai-1/messages');
    expect(adapter.body, {
      'content': 'Tôi nên tập gì?',
      'clientRequestId': 'uuid-1',
    });
    expect(result.isComplete, isFalse);
    expect(result.reply, isNull);
  });
}

class _AiAdapter implements HttpClientAdapter {
  String? path;
  Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    body = Map<String, dynamic>.from(
      jsonDecode(
        utf8.decode(
          (await requestStream!.toList()).expand((chunk) => chunk).toList(),
        ),
      ) as Map,
    );
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'requestId': 'request-1',
          'status': 'PROCESSING',
          'reply': null,
        },
      }),
      202,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
