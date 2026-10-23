import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';

abstract interface class MemberMeasurementService {
  Future<List<BodyMeasurement>> getPage(int page);
  Future<BodyMeasurement> create(Map<String, Object?> payload);
  Future<BodyMeasurement> update(String id, Map<String, Object?> payload);
}

class MemberMeasurementApi implements MemberMeasurementService {
  const MemberMeasurementApi(this.client);
  final ApiClient client;
  @override
  Future<List<BodyMeasurement>> getPage(int page) async =>
      (await client.get<List<BodyMeasurement>>(
        '/body-measurements',
        queryParameters: {'page': page, 'pageSize': 20},
        decode: (value) =>
            (value as List).map(BodyMeasurement.fromJson).toList(),
      )).data;
  @override
  Future<BodyMeasurement> create(Map<String, Object?> payload) async =>
      (await client.post<BodyMeasurement>(
        '/body-measurements',
        body: payload,
        decode: BodyMeasurement.fromJson,
      )).data;
  @override
  Future<BodyMeasurement> update(
    String id,
    Map<String, Object?> payload,
  ) async => (await client.patch<BodyMeasurement>(
    '/body-measurements/${Uri.encodeComponent(id)}',
    body: payload,
    decode: BodyMeasurement.fromJson,
  )).data;
}
