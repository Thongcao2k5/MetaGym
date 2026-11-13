import 'package:meta_gym_app/core/network/api_client.dart';

typedef CoachRecord = Map<String, dynamic>;

class CoachV2Api {
  const CoachV2Api(this.client);
  final ApiClient client;

  static CoachRecord _record(Object? data) => CoachRecord.from(data as Map);

  Future<List<CoachRecord>> list(
    String path, {
    Map<String, dynamic>? query,
  }) async => (await client.get(
    path,
    queryParameters: query,
    decode: (data) => (data as List).map(_record).toList(),
  )).data;

  Future<CoachRecord> get(String path) async =>
      (await client.get(path, decode: _record)).data;

  Future<CoachRecord> post(String path, {Object? body, String? key}) async =>
      (await client.post(
        path,
        body: body,
        decode: _record,
        headers: key == null ? null : {'Idempotency-Key': key},
      )).data;

  Future<void> patch(String path, Object body) async {
    await client.patch(path, body: body, decode: _record);
  }

  Future<void> put(String path, Object body) async {
    await client.put(path, body: body, decode: _record);
  }
}
