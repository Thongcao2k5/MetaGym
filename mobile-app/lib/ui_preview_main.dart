import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/core/storage/token_storage.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/member/presentation/member_dashboard_view.dart';
import 'package:provider/provider.dart';

// Local UI preview entry point. Run with `flutter run -t lib/ui_preview_main.dart`.
// No credentials or backend data are stored by this preview.
class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> delete() async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const user = AuthUser(
    id: 'preview-member',
    email: 'preview@metagym.local',
    fullName: 'Minh Quân',
    role: UserRole.member,
    status: 'ACTIVE',
  );
  final session = SessionController(_MemoryTokenStorage(), (_) async => user);
  await session.authenticate(
    const AuthSession(accessToken: 'preview', user: user),
  );
  runApp(
    ChangeNotifierProvider.value(value: session, child: const _PreviewApp()),
  );
}

class _PreviewApp extends StatefulWidget {
  const _PreviewApp();

  @override
  State<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<_PreviewApp> {
  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          extendBody: true,
          backgroundColor: MetaGymTheme.darkCanvas,
          body: Stack(
            children: [
              MemberDashboardView(
                onNavigateTab: (_) {},
                bottomPadding: MetaGymBottomNav.contentBottomPadding(context),
              ),
              const Positioned(
                top: 0,
                right: 16,
                child: SafeArea(
                  child: Text(
                    'XEM TRƯỚC · DỮ LIỆU MẪU',
                    style: TextStyle(
                      color: MetaGymTheme.warningAmber,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: MetaGymBottomNav(currentIndex: 0, onTap: (_) {}),
        ),
      ),
      GoRoute(
        path: '/member/features/:feature',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Xem trước giao diện')),
          body: const Center(child: Text('Chức năng cần backend để kiểm thử.')),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Meta Gym · UI Preview',
    theme: MetaGymTheme.dark,
    routerConfig: _router,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }
}
