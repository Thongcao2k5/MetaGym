import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/progress/data/coach_progress_service.dart';

void main() {
  test(
    'filters Coach comments by member ID with API query parameters',
    () async {
      final adapter = _CommentsAdapter();
      final service = CoachProgressApi(
        ApiClient.withAdapter(
          config: ApiConfig.fromValues(environment: 'local'),
          adapter: adapter,
        ),
      );
      expect(await service.getComments('member-1'), isEmpty);
      expect(adapter.request?.path, '/progress-comments');
      expect(adapter.request?.queryParameters['memberId'], 'member-1');
    },
  );
}

class _CommentsAdapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({'data': []}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
