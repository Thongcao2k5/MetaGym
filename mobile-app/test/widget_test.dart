import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/main.dart';

void main() {
  testWidgets('shows the Meta Gym scaffold', (tester) async {
    await tester.pumpWidget(const MetaGymApp());

    expect(find.text('Meta Gym'), findsOneWidget);
    expect(find.text('Khung ứng dụng đã sẵn sàng để phát triển.'), findsOneWidget);
  });
}
