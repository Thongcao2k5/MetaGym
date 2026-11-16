import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/coaching/domain/coach_outcome_models.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';

class CoachOutcomeApi {
  const CoachOutcomeApi(this.client);

  final ApiClient client;

  Future<List<CoachOutcomeCase>> getPublicOutcomes(String coachId) async =>
      (await client.get<List<CoachOutcomeCase>>(
        '/coaches/${Uri.encodeComponent(coachId)}/outcomes',
        decode: (value) =>
            (value as List).map(CoachOutcomeCase.fromJson).toList(),
      )).data;

  Future<List<CoachOutcomeCase>> getCoachMemberOutcomes(
    String memberId,
  ) async => (await client.get<List<CoachOutcomeCase>>(
    '/coach/members/${Uri.encodeComponent(memberId)}/outcomes',
    decode: (value) => (value as List).map(CoachOutcomeCase.fromJson).toList(),
  )).data;

  Future<String> uploadOutcomePhoto(SelectedProgressImage image) async {
    final validation = validateProgressImage(image);
    if (validation != null) throw FormatException(validation);
    final response = await client.post<Map<String, dynamic>>(
      '/media/images',
      body: image.bytes,
      headers: {
        'content-type': image.mimeType,
        'x-image-purpose': 'COACH_OUTCOME',
        'x-file-name': image.name,
      },
      decode: (value) => Map<String, dynamic>.from(value as Map),
    );
    return response.data['id'] as String;
  }

  Future<CoachOutcomeCase> submitOutcome(
    String memberId, {
    required String goal,
    required int durationWeeks,
    required double beforeWeightKg,
    required double afterWeightKg,
    double? beforeBodyFatPercent,
    double? afterBodyFatPercent,
    String? beforeMediaId,
    String? afterMediaId,
  }) async => (await client.post<CoachOutcomeCase>(
    '/coach/members/${Uri.encodeComponent(memberId)}/outcomes',
    body: {
      'goal': goal,
      'durationWeeks': durationWeeks,
      'beforeWeightKg': beforeWeightKg,
      'afterWeightKg': afterWeightKg,
      'beforeBodyFatPercent': beforeBodyFatPercent,
      'afterBodyFatPercent': afterBodyFatPercent,
      'beforeMediaId': beforeMediaId,
      'afterMediaId': afterMediaId,
    },
    decode: CoachOutcomeCase.fromJson,
  )).data;

  Future<void> deleteCoachOutcome(String outcomeId) async {
    await client.delete<Map<String, dynamic>>(
      '/coach/outcomes/${Uri.encodeComponent(outcomeId)}',
      decode: (value) => Map<String, dynamic>.from(value as Map),
    );
  }

  Future<List<CoachOutcomeCase>> getMemberOutcomes() async =>
      (await client.get<List<CoachOutcomeCase>>(
        '/member/coach-outcomes',
        decode: (value) =>
            (value as List).map(CoachOutcomeCase.fromJson).toList(),
      )).data;

  Future<CoachOutcomeCase> updateMemberConsent(
    String outcomeId, {
    String? decision,
    bool? allowRealName,
    bool removePhotos = false,
  }) async => (await client.patch<CoachOutcomeCase>(
    '/member/coach-outcomes/${Uri.encodeComponent(outcomeId)}',
    body: {
      'decision': ?decision,
      'allowRealName': ?allowRealName,
      if (removePhotos) 'removePhotos': true,
    },
    decode: CoachOutcomeCase.fromJson,
  )).data;
}
