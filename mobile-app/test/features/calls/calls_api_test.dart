import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';

void main() {
  test('creates and updates call metadata using backend paths', () async {
    final adapter = _CallsAdapter();
    final api = CallsApi(
      ApiClient.withAdapter(
        config: ApiConfig.fromValues(environment: 'local'),
        adapter: adapter,
      ),
    );
    await api.create('relationship-1', 'VOICE');
    expect(adapter.path, '/calls');
    expect(adapter.body, {
      'relationshipId': 'relationship-1',
      'callType': 'VOICE',
    });
    await api.updateStatus(
      'call-1',
      'FAILED',
      failureReason: 'Ứng dụng chưa tích hợp RTC',
    );
    expect(adapter.path, '/calls/call-1');
    expect(adapter.body, {
      'status': 'FAILED',
      'failureReason': 'Ứng dụng chưa tích hợp RTC',
    });
  });
}

class _CallsAdapter implements HttpClientAdapter {
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
          'id': 'call-1',
          'relationshipId': 'relationship-1',
          'callerId': 'member-1',
          'receiverId': 'coach-1',
          'callType': 'VOICE',
          'status': 'CREATED',
          'initiatedAt': '2026-10-23T08:00:00Z',
          'durationSeconds': 0,
        },
      }),
      options.method == 'POST' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
