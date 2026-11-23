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
import 'package:meta_gym_app/features/training/data/gym_visits_service.dart';
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
        expect(plan.days.length, 3);
        expect(plan.days.first.exercises.isNotEmpty, isTrue);

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

    test('supports empty and error demo state modes offline', () async {
      String? activeToken;
      final client = ApiClient(
        config: ApiConfig.fromValues(environment: 'local'),
        accessTokenProvider: () => activeToken,
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
