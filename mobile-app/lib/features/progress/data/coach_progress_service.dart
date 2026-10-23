import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/progress/data/member_photo_service.dart';
import 'package:meta_gym_app/features/progress/domain/body_measurement.dart';
import 'package:meta_gym_app/features/progress/domain/meal_log.dart';
import 'package:meta_gym_app/features/progress/domain/progress_comment.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';
import 'package:meta_gym_app/features/progress/domain/progress_photo.dart';
import 'package:meta_gym_app/features/progress/domain/workout_log.dart';

abstract interface class CoachProgressService {
  Future<ProgressSummary> getSummary(String memberId);
  Future<List<WorkoutLog>> getWorkouts(String memberId);
  Future<List<MealLog>> getMeals(String memberId);
  Future<List<BodyMeasurement>> getMeasurements(String memberId);
  Future<List<ProgressPhoto>> getPhotos(String memberId);
  Future<List<ProgressComment>> getComments(String memberId);
  Future<ProgressComment> comment(Map<String, Object?> payload);
  Future<Uri> getPhotoAccessUrl(String mediaId);
}

class CoachProgressApi implements CoachProgressService {
  const CoachProgressApi(this.client);
  final ApiClient client;
  String _base(String id) => '/coach/members/${Uri.encodeComponent(id)}';

  Future<List<T>> _list<T>(String path, T Function(dynamic) fromJson) async =>
      (await client.get<List<T>>(
        path,
        queryParameters: {'page': 1, 'pageSize': 100},
        decode: (value) => (value as List).map(fromJson).toList(),
      )).data;

  @override
  Future<ProgressSummary> getSummary(String memberId) async =>
      (await client.get<ProgressSummary>(
        '${_base(memberId)}/progress/summary',
        decode: ProgressSummary.fromJson,
      )).data;
  @override
  Future<List<WorkoutLog>> getWorkouts(String memberId) =>
      _list('${_base(memberId)}/workout-logs', WorkoutLog.fromJson);
  @override
  Future<List<MealLog>> getMeals(String memberId) =>
      _list('${_base(memberId)}/meal-logs', MealLog.fromJson);
  @override
  Future<List<BodyMeasurement>> getMeasurements(String memberId) =>
      _list('${_base(memberId)}/body-measurements', BodyMeasurement.fromJson);
  @override
  Future<List<ProgressPhoto>> getPhotos(String memberId) =>
      _list('${_base(memberId)}/progress-photos', ProgressPhoto.fromJson);
  @override
  Future<List<ProgressComment>> getComments(String memberId) async =>
      (await client.get<List<ProgressComment>>(
        '/progress-comments',
        queryParameters: {'memberId': memberId, 'page': 1, 'pageSize': 100},
        decode: (value) =>
            (value as List).map(ProgressComment.fromJson).toList(),
      )).data;
  @override
  Future<ProgressComment> comment(Map<String, Object?> payload) async =>
      (await client.post<ProgressComment>(
        '/coach/progress-comments',
        body: payload,
        decode: ProgressComment.fromJson,
      )).data;
  @override
  Future<Uri> getPhotoAccessUrl(String mediaId) =>
      MemberPhotoApi(client).getAccessUrl(mediaId);
}
