import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meta_gym_app/app/app_router.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({this.bottomPadding, super.key});

  final double? bottomPadding;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleFieldController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _fillFields(context.read<SessionController>().user!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloadProfile();
    });
  }

  Future<void> _reloadProfile() async {
    if (!await context.read<ProfileController>().load() || !mounted) return;
    _fillFields(context.read<SessionController>().user!);
    setState(() {});
  }

  void _fillFields(AuthUser user) {
    _nameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
    _roleFieldController.text = switch (user.role) {
      UserRole.member => user.profile['fitnessGoal'] as String? ?? '',
      UserRole.coach => user.profile['biography'] as String? ?? '',
      UserRole.admin => '',
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _roleFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final user = context.watch<SessionController>().user!;
    final effectiveBottomPadding =
        widget.bottomPadding ?? MetaGymBottomNav.contentBottomPadding(context);

    final cleanName = user.fullName.trim();
    final parts = cleanName
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (cleanName.isNotEmpty
              ? cleanName
                    .substring(0, cleanName.length >= 2 ? 2 : 1)
                    .toUpperCase()
              : 'MG');

    return Scaffold(
      backgroundColor: MetaGymTheme.scaffoldBackground,
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          'Hồ sơ',
          style: TextStyle(
            color: MetaGymTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            fontFamily: MetaGymTheme.fontFamily,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, effectiveBottomPadding + 24),
        children: [
          // 1. Thẻ thông tin cá nhân & Avatar
          MetaGymGlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF7E58), Color(0xFFFF4820)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x4DFFFFFF),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4DFF5A36),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: const TextStyle(
                                color: MetaGymTheme.darkTextPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x2423C997),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0x4D23C997),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              user.role == UserRole.member
                                  ? 'Hội viên'
                                  : (user.role == UserRole.coach
                                        ? 'HLV'
                                        : 'Admin'),
                              style: const TextStyle(
                                color: Color(0xFF23C997),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: MetaGymTheme.darkTextSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Thẻ chỉnh sửa hồ sơ
          MetaGymGlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THÔNG TIN TÀI KHOẢN',
                  style: TextStyle(
                    color: MetaGymTheme.reflectionBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: MetaGymTheme.darkTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Họ và tên',
                    labelStyle: const TextStyle(
                      color: MetaGymTheme.darkTextSecondary,
                    ),
                    filled: true,
                    fillColor: const Color(0x1F162232),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x38D4E4FF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x38D4E4FF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: MetaGymTheme.brandOrange,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: MetaGymTheme.darkTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại',
                    labelStyle: const TextStyle(
                      color: MetaGymTheme.darkTextSecondary,
                    ),
                    filled: true,
                    fillColor: const Color(0x1F162232),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x38D4E4FF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x38D4E4FF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: MetaGymTheme.brandOrange,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                if (user.role != UserRole.admin) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _roleFieldController,
                    maxLines: 3,
                    style: const TextStyle(color: MetaGymTheme.darkTextPrimary),
                    decoration: InputDecoration(
                      labelText: user.role == UserRole.member
                          ? 'Mục tiêu tập luyện'
                          : 'Giới thiệu huấn luyện viên',
                      labelStyle: const TextStyle(
                        color: MetaGymTheme.darkTextSecondary,
                      ),
                      filled: true,
                      fillColor: const Color(0x1F162232),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0x38D4E4FF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0x38D4E4FF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: MetaGymTheme.brandOrange,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
                if (profile.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1FF15B64),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      profile.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Nút Lưu hồ sơ
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MetaGymTheme.brandOrange,
                foregroundColor: MetaGymTheme.onBrandOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: profile.isBusy
                  ? null
                  : () => profile.updateProfile(
                      fullName: _nameController.text,
                      phone: _phoneController.text,
                      fitnessGoal: _roleFieldController.text,
                      biography: _roleFieldController.text,
                    ),
              child: Text(
                profile.isBusy ? 'Đang lưu…' : 'Lưu hồ sơ',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Nút Đổi mật khẩu
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: MetaGymTheme.darkTextPrimary,
                side: const BorderSide(color: Color(0x38D4E4FF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: profile.isBusy
                  ? null
                  : () => context.push(AppRoutes.changePassword),
              child: const Text(
                'Đổi mật khẩu',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Nút Đăng xuất
          Center(
            child: TextButton.icon(
              onPressed: () => context.read<SessionController>().signOut(),
              icon: const Icon(
                Icons.logout_rounded,
                color: MetaGymTheme.dangerCoral,
                size: 18,
              ),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(
                  color: MetaGymTheme.dangerCoral,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
