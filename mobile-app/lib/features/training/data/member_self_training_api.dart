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

  Future<MemberSelfTrainingDay> createSession({
    required String day,
    required String title,
    required String? startTime,
    required String notes,
    required List<SelfTrainingExercise> exercises,
  }) async => (await client.post<MemberSelfTrainingDay>(
    '/member/self-training-days',
    body: {
      'planDate': day,
      'title': title,
      'startTime': startTime,
      'notes': notes,
      'exercises': exercises.map((item) => item.toJson()).toList(),
    },
    decode: MemberSelfTrainingDay.fromJson,
  )).data;

  Future<MemberSelfTrainingDay> updateSession({
    required String id,
    required String title,
    required String? startTime,
    required String notes,
    required List<SelfTrainingExercise> exercises,
  }) async => (await client.put<MemberSelfTrainingDay>(
    '/member/self-training-days/sessions/$id',
    body: {
      'title': title,
      'startTime': startTime,
      'notes': notes,
      'exercises': exercises.map((item) => item.toJson()).toList(),
    },
    decode: MemberSelfTrainingDay.fromJson,
  )).data;

  Future<void> deleteSession(String id) async {
    await client.delete<Map<String, dynamic>>(
      '/member/self-training-days/sessions/$id',
      decode: (value) => Map<String, dynamic>.from(value as Map),
    );
  }

  Future<MemberSelfTrainingDay> save({
    required String day,
    required String title,
    required String? startTime,
    required String notes,
    required List<SelfTrainingExercise> exercises,
  }) async => (await client.put<MemberSelfTrainingDay>(
    '/member/self-training-days/$day',
    body: {
      'title': title,
      'startTime': startTime,
      'notes': notes,
      'exercises': exercises.map((item) => item.toJson()).toList(),
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
