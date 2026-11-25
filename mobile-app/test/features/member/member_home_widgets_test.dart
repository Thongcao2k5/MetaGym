import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/features/member/presentation/member_explore_articles.dart';
import 'package:meta_gym_app/features/member/presentation/widgets/member_home_explore_and_news.dart';
import 'package:meta_gym_app/features/member/presentation/widgets/member_home_fan_deck.dart';
import 'package:meta_gym_app/features/member/presentation/widgets/member_home_qr_modal.dart';

void main() {
  testWidgets('MemberHomeFanDeck renders 4 tiers and switches on dot tap', (
    tester,
  ) async {
    var membershipTapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                MemberHomeExploreGrid(
                  onOpenAll: () {},
                  onOpenEquipment: () {},
                  onOpenVisits: () {},
                  onOpenMeasurements: () {},
                  onOpenCoach: () {},
                ),
                const SizedBox(height: 16),
                MemberHomeFanDeck(
                  onOpenMembership: () => membershipTapped++,
                ),
                const SizedBox(height: 16),
                MemberHomeArticlesSection(
                  onOpenGymIntro: () {},
                  onOpenBeginnerGuide: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Khám phá Meta Gym'), findsOneWidget);
    expect(find.text('Đặc quyền Hội viên'), findsOneWidget);
    expect(find.text('Thẻ Vàng — Pro VIP'), findsOneWidget);
    expect(find.text('Tin tức & Bài viết'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const ValueKey<String>('fan-card-2')));
    await tester.tap(find.byKey(const ValueKey<String>('fan-card-2')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey<String>('fan-card-3')));
    await tester.pumpAndSettle();
    expect(find.text('Thẻ Kim Cương — Elite'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Xem gói tập ›'));
    await tester.tap(find.text('Xem gói tập ›'));
    await tester.pumpAndSettle();
    expect(membershipTapped, 1);
  });

  testWidgets('Member QR Check-in modal opens and regenerates session token', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showMemberQrCheckinModal(
                  context,
                  memberName: 'Nguyễn Minh Quân',
                  memberCode: 'MG-2048',
                ),
                child: const Text('Mở QR'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở QR'));
    await tester.pumpAndSettle();
    expect(find.text('QR Check-in Phòng Tập'), findsOneWidget);
    expect(find.byKey(const Key('qr-regen-btn')), findsOneWidget);

    await tester.tap(find.byKey(const Key('qr-regen-btn')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('qr-close-btn')));
    await tester.pumpAndSettle();
    expect(find.text('QR Check-in Phòng Tập'), findsNothing);
  });

  testWidgets(
    'MemberExploreArticleDetailPage bolds Nhật ký tập luyện and CTA routes to /member/features/workouts',
    (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => MemberExploreArticleDetailPage(
              article: kMemberExploreArticles.last,
            ),
          ),
          GoRoute(
            path: '/member/features/workouts',
            builder: (_, _) => const Scaffold(body: Text('Workouts Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Nhật ký tập luyện', findRichText: true),
        findsWidgets,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('article-detail-cta')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('article-detail-cta')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('article-detail-cta')));
      await tester.pumpAndSettle();
      expect(find.text('Workouts Target'), findsOneWidget);
    },
  );
}
