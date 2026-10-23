import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';

void main() {
  test('uploads raw image bytes for MESSAGE and resolves signed URL', () async {
    final adapter = _ImageAdapter();
    final api = MessagingApi(
      ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      ),
    );
    final image = SelectedProgressImage(
      name: 'chat.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    expect(await api.uploadImage(image), 'media-1');
    expect(adapter.uploadRequest?.headers['x-image-purpose'], 'MESSAGE');
    expect(adapter.uploadRequest?.headers['content-type'], 'image/png');
    expect(adapter.bytes, image.bytes);
    final sent = await api.sendImage(
      'relationship-1',
      'media-1',
      newClientMessageId(),
    );
    expect(sent.mediaId, 'media-1');
    expect(adapter.messagePayload?['messageType'], 'IMAGE');
    expect(adapter.messagePayload?['mediaId'], 'media-1');
    final url = await api.getImageAccessUrl('media-1');
    expect(url.host, '127.0.0.1');
    expect(url.path, '/api/v1/media/images/media-1');
  });

  test('rejects invalid image before upload', () async {
    final adapter = _ImageAdapter();
    final api = MessagingApi(
      ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      ),
    );
    final invalid = SelectedProgressImage(
      name: 'bad.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    await expectLater(api.uploadImage(invalid), throwsFormatException);
    expect(adapter.uploadRequest, isNull);
  });
}

class _ImageAdapter implements HttpClientAdapter {
  RequestOptions? uploadRequest;
  List<int>? bytes;
  Map<String, dynamic>? messagePayload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = (await requestStream?.toList() ?? <Uint8List>[])
        .expand((chunk) => chunk)
        .toList();
    Map<String, dynamic> data;
    var status = 200;
    if (options.path == '/media/images') {
      uploadRequest = options;
      bytes = body;
      data = {'id': 'media-1'};
      status = 201;
    } else if (options.path.endsWith('/messages')) {
      messagePayload = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(body)) as Map,
      );
      data = {
        'id': 'message-1',
        'senderId': 'member-1',
        'messageType': 'IMAGE',
        'mediaId': 'media-1',
        'sentAt': '2026-10-23T08:00:00Z',
      };
      status = 201;
    } else {
      data = {'url': '/api/v1/media/images/media-1?expires=1&signature=abc'};
    }
    return ResponseBody.fromString(
      jsonEncode({'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
