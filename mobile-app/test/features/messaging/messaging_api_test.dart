import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';

void main() {
  test(
    'sends a text message with the same client ID supplied by the UI',
    () async {
      final adapter = _MessagingAdapter();
      final api = MessagingApi(
        ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        ),
      );
      final id = newClientMessageId();
      final message = await api.sendText('relationship-1', 'Xin chào', id);
      expect(message.content, 'Xin chào');
      expect(adapter.request?.method, 'POST');
      expect(adapter.request?.path, '/conversations/relationship-1/messages');
      expect(adapter.payload, {
        'messageType': 'TEXT',
        'clientMessageId': id,
        'content': 'Xin chào',
      });
      await api.markRead('relationship-1', 'received-1');
      expect(adapter.request?.method, 'PATCH');
      expect(adapter.request?.path, '/conversations/relationship-1/read-state');
      expect(adapter.payload, {'messageId': 'received-1'});
    },
  );
}

class _MessagingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  Map<String, dynamic>? payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    payload = Map<String, dynamic>.from(
      jsonDecode(
        utf8.decode(
          (await requestStream!.toList()).expand((chunk) => chunk).toList(),
        ),
      ) as Map,
    );
    return ResponseBody.fromString(
      jsonEncode({
        'data': options.method == 'PATCH'
            ? {
                'lastReadMessageId': 'received-1',
                'lastReadAt': '2026-10-23T08:00:00Z',
              }
            : {
                'id': 'message-1',
                'senderId': 'member-1',
                'messageType': 'TEXT',
                'content': 'Xin chào',
                'sentAt': '2026-10-23T08:00:00Z',
              },
      }),
      options.method == 'PATCH' ? 200 : 201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
