import 'package:meta_gym_app/core/network/api_client.dart';

import 'flow_action.dart';

abstract class FlowService {
  Future<ApiResult<Object?>> run(
    FlowAction action,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  });
}

class ApiFlowService implements FlowService {
  const ApiFlowService(this.client);

  final ApiClient client;

  @override
  Future<ApiResult<Object?>> run(
    FlowAction action,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => switch (action.method) {
    'GET' => client.get<Object?>(
      path,
      decode: (data) => data,
      queryParameters: query,
    ),
    'POST' => client.post<Object?>(
      path,
      decode: (data) => data,
      body: body,
      queryParameters: query,
    ),
    'PATCH' => client.patch<Object?>(
      path,
      decode: (data) => data,
      body: body,
      queryParameters: query,
    ),
    'DELETE' => client.delete<Object?>(
      path,
      decode: (data) => data,
      body: body,
      queryParameters: query,
    ),
    _ => throw UnsupportedError('Phương thức ${action.method} không hỗ trợ.'),
  };
}
