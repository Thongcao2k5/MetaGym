import 'package:flutter_test/flutter_test.dart';
import 'package:meta_gym_app/core/config/api_config.dart';
import 'package:meta_gym_app/core/network/api_client.dart';
import 'package:meta_gym_app/core/network/api_exception.dart';
import 'package:meta_gym_app/core/network/local_demo_interceptor.dart';
import 'package:meta_gym_app/features/ai/data/ai_service.dart';
import 'package:meta_gym_app/features/auth/data/auth_api.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/calls/data/calls_service.dart';
import 'package:meta_gym_app/features/membership/data/membership_api.dart';
import 'package:meta_gym_app/features/membership/domain/membership_models.dart';
import 'package:meta_gym_app/features/messaging/data/messaging_service.dart';
import 'package:meta_gym_app/features/progress/data/member_journal_service.dart';
import 'package:meta_gym_app/features/progress/data/member_progress_service.dart';
import 'package:meta_gym_app/features/training/data/gym_visits_service.dart';
import 'package:meta_gym_app/features/training/data/member_self_training_api.dart';
import 'package:meta_gym_app/features/training/data/nutrition_tracking_api.dart';
import 'package:meta_gym_app/features/training/domain/member_self_training_day.dart';
import 'package:meta_gym_app/features/training/domain/training_models.dart';

void main() {
  tearDown(() {
    OfflineDemoControl.mode.value = DemoUiStateMode.normal;
  });

  group('LocalDemoInterceptor', () {
    test(
      'authenticates seeded member account and serves full local dataset',
      () async {
        String? activeToken;
        final client = ApiClient(
          config: ApiConfig.fromValues(environment: 'local'),
          accessTokenProvider: () => activeToken,
          enableLocalDemoMode: true,
        );
        final authApi = AuthApi(client);

        final session = await authApi.login(
          email: LocalDemoAccounts.memberEmail,
          password: LocalDemoAccounts.demoPassword,
        );
        activeToken = session.accessToken;

        expect(session.user.fullName, 'Nguyễn Minh Quân');
        expect(session.user.role, UserRole.member);
        expect(LocalDemoAccounts.isDemoToken(activeToken), isTrue);

        final memberships = (await client.get<List<Membership>>(
          '/memberships/me',
          decode: (v) => (v as List).map(Membership.fromJson).toList(),
        )).data;
        expect(memberships.length, 1);
        expect(memberships.first.status, 'ACTIVE');
        expect(memberships.first.planName, contains('Hạng Vàng'));

        final plan = (await client.get<TrainingPlan>(
          '/training-plans/me/active',
          decode: TrainingPlan.fromJson,
        )).data;
        expect(plan.days.length, 7);
        expect(plan.days.first.exercises.isNotEmpty, isTrue);
        expect(plan.days.last.isRestOrRecovery, isTrue);

        final visitsApi = GymVisitsApi(client);
        final before = await visitsApi.getMonth(DateTime.now());
        expect(before.visits.length, 5);
        await visitsApi.checkIn('LOCAL-QR-TEST');
        final after = await visitsApi.getMonth(DateTime.now());
        expect(after.visits.length, 6);

        // Thanh toán offline
        final membershipApi = MembershipApi(client);
        final plans = await membershipApi.getPlans();
        expect(plans.length, 4);
        final payment = await membershipApi.createPayment(
          planId: plans.first.id,
          idempotencyKey: 'idem-offline-1',
        );
        final confirmed = await membershipApi.confirmMockPayment(payment.id);
        expect(confirmed.payment.status, 'SUCCESS');
        expect(confirmed.membership.planName, plans.first.name);

        // AI Chat offline
        final aiApi = AiApi(client);
        final aiConv = await aiApi.create();
        final aiRes = await aiApi.sendQuestion(
          aiConv.id,
          'Nên ăn gì trước buổi tập?',
          'req-1',
        );
        expect(aiRes.isComplete, isTrue);
        expect(aiRes.reply!.content, contains('dinh dưỡng'));

        // Direct Chat offline
        final msgApi = MessagingApi(client);
        final convs = await msgApi.getConversations(1);
        expect(convs.isNotEmpty, isTrue);
        await msgApi.sendText(convs.first.messageKey, 'Chào Coach!', 'cm-1');
        final msgs = await msgApi.getMessages(convs.first.messageKey, 1);
        expect(msgs.any((m) => m.content == 'Chào Coach!'), isTrue);

        // Cuộc gọi mô phỏng offline
        final callsApi = CallsApi(client);
        final createdCall = await callsApi.createLiveCall(
          convs.first.relationshipId!,
          'VIDEO',
        );
        final roomAccess = await callsApi.getRoomAccess(createdCall.id);
        expect(roomAccess.token, 'local-demo-livekit-token');
        final ended = await callsApi.updateStatus(createdCall.id, 'ENDED');
        expect(ended.status, 'ENDED');
      },
    );

    test(
      'serves valid schemas for nutrition tracking, self-training, journal and progress offline',
      () async {
        String? activeToken;
        final client = ApiClient(
          config: ApiConfig.fromValues(environment: 'local'),
          accessTokenProvider: () => activeToken,
          enableLocalDemoMode: true,
        );
        final session = await AuthApi(client).login(
          email: LocalDemoAccounts.memberEmail,
          password: LocalDemoAccounts.demoPassword,
        );
        activeToken = session.accessToken;

        final vnNow = DateTime.now().toUtc().add(const Duration(hours: 7));
        String fmt(DateTime d) =>
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final todayStr = fmt(vnNow);
        final yesterdayStr = fmt(vnNow.subtract(const Duration(days: 1)));

        // 1. NutritionTrackingApi
        final nutritionApi = NutritionTrackingApi(client);
        final todayData = await nutritionApi.day(todayStr);
        expect(todayData['canWrite'], isTrue);
        expect(todayData['hasActiveMembership'], isTrue);
        expect(todayData['plan'], isNotNull);
        final todayEntries = (todayData['entries'] as List)
            .cast<Map<String, dynamic>>();
        expect(todayEntries, isNotEmpty);
        expect(todayEntries.first['mealName'], isNotNull);
        expect(todayEntries.first['kcal'], isA<num>());

        final yesterdayData = await nutritionApi.day(yesterdayStr);
        expect(yesterdayData['canWrite'], isFalse);

        final foods = await nutritionApi.foods();
        expect(foods, isNotEmpty);
        expect(foods.first['kcalPer100g'], isA<num>());

        await nutritionApi.add({
          'eatenAt': '${todayStr}T19:00:00+07:00',
          'mealType': 'DINNER',
          'mealName': 'Cá hồi phi lê áp chảo',
          'foodId': 'food-003',
          'quantity': 150,
          'unit': 'g',
          'notes': '',
        });
        final afterAdd = await nutritionApi.day(todayStr);
        final afterEntries = (afterAdd['entries'] as List)
            .cast<Map<String, dynamic>>();
        final createdMeal = afterEntries.firstWhere(
          (e) => e['mealType'] == 'DINNER',
        );
        expect(createdMeal['mealName'], 'Cá hồi phi lê áp chảo');
        expect(createdMeal['kcal'], 312.0);

        await nutritionApi.update(createdMeal['id'] as String, {
          'eatenAt': '${todayStr}T19:00:00+07:00',
          'mealType': 'DINNER',
          'mealName': 'Cơm nhà',
          'foodId': null,
          'quantity': 1,
          'unit': 'phần',
          'notes': '',
        });
        final afterUpdate = await nutritionApi.day(todayStr);
        final updatedMeal = (afterUpdate['entries'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((e) => e['id'] == createdMeal['id']);
        expect(updatedMeal['mealName'], 'Cơm nhà');
        expect(updatedMeal['kcal'], isNull);

        await nutritionApi.delete(createdMeal['id'] as String);

        // 2. MemberSelfTrainingApi
        final selfApi = MemberSelfTrainingApi(client);
        final range = await selfApi.getRange(
          fmt(vnNow.subtract(const Duration(days: 7))),
          fmt(vnNow.add(const Duration(days: 7))),
        );
        expect(range, isNotEmpty);
        expect(range.first.exercises, isNotEmpty);
        final savedPlan = await selfApi.save(
          day: fmt(vnNow.add(const Duration(days: 1))),
          title: 'Vai & Tay tự tập',
          startTime: '17:30',
          notes: 'Khởi động kỹ',
          exercises: const [
            SelfTrainingExercise(
              id: 'custom-1',
              name: 'Lateral Raise',
              sets: 4,
              reps: '12-15',
            ),
          ],
        );
        expect(savedPlan.planDate, fmt(vnNow.add(const Duration(days: 1))));
        expect(savedPlan.exercises.first.name, 'Lateral Raise');
        expect(savedPlan.exercises.first.sets, 4);
        expect(savedPlan.exercises.first.reps, '12-15');
        await selfApi.delete(savedPlan.planDate);

        // 3. MemberJournalApi & MemberProgressApi
        final journalApi = MemberJournalApi(client);
        final journalEntries = await journalApi.getPage(1);
        expect(journalEntries, isNotEmpty);
        expect(journalEntries.first.achievements, isNotEmpty);
        final journalChart = await journalApi.getChart();
        expect(journalChart, isNotEmpty);

        final createdJournal = await journalApi.create({
          'journalDate': todayStr,
          'notes': 'Tập tốt',
          'chestCm': 98.5,
          'achievements': [
            {'title': 'Đẩy ngực', 'result': '75 kg'},
          ],
          'photoMediaIds': const <String>[],
        });
        expect(createdJournal.chestCm, 98.5);
        await journalApi.update(createdJournal.id, {
          'notes': 'Tập rất tốt',
          'achievements': [
            {'title': 'Đẩy ngực', 'result': '77.5 kg'},
          ],
          'photoMediaIds': const <String>[],
        });
        await journalApi.delete(createdJournal.id);

        final progressApi = MemberProgressApi(client);
        final summary = await progressApi.getSummary();
        expect(summary.latestMeasurement, isNotNull);
        final charts = await progressApi.getCharts();
        expect(charts, isNotEmpty);
        expect(charts.last.weightKg, 72.1);
      },
    );

    test('supports empty and error demo state modes offline', () async {
      String? activeToken;
      final client = ApiClient(
        config: ApiConfig.fromValues(environment: 'local'),
        accessTokenProvider: () => activeToken,
        enableLocalDemoMode: true,
      );
      final authApi = AuthApi(client);
      final session = await authApi.login(
        email: LocalDemoAccounts.memberEmail,
        password: LocalDemoAccounts.demoPassword,
      );
      activeToken = session.accessToken;

      OfflineDemoControl.mode.value = DemoUiStateMode.empty;
      final emptyMemberships = (await client.get<List<Membership>>(
        '/memberships/me',
        decode: (v) => (v as List).map(Membership.fromJson).toList(),
      )).data;
      expect(emptyMemberships, isEmpty);

      OfflineDemoControl.mode.value = DemoUiStateMode.error;
      await expectLater(
        () => client.get<List<Membership>>(
          '/memberships/me',
          decode: (v) => (v as List).map(Membership.fromJson).toList(),
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('authenticates seeded coach account', () async {
      final client = ApiClient(
        config: ApiConfig.fromValues(environment: 'local'),
        enableLocalDemoMode: true,
      );
      final authApi = AuthApi(client);
      final session = await authApi.login(
        email: LocalDemoAccounts.coachEmail,
        password: LocalDemoAccounts.demoPassword,
      );
      expect(session.user.fullName, 'Lê Hoàng Nam');
      expect(session.user.role, UserRole.coach);
    });
  });
}
