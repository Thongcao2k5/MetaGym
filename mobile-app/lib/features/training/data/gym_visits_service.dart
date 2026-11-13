import 'package:meta_gym_app/core/network/api_client.dart';

class GymVisit {
  const GymVisit({required this.day, required this.checkedInAt,
    required this.gymName, required this.gymAddress});
  final DateTime day;
  final DateTime checkedInAt;
  final String gymName;
  final String gymAddress;

  factory GymVisit.fromJson(Object? value) {
    final json = value as Map<String, dynamic>;
    return GymVisit(
      day: DateTime.parse(json['day'] as String),
      checkedInAt: DateTime.parse(json['checkedInAt'] as String),
      gymName: json['gymName'] as String,
      gymAddress: json['gymAddress'] as String,
    );
  }
}

class GymVisitMonth {
  const GymVisitMonth({required this.visits, required this.visitedDays,
    required this.eligibleDays, required this.entryCount});
  final List<GymVisit> visits;
  final int visitedDays;
  final int eligibleDays;
  final int entryCount;

  factory GymVisitMonth.fromJson(Object? value) {
    final json = value as Map<String, dynamic>;
    return GymVisitMonth(
      visits: (json['visits'] as List).map(GymVisit.fromJson).toList(),
      visitedDays: json['visitedDays'] as int,
      eligibleDays: json['eligibleDays'] as int,
      entryCount: json['entryCount'] as int,
    );
  }
}

class GymVisitsApi {
  const GymVisitsApi(this.client);
  final ApiClient client;

  Future<GymVisitMonth> getMonth(DateTime month) async =>
      (await client.get<GymVisitMonth>('/gym-visits/me',
        queryParameters: {'month': '${month.year}-${month.month.toString().padLeft(2, '0')}'},
        decode: GymVisitMonth.fromJson)).data;

  Future<GymVisit> checkIn(String code) async =>
      (await client.post<GymVisit>('/gym-visits/check-in',
        body: {'code': code}, decode: GymVisit.fromJson)).data;
}
