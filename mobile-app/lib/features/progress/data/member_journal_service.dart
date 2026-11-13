import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/features/progress/domain/journal_entry.dart';

abstract interface class MemberJournalService {
  Future<List<JournalEntry>> getPage(int page);
  Future<List<JournalChartPoint>> getChart();
  Future<JournalEntry> create(Map<String, Object?> payload);
  Future<JournalEntry> update(String id, Map<String, Object?> payload);
  Future<void> delete(String id);
}

class MemberJournalApi implements MemberJournalService {
  const MemberJournalApi(this.client);
  final ApiClient client;

  Future<int> getCount() async {
    final result = await client.get('/journal',
      queryParameters: {'page': 1, 'pageSize': 1}, decode: (value) => value);
    return result.pagination?['totalItems'] as int? ?? 0;
  }

  @override
  Future<List<JournalEntry>> getPage(int page) async =>
      (await client.get<List<JournalEntry>>(
        '/journal',
        queryParameters: {'page': page, 'pageSize': 20},
        decode: (value) => (value as List).map(JournalEntry.fromJson).toList(),
      )).data;

  @override
  Future<List<JournalChartPoint>> getChart() async =>
      (await client.get<List<JournalChartPoint>>(
        '/journal/charts',
        decode: (value) => (value as List)
            .map(JournalChartPoint.fromJson).toList(),
      )).data;

  @override
  Future<JournalEntry> create(Map<String, Object?> payload) async =>
      (await client.post<JournalEntry>(
        '/journal', body: payload, decode: JournalEntry.fromJson,
      )).data;

  @override
  Future<JournalEntry> update(String id, Map<String, Object?> payload) async =>
      (await client.patch<JournalEntry>(
        '/journal/${Uri.encodeComponent(id)}',
        body: payload, decode: JournalEntry.fromJson,
      )).data;

  @override
  Future<void> delete(String id) async {
    await client.delete<Map<String, dynamic>>(
      '/journal/${Uri.encodeComponent(id)}',
      decode: (value) => Map<String, dynamic>.from(value as Map),
    );
  }
}
