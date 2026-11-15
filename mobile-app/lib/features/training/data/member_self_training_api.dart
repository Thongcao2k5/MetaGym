import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/training/domain/member_self_training_day.dart';

class MemberSelfTrainingApi {
  const MemberSelfTrainingApi(this.client);

  final ApiClient client;

  Future<List<MemberSelfTrainingDay>> getRange(String from, String to) async =>
      (await client.get<List<MemberSelfTrainingDay>>(
        '/member/self-training-days',
        queryParameters: {'from': from, 'to': to},
        decode: (value) =>
            (value as List).map(MemberSelfTrainingDay.fromJson).toList(),
      )).data;

  Future<MemberSelfTrainingDay> save({
    required String day,
    required String title,
    required String? startTime,
    required String notes,
    required List<String> exerciseIds,
  }) async => (await client.put<MemberSelfTrainingDay>(
    '/member/self-training-days/$day',
    body: {
      'title': title,
      'startTime': startTime,
      'notes': notes,
      'exerciseIds': exerciseIds,
    },
    decode: MemberSelfTrainingDay.fromJson,
  )).data;

  Future<void> delete(String day) async {
    await client.delete<Map<String, dynamic>>(
      '/member/self-training-days/$day',
      decode: (value) => Map<String, dynamic>.from(value as Map),
    );
  }
}
