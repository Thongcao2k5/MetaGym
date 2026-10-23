import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';

void main() {
  test(
    'uploads raw bytes with purpose and resolves a signed URL on the API host',
    () async {
      final adapter = _PhotoAdapter();
      final client = ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
        accessTokenProvider: () => 'token-1',
      );
      final api = MemberPhotoApi(client);
      final image = SelectedProgressImage(
        name: 'progress.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      );
      expect(await api.upload(image), 'media-1');
      expect(adapter.request?.headers['x-image-purpose'], 'PROGRESS_PHOTO');
      expect(adapter.request?.headers['content-type'], 'image/png');
      expect(adapter.request?.headers['authorization'], 'Bearer token-1');
      expect(adapter.uploadBytes, image.bytes);
      final url = await api.getAccessUrl('media-1');
      expect(url.host, '127.0.0.1');
      expect(url.path, '/api/v1/media/images/media-1');
    },
  );
}

class _PhotoAdapter implements HttpClientAdapter {
  RequestOptions? request;
  List<int>? uploadBytes;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (options.path == '/media/images') {
      uploadBytes = (await requestStream!.toList())
          .expand((chunk) => chunk)
          .toList();
      return ResponseBody.fromString(
        jsonEncode({
          'data': {'id': 'media-1'},
        }),
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'url': '/api/v1/media/images/media-1?expires=123&signature=abc',
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
