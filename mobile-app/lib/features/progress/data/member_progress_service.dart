import 'package:intl/intl.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/progress/domain/progress_models.dart';

abstract interface class MemberProgressService {
  Future<ProgressSummary> getSummary();
  Future<List<WeightPoint>> getCharts({DateTime? from, DateTime? to});
}

class MemberProgressApi implements MemberProgressService {
  const MemberProgressApi(this.client);
  final ApiClient client;

  @override
  Future<ProgressSummary> getSummary() async =>
      (await client.get<ProgressSummary>(
        '/progress/me/summary',
        decode: ProgressSummary.fromJson,
      )).data;

  @override
  Future<List<WeightPoint>> getCharts({DateTime? from, DateTime? to}) async =>
      (await client.get<List<WeightPoint>>(
        '/progress/me/charts',
        queryParameters: {
          if (from != null) 'from': DateFormat('yyyy-MM-dd').format(from),
          if (to != null) 'to': DateFormat('yyyy-MM-dd').format(to),
        },
        decode: (value) => (value as List).map(WeightPoint.fromJson).toList(),
      )).data;
}
