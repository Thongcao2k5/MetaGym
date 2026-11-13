import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/coaching/data/coach_v2_api.dart';
import 'package:provider/provider.dart';

class CoachNotificationsPage extends StatefulWidget {
  const CoachNotificationsPage({super.key});

  @override
  State<CoachNotificationsPage> createState() => _CoachNotificationsPageState();
}

class _CoachNotificationsPageState extends State<CoachNotificationsPage> {
  late final _api = CoachV2Api(context.read<ApiClient>());
  late var _items = _api.list('/coach-notifications');
  bool _saving = false;

  void _reload() => setState(() => _items = _api.list('/coach-notifications'));

  Future<void> _read(CoachRecord item) async {
    if (_saving || item['readAt'] != null) return;
    setState(() => _saving = true);
    try {
      await _api.patch('/coach-notifications/${item['id']}/read', {});
      if (mounted) _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thông báo Coach'),
      actions: [
        IconButton(
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại',
        ),
      ],
    ),
    body: FutureBuilder<List<CoachRecord>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: Text(
                error is ApiException
                    ? '${error.message} · Thử lại'
                    : 'Không tải được thông báo · Thử lại',
              ),
            ),
          );
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(child: Text('Chưa có thông báo.'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final unread = item['readAt'] == null;
            return ListTile(
              leading: Icon(
                unread
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none,
              ),
              title: Text(switch (item['kind']) {
                'BOOKED' => 'Có lịch tập mới với Coach',
                'COMPLETED' => 'Coach đã xác nhận buổi tập',
                'CANCELLED' => 'Lịch tập đã hủy hoặc thay đổi',
                'PACKAGE_ACTIVE' => 'Gói Coach đã kích hoạt',
                'PACKAGE_QUEUED' => 'Gói Coach đang chờ kích hoạt',
                'PACKAGE_EXTENDED' => 'Gói Coach được thêm 7 ngày',
                'PACKAGE_LAST_SESSION' => 'Gói Coach còn 1 buổi',
                'PACKAGE_ENDED' => 'Gói Coach đã kết thúc',
              'PACKAGE_EXPIRING' => 'Gói Coach còn tối đa 7 ngày',
                _ => 'Có cập nhật về Coach',
              }),
              subtitle: Text(
                unread ? 'Chưa đọc · Chạm để đánh dấu đã đọc' : 'Đã đọc',
              ),
              onTap: unread && !_saving ? () => _read(item) : null,
            );
          },
        );
      },
    ),
  );
}
