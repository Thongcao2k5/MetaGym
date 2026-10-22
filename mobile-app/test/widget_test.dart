import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/app/meta_gym_app.dart';

void main() {
  testWidgets('public route can navigate to Member and Coach samples', (
    tester,
  ) async {
    await tester.pumpWidget(const MetaGymApp());

    expect(find.text('Meta Gym'), findsOneWidget);
    expect(find.text('Không gian dành cho hội viên'), findsNothing);

    await tester.tap(find.text('Khu vực Member'));
    await tester.pumpAndSettle();
    expect(find.text('Không gian dành cho hội viên'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khu vực Coach'));
    await tester.pumpAndSettle();
    expect(find.text('Không gian dành cho huấn luyện viên'), findsOneWidget);
  });
}
