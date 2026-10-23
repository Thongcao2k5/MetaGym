import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/features/workbench/flow_action.dart';
import 'package:meta_gym_app/features/workbench/flow_catalog.dart';

void main() {
  test('replaces path parameters and encodes supplied values', () {
    const action = FlowAction('Xem', 'GET', '/coach/members/:memberId');
    expect(action.pathParameters, ['memberId']);
    expect(
      action.resolvePath({'memberId': 'member 1'}),
      '/coach/members/member%201',
    );
  });

  test('rejects missing or path-breaking identifiers', () {
    const action = FlowAction('Xem', 'GET', '/coaches/:coachId');
    expect(() => action.resolvePath({}), throwsFormatException);
    expect(() => action.resolvePath({'coachId': 'a/b'}), throwsFormatException);
  });

  test('all sample payloads and queries are JSON objects', () {
    for (final flows in [memberFlows, coachFlows]) {
      final operations = <String>{};
      for (final group in flows) {
        for (final action in group.actions) {
          expect(
            operations.add('${action.method} ${action.path}'),
            isTrue,
            reason: action.title,
          );
          if (action.sampleBody case final body?) {
            expect(jsonDecode(body), isA<Map>(), reason: action.title);
          }
          if (action.sampleQuery case final query?) {
            expect(jsonDecode(query), isA<Map>(), reason: action.title);
          }
        }
      }
    }
  });
}
