import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:provider/provider.dart';

import 'flow_action.dart';
import 'flow_catalog.dart';
import 'flow_action_page.dart';
import 'flow_service.dart';

class FlowWorkbenchPage extends StatelessWidget {
  const FlowWorkbenchPage({required this.role, super.key});

  final FlowRole role;

  @override
  Widget build(BuildContext context) {
    final groups = role == FlowRole.member ? memberFlows : coachFlows;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          role == FlowRole.member
              ? 'Kiểm thử luồng hội viên'
              : 'Kiểm thử luồng Coach',
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MetaGymBackground(),
          ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Khung chức năng để thử API thật. Chọn một thao tác, '
                  'nhập mã đối tượng và dữ liệu JSON theo hợp đồng API. '
                  'Các thao tác tạo/sửa/xóa sẽ thay đổi dữ liệu thật. '
                  'Chưa hỗ trợ chọn/tải ảnh và cuộc gọi trực tiếp; '
                  'chỉ thử được URL ảnh và API metadata cuộc gọi.',
                ),
              ),
              for (final group in groups)
                ExpansionTile(
                  title: Text(group.title),
                  subtitle: Text('${group.actions.length} thao tác'),
                  children: [
                    for (final action in group.actions)
                      ListTile(
                        title: Text(action.title),
                        subtitle: Text('${action.method} ${action.path}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => FlowActionPage(
                              action: action,
                              service: ApiFlowService(
                                context.read<ApiClient>(),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
