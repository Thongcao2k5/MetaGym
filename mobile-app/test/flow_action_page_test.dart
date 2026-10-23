import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/features/workbench/flow_action.dart';
import 'package:meta_gym_app/features/workbench/flow_action_page.dart';
import 'package:meta_gym_app/features/workbench/flow_service.dart';

void main() {
  testWidgets('requires an ID before sending and renders empty result', (
    tester,
  ) async {
    final service = _FakeFlowService();
    await tester.pumpWidget(
      MaterialApp(
        home: FlowActionPage(
          action: const FlowAction('Xem Coach', 'GET', '/coaches/:coachId'),
          service: service,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('flow-run')));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.byKey(const Key('flow-error')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('flow-id-coachId')), 'coach-1');
    await tester.tap(find.byKey(const Key('flow-run')));
    await tester.pumpAndSettle();
    expect(service.path, '/coaches/coach-1');
    expect(find.text('Chưa có dữ liệu.'), findsOneWidget);
  });

  testWidgets('validates JSON before mutation and shows API error', (
    tester,
  ) async {
    final service = _FakeFlowService(
      error: const ApiException(
        kind: ApiExceptionKind.validation,
        message: 'Dữ liệu không hợp lệ',
        code: 'VALIDATION_ERROR',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FlowActionPage(
          action: const FlowAction('Gửi', 'POST', '/coach-requests'),
          service: service,
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('flow-body')), 'invalid');
    await tester.tap(find.byKey(const Key('flow-run')));
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.byKey(const Key('flow-error')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('flow-body')), '{}');
    await tester.tap(find.byKey(const Key('flow-run')));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.textContaining('VALIDATION_ERROR'), findsOneWidget);
  });
}

class _FakeFlowService implements FlowService {
  _FakeFlowService({this.error});
  final ApiException? error;
  int calls = 0;
  String? path;

  @override
  Future<ApiResult<Object?>> run(
    FlowAction action,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    calls++;
    this.path = path;
    if (error != null) throw error!;
    return const ApiResult<Object?>(data: []);
  }
}
