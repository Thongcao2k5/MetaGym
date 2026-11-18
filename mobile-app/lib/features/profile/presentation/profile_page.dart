import 'dart:io' show Directory, File;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, Uint8List;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_health_declaration_page.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:meta_gym_app/features/progress/presentation/member_journal_page.dart';
import 'package:meta_gym_app/features/training/presentation/gym_visits_page.dart';
import 'package:provider/provider.dart';

enum _PhotoAccessMode { unset, full, selectedOnly, denied }

/// Màn hình Hồ sơ cá nhân lấy chính xác bảng màu, độ mờ và định dạng thẻ từ
/// Trang chủ Hội viên (`member_dashboard_view.dart`):
/// - Background: `_gymBannerAsset` + radial glow + scrim `[0x9E0F1115, 0x900F1115, 0xAA0F1115]`
/// - Hero Glass Card: gradient `[0xCD342D28, 0xC829241F]`, border `0xB7B3A99D` (1.2px), top line `0x75FFF5E9`
/// - Content Card: fill `0xC42B2622` (featured `0xB82D2824`), border `0xA3A79D92` (1.1px), top line `0x70FFF6EA`
/// - Inner Metric Panel: fill `0x80211E1C`, border `0x9A8C8176` (1.0px), radius `17`
/// - Quick Action Tile: gradient `[0xC637302A, 0xBB2C2621]`, border `0xB7ADA396` (1.1px), radius `18`
/// - Header Circle Button: fill `0x9E2F2924`, border `0x95ADA295` (1.0px)
class ProfilePage extends StatefulWidget {
  const ProfilePage({this.bottomPadding, super.key});

  final double? bottomPadding;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const AssetImage _gymBannerAsset = AssetImage(
    'assets/images/gym_banner.png',
  );

  static const MethodChannel _mediaPermissionChannel = MethodChannel(
    'com.metagym.meta_gym_app/media_permission',
  );
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const bool _showQuickActionDock = false;

  bool _initialized = false;
  int? _expandedCategory;
  VoidCallback? _activeSectionRefresh;

  // Trạng thái Avatar & Quyền truy cập ảnh
  Uint8List? _avatarBytes;
  List<Uint8List> _allowedPhotoBytes = const [];
  _PhotoAccessMode _photoAccessMode = _PhotoAccessMode.unset;

  // Trạng thái Quyền riêng tư & Cài đặt ứng dụng
  bool _shareJournalWithCoach = true;
  bool _shareMeasurementsWithCoach = true;
  String _unitSystem = 'cm / kg';
  bool _workoutReminderEnabled = true;
  String _reminderTime = '18:00';

  // Trạng thái đồng bộ với `/users/me`
  String _fullName = '';
  String _email = '';
  String _phone = '';
  UserRole _role = UserRole.member;
  String _status = 'ACTIVE';

  // Trường dành cho Hội viên (`member_profiles`)
  String _dateOfBirth = '1999-08-15';
  String _gender = 'MALE';
  double _heightCm = 0;
  String _fitnessGoal = '';
  String _experienceLevel = 'INTERMEDIATE';
  String _activityLevel = 'MODERATE';
  String _healthNotes = '';
  String _injuryNotes = '';
  String _dietaryPreferences = 'Ưu tiên đạm cao (~150g/ngày), hạn chế đường';

  // Trường dành cho Huấn luyện viên (`coach_profiles`)
  String _biography =
      'Huấn luyện viên cá nhân chuyên Hypertrophy, Strength & Mobility.';
  List<String> _specialties = ['Hypertrophy', 'Giảm mỡ', 'Phục hồi vận động'];
  String _qualifications = 'CPT NASM · Chứng chỉ Dinh dưỡng Thể thao';
  int _experienceYears = 4;
  String _availabilityNote = 'Thứ 2 – Thứ 7 · 06:00 – 20:00';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(_gymBannerAsset, context).catchError((_) {});
    }
    if (_initialized) return;
    _initialized = true;

    final user = context.read<SessionController?>()?.user;
    if (user != null) {
      _syncFromUser(user);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reloadProfile();
        _loadSavedAvatar();
      }
    });
  }

  String get _avatarStorageKey {
    final userId = context.read<SessionController?>()?.user?.id ?? _email;
    return 'meta_gym.avatar.${userId.isNotEmpty ? userId : "default"}';
  }

  String get _permissionStorageKey {
    final userId = context.read<SessionController?>()?.user?.id ?? _email;
    return 'meta_gym.photo_permission.${userId.isNotEmpty ? userId : "default"}';
  }

  File? _getAvatarCacheFile(String userId) {
    if (MetaGymTheme.isFlutterTestEnvironment) return null;
    try {
      final tempDir = Directory.systemTemp.path;
      final safeKey = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      return File('$tempDir/meta_gym_avatar_$safeKey.jpg');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadSavedAvatar() async {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      final user = context.read<SessionController?>()?.user;
      final controller = context.read<ProfileController?>();
      final userId = user?.id ?? _email;
      final file = _getAvatarCacheFile(userId);

      // 1. Kiểm tra cache tệp cục bộ trước (tốc độ cao, không cần mạng)
      if (file != null && await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty && mounted) {
          setState(() => _avatarBytes = bytes);
        }
      }

      // 2. Nếu chưa có ảnh trong cache và người dùng có avatarUrl trên server
      if (_avatarBytes == null &&
          user?.avatarUrl != null &&
          user!.avatarUrl!.isNotEmpty &&
          controller != null) {
        final serverBytes = await controller.fetchAvatarBytes(user.avatarUrl!);
        if (serverBytes != null && serverBytes.isNotEmpty) {
          if (file != null) {
            await file.writeAsBytes(serverBytes, flush: true);
          }
          if (mounted) {
            setState(() => _avatarBytes = serverBytes);
          }
        }
      }

      // 3. Khôi phục quyền ảnh đã cấp
      final rawPerm = await _secureStorage.read(key: _permissionStorageKey);
      if (rawPerm != null && mounted) {
        setState(() {
          _photoAccessMode = _PhotoAccessMode.values.firstWhere(
            (e) => e.name == rawPerm,
            orElse: () => _PhotoAccessMode.unset,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAvatarToStorage(
    Uint8List? avatarBytes,
    _PhotoAccessMode mode,
  ) async {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      final userId = context.read<SessionController?>()?.user?.id ?? _email;
      final controller = context.read<ProfileController?>();
      final file = _getAvatarCacheFile(userId);

      if (avatarBytes == null || avatarBytes.isEmpty) {
        if (file != null && await file.exists()) {
          await file.delete();
        }
        await _secureStorage.delete(key: _avatarStorageKey);
        if (controller != null) {
          await controller.deleteAvatar();
        }
      } else {
        // Lưu vào tệp cục bộ trên thiết bị
        if (file != null) {
          await file.writeAsBytes(avatarBytes, flush: true);
        }
        // Đồng bộ lưu lên máy chủ database qua API
        if (controller != null) {
          await controller.uploadAvatar(avatarBytes);
        }
      }
      await _secureStorage.write(key: _permissionStorageKey, value: mode.name);
    } catch (_) {}
  }

  Future<_PhotoAccessMode> _requestNativePhotoPermission() async {
    if (MetaGymTheme.isFlutterTestEnvironment) return _PhotoAccessMode.full;
    try {
      final result = await _mediaPermissionChannel.invokeMethod<String>(
        'request',
      );
      switch (result) {
        case 'FULL':
          return _PhotoAccessMode.full;
        case 'SELECTED':
          return _PhotoAccessMode.selectedOnly;
        case 'DENIED':
          return _PhotoAccessMode.denied;
        default:
          return _PhotoAccessMode.full;
      }
    } catch (_) {
      return _PhotoAccessMode.full;
    }
  }

  Future<List<Uint8List>> _loadNativeGrantedPhotos() async {
    if (MetaGymTheme.isFlutterTestEnvironment) return const [];
    try {
      final rawList = await _mediaPermissionChannel.invokeMethod<List<dynamic>>(
        'getSelectedPhotos',
      );
      if (rawList == null) return const [];
      return rawList.whereType<Uint8List>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _reloadProfile() async {
    try {
      final controller = context.read<ProfileController?>();
      if (controller == null) return;
      if (!await controller.load() || !mounted) return;
      final user = context.read<SessionController?>()?.user;
      if (user != null) {
        setState(() => _syncFromUser(user));
        _loadSavedAvatar();
      }
    } catch (_) {
      // Giữ trạng thái hiện tại nếu chạy ở chế độ preview độc lập.
    }
  }

  void _syncFromUser(AuthUser user) {
    _fullName = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : 'Hội viên Meta Gym';
    _email = user.email.trim();
    _phone = user.phone?.trim() ?? '';
    _role = user.role;
    _status = user.status.isNotEmpty ? user.status : 'ACTIVE';

    final p = user.profile;
    if (user.role == UserRole.member) {
      final dob = p['dateOfBirth'] as String?;
      if (dob != null && dob.trim().isNotEmpty) _dateOfBirth = dob.trim();

      final gender = p['gender'] as String?;
      if (gender != null && gender.trim().isNotEmpty) _gender = gender.trim();

      final height = p['heightCm'];
      _heightCm = height is num && height > 0 ? height.toDouble() : 0;

      final goal = p['fitnessGoal'] as String?;
      _fitnessGoal = goal?.trim() ?? '';

      final exp = p['experienceLevel'] as String?;
      if (exp != null && exp.trim().isNotEmpty) _experienceLevel = exp.trim();

      final act = p['activityLevel'] as String?;
      if (act != null && act.trim().isNotEmpty) _activityLevel = act.trim();

      final health = p['healthNotes'] as String?;
      _healthNotes = health?.trim() ?? '';

      final injury = p['injuryNotes'] as String?;
      _injuryNotes = injury?.trim() ?? '';

      final diet = p['dietaryPreferences'] as String?;
      if (diet != null && diet.trim().isNotEmpty) {
        _dietaryPreferences = diet.trim();
      }
    } else if (user.role == UserRole.coach) {
      final bio = p['biography'] as String?;
      if (bio != null && bio.trim().isNotEmpty) _biography = bio.trim();

      final specs = p['specialties'];
      if (specs is List && specs.isNotEmpty) {
        _specialties = specs
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final qual = p['qualifications'] as String?;
      if (qual != null && qual.trim().isNotEmpty) {
        _qualifications = qual.trim();
      }

      final years = p['experienceYears'];
      if (years is num && years >= 0) _experienceYears = years.toInt();

      final avail = p['availabilityNote'] as String?;
      if (avail != null && avail.trim().isNotEmpty) {
        _availabilityNote = avail.trim();
      }
    }
  }

  Future<bool> _persistPatch(
    Map<String, Object?> patch, {
    required String successMessage,
  }) async {
    final controller = context.read<ProfileController?>();
    if (controller != null) {
      final ok = await controller.patchProfile(patch);
      if (!mounted) return false;
      if (ok) {
        final updatedUser = context.read<SessionController?>()?.user;
        if (updatedUser != null) {
          setState(() => _syncFromUser(updatedUser));
        }
        _refreshBoth();
        _showToast(successMessage);
        return true;
      } else {
        _showToast(
          controller.errorMessage ?? 'Không thể lưu thay đổi lên máy chủ.',
          isError: true,
        );
        return false;
      }
    }
    _refreshBoth();
    _showToast(successMessage);
    return true;
  }

  String get _initials {
    final clean = _fullName.trim();
    final parts = clean
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (clean.isNotEmpty) {
      return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'MG';
  }

  String get _roleLabel => switch (_role) {
    UserRole.member => 'Hội viên',
    UserRole.coach => 'Huấn luyện viên',
    UserRole.admin => 'Quản trị viên',
  };

  static String _genderLabel(String code) => switch (code) {
    'MALE' => 'Nam',
    'FEMALE' => 'Nữ',
    'OTHER' => 'Khác',
    _ => 'Không tiết lộ',
  };

  static String _experienceLabel(String code) => switch (code) {
    'BEGINNER' => 'Mới bắt đầu',
    'INTERMEDIATE' => 'Trung cấp',
    'ADVANCED' => 'Nâng cao',
    _ => code,
  };

  static String _activityLabel(String code) => switch (code) {
    'LOW' => 'Ít vận động',
    'MODERATE' => 'Trung bình',
    'HIGH' => 'Năng động cao',
    _ => code,
  };

  void _refreshBoth() {
    if (mounted) setState(() {});
    _activeSectionRefresh?.call();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2B2622),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isError
                  ? const Color(0x80F15B64)
                  : const Color(0xA3A79D92),
            ),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                color: isError
                    ? const Color(0xFFF15B64)
                    : MetaGymTheme.progressGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _navigateOrPushWidget({required String route, Widget? fallbackPage}) {
    try {
      context.push(route);
    } catch (_) {
      if (fallbackPage != null) {
        Navigator.of(context)
            .push<void>(MaterialPageRoute(builder: (_) => fallbackPage));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionUser = context.watch<SessionController?>()?.user;
    if (sessionUser != null && _email.isEmpty) {
      _syncFromUser(sessionUser);
    }
    final isBusy = context.watch<ProfileController?>()?.isBusy ?? false;
    final effectiveBottomPadding =
        widget.bottomPadding ?? MetaGymBottomNav.contentBottomPadding(context);

    return Material(
      color: MetaGymTheme.darkCanvas,
      child: Stack(
        children: [
          // 1. Nền Canvas & Ảnh Gym đồng bộ chính xác với member_dashboard_view.dart
          const Positioned.fill(child: _ProfileGymBackground()),

          // 2. Main scrollable viewport
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: MetaGymTheme.darkSurface,
              onRefresh: _reloadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  MetaGymTheme.pageGutter,
                  0,
                  MetaGymTheme.pageGutter,
                  effectiveBottomPadding + 32,
                ),
                children: [
                  const SizedBox(height: 6),
                  _buildHeader(isBusy: isBusy),
                  const SizedBox(height: 14),

                  // 4 nút điều hướng nhanh (ẩn theo yêu cầu, giữ nguyên hàm xử lý)
                  if (_showQuickActionDock && _role != UserRole.admin) ...[
                    _buildQuickActionDock(),
                    const SizedBox(height: 14),
                  ],

                  // Thẻ Hero Hồ sơ đồng bộ _buildMembershipGlassCard trên Trang chủ
                  _buildHeroProfileCard(),
                  const SizedBox(height: 22),
                  _ProfileCategoryCard(
                    title: 'Cá nhân & thể trạng',
                    icon: Icons.person_outline_rounded,
                    count: 3,
                    expanded: _expandedCategory == 0,
                    onToggle: () => _toggleCategory(0),
                    children: [
                      _buildPersonalInfoMenuCard(),
                      _buildTrainingProfileMenuCard(),
                      if (_role == UserRole.coach) _buildHealthMenuCard(),
                      if (_role == UserRole.member)
                        _buildCoachDeclarationMenuCard(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProfileCategoryCard(
                    title: 'Tập luyện & dịch vụ',
                    icon: Icons.fitness_center_outlined,
                    count: 3,
                    expanded: _expandedCategory == 1,
                    onToggle: () => _toggleCategory(1),
                    children: _buildActivityServiceCards(),
                  ),
                  const SizedBox(height: 12),
                  _ProfileCategoryCard(
                    title: 'Tài khoản & hỗ trợ',
                    icon: Icons.tune_rounded,
                    count: 4,
                    expanded: _expandedCategory == 2,
                    onToggle: () => _toggleCategory(2),
                    children: [
                      _buildSecurityMenuCard(),
                      _buildPrivacyMenuCard(),
                      _buildAppSettingsMenuCard(),
                      _buildSupportInfoMenuCard(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSignOutButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleCategory(int index) {
    setState(
      () => _expandedCategory = _expandedCategory == index ? null : index,
    );
  }

  Widget _buildSignOutButton() => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: _confirmSignOut,
      icon: const Icon(Icons.logout_rounded, size: 20),
      label: const Text('Đăng xuất'),
      style: OutlinedButton.styleFrom(
        foregroundColor: MetaGymTheme.dangerCoral,
        backgroundColor: const Color(0xE12B2622),
        side: const BorderSide(color: Color(0xA3A79D92)),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );

  // ===========================================================================
  // 1. HEADER BAR (GIỐNG CHÍNH XÁC _buildHeader CỦA TRANG CHỦ)
  // ===========================================================================
  Widget _buildHeader({required bool isBusy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6A42), Color(0xFFFF4520)],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x40FFFFFF), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4DFF5A36),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'MG',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'META GYM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Hồ sơ',
                  style: TextStyle(
                    color: Color(0xFFF7F9FC),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MetaGymTheme.brandOrange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. QUICK ACTION DOCK (GIỐNG CHÍNH XÁC _buildQuickActionDock CỦA TRANG CHỦ)
  // ===========================================================================
  Widget _buildQuickActionDock() {
    if (_role == UserRole.coach) {
      return Row(
        children: [
          Expanded(
            child: _buildQuickActionButton(
              label: 'Học viên',
              icon: Icons.groups_outlined,
              onTap: () =>
                  _navigateOrPushWidget(route: '/coach/features/members'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionButton(
              label: 'Lịch dạy',
              icon: Icons.calendar_today_rounded,
              onTap: () =>
                  _navigateOrPushWidget(route: '/coach/features/sessions'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionButton(
              label: 'Giáo trình',
              icon: Icons.description_outlined,
              onTap: () =>
                  _navigateOrPushWidget(route: '/coach/features/training'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildQuickActionButton(
              label: 'Thông báo',
              icon: Icons.notifications_none_rounded,
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const CoachNotificationsPage(),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            label: 'Điểm danh QR',
            icon: Icons.qr_code_scanner_rounded,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const GymVisitsPage()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Gói tập',
            icon: Icons.card_membership_rounded,
            onTap: () =>
                _navigateOrPushWidget(route: '/member/features/membership'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Nhật ký',
            icon: Icons.menu_book_rounded,
            onTap: () => _navigateOrPushWidget(
              route: '/member/features/workouts',
              fallbackPage: const MemberJournalPage(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Thông báo',
            icon: Icons.notifications_none_rounded,
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const CoachNotificationsPage(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xC637302A), Color(0xBB2C2621)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xB7ADA396), width: 1.1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: const Color(0x20FFFFFF),
            child: SizedBox(
              height: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: MetaGymTheme.brandOrange),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. HERO PROFILE CARD (GỌN GÀNG ĐỒNG BỘ MẪU WAYS STATION, GIỮ PHONG CÁCH KÍNH META GYM)
  // ===========================================================================
  Widget _buildHeroProfileCard() {
    return _MembershipGlassCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openPersonalInfoPage,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF7651), MetaGymTheme.brandOrange],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x80FFE2D9)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3D000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _avatarBytes == null
                          ? Text(
                              _initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : ClipOval(
                              child: Image.memory(
                                _avatarBytes!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2622),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xB7B3A99D)),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fullName.isEmpty ? 'Hội viên Meta Gym' : _fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MetaGymTheme.darkTextPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _roleLabel,
                            style: const TextStyle(
                              color: Color(0xFFD0C8C0),
                              fontSize: 11.5,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _status == 'ACTIVE'
                                      ? MetaGymTheme.progressGreen
                                      : MetaGymTheme.warningAmber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _status == 'ACTIVE'
                                    ? 'Đang hoạt động'
                                    : 'Chờ kích hoạt',
                                style: TextStyle(
                                  color: _status == 'ACTIVE'
                                      ? MetaGymTheme.progressGreen
                                      : MetaGymTheme.warningAmber,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.mail_outline_rounded,
                            color: Color(0xFFA9C7E8),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _email.isEmpty ? 'Chưa cập nhật email' : _email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFD0C8C0),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              color: Color(0xFFA9C7E8),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _phone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFD0C8C0),
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB8C2D0),
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. CÁC LỐI VÀO THEO DANH MỤC, GIỮ NGUYÊN LUỒNG CỦA TỪNG VAI TRÒ
  // ===========================================================================
  Widget _buildPersonalInfoMenuCard() => _ProfileMenuTile(
    icon: Icons.person_outline_rounded,
    title: 'Thông tin cá nhân',
    onTap: _openPersonalInfoPage,
  );

  Widget _buildTrainingProfileMenuCard() => _ProfileMenuTile(
    icon: _role == UserRole.coach
        ? Icons.badge_outlined
        : Icons.fitness_center_outlined,
    title: _role == UserRole.coach
        ? 'Hồ sơ chuyên môn'
        : 'Thể trạng & mục tiêu',
    onTap: _role == UserRole.coach
        ? _openCoachProfilePage
        : _openTrainingProfilePage,
  );

  Widget _buildHealthMenuCard() => _ProfileMenuTile(
    icon: _role == UserRole.coach
        ? Icons.schedule_rounded
        : Icons.favorite_border_rounded,
    title: _role == UserRole.coach
        ? 'Khung giờ & chuyên môn'
        : 'Sức khỏe & chấn thương',
    onTap: _role == UserRole.coach
        ? _openCoachProfilePage
        : _openHealthNutritionPage,
  );

  Widget _buildCoachDeclarationMenuCard() => _ProfileMenuTile(
    icon: Icons.monitor_heart_outlined,
    title: 'Khai báo thể trạng cho Coach',
    onTap: () async {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const MemberHealthDeclarationPage()),
      );
      if (saved == true && mounted) await _reloadProfile();
    },
  );

  List<Widget> _buildActivityServiceCards() {
    if (_role == UserRole.coach) {
      return [
        _ProfileMenuTile(
          icon: Icons.groups_outlined,
          title: 'Hội viên đang phụ trách',
          onTap: () => _navigateOrPushWidget(route: '/coach/features/members'),
        ),
        _ProfileMenuTile(
          icon: Icons.calendar_month_rounded,
          title: 'Lịch dạy & giáo trình',
          onTap: () => _navigateOrPushWidget(route: '/coach/features/sessions'),
        ),
        _ProfileMenuTile(
          icon: Icons.notifications_none_rounded,
          title: 'Thông báo',
          onTap: _openCoachNotifications,
        ),
      ];
    }
    return [
      _ProfileMenuTile(
        icon: Icons.menu_book_rounded,
        title: 'Nhật ký tập luyện & số đo',
        onTap: () => _navigateOrPushWidget(
          route: '/member/features/workouts',
          fallbackPage: const MemberJournalPage(),
        ),
      ),
      _ProfileMenuTile(
        icon: Icons.calendar_month_rounded,
        title: 'Coach & lịch hẹn',
        onTap: () => _navigateOrPushWidget(route: '/member/features/sessions'),
      ),
      _ProfileMenuTile(
        icon: Icons.notifications_none_rounded,
        title: 'Thông báo',
        onTap: _openCoachNotifications,
      ),
    ];
  }

  void _openCoachNotifications() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const CoachNotificationsPage()),
    );
  }

  Widget _buildSecurityMenuCard() => _ProfileMenuTile(
    icon: Icons.shield_outlined,
    title: 'Bảo mật & tài khoản',
    onTap: _openSecurityAccountPage,
  );

  Widget _buildPrivacyMenuCard() => _ProfileMenuTile(
    icon: Icons.lock_person_outlined,
    title: 'Quyền riêng tư',
    onTap: _openPrivacySettingsPage,
  );

  Widget _buildAppSettingsMenuCard() => _ProfileMenuTile(
    icon: Icons.tune_rounded,
    title: 'Cài đặt ứng dụng',
    onTap: _openAppSettingsPage,
  );

  Widget _buildSupportInfoMenuCard() => _ProfileMenuTile(
    icon: Icons.support_agent_rounded,
    title: 'Phòng tập & hỗ trợ',
    onTap: _openSupportInfoPage,
  );

  Future<void> _openPrivacySettingsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PrivacySettingsDetailPage(
          accessMode: _photoAccessMode,
          shareJournalWithCoach: _shareJournalWithCoach,
          shareMeasurementsWithCoach: _shareMeasurementsWithCoach,
          onSave: (newMode, shareJournal, shareMeasurements) async {
            if (!MetaGymTheme.isFlutterTestEnvironment) {
              try {
                await _secureStorage.write(
                  key: _permissionStorageKey,
                  value: newMode.name,
                );
              } catch (_) {}
            }
            if (!mounted) return;
            setState(() {
              _photoAccessMode = newMode;
              _shareJournalWithCoach = shareJournal;
              _shareMeasurementsWithCoach = shareMeasurements;
            });
            _showToast('Đã cập nhật cài đặt quyền riêng tư');
          },
        ),
      ),
    );
  }

  Future<void> _openAppSettingsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AppSettingsDetailPage(
          unitSystem: _unitSystem,
          workoutReminderEnabled: _workoutReminderEnabled,
          reminderTime: _reminderTime,
          onSave: (unit, reminderEnabled, time) {
            setState(() {
              _unitSystem = unit;
              _workoutReminderEnabled = reminderEnabled;
              _reminderTime = time;
            });
            _showToast('Đã lưu cài đặt ứng dụng');
          },
        ),
      ),
    );
  }

  Future<void> _openSupportInfoPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _SupportInfoDetailPage(onShowToast: _showToast),
      ),
    );
  }

  Future<void> _openPersonalInfoPage() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PersonalInfoDetailPage(
          fullName: _fullName,
          phone: _phone,
          dateOfBirth: _dateOfBirth,
          gender: _gender,
          role: _role,
          initials: _initials,
          avatarBytes: _avatarBytes,
          allowedPhotos: _allowedPhotoBytes,
          accessMode: _photoAccessMode,
          onSave: (patch, newAvatar, newAllowedPhotos, newAccessMode) async {
            setState(() {
              _fullName = patch['fullName'] as String? ?? _fullName;
              _phone = patch['phone'] as String? ?? _phone;
              if (patch['dateOfBirth'] != null) {
                _dateOfBirth = patch['dateOfBirth'] as String;
              }
              if (patch['gender'] != null) {
                _gender = patch['gender'] as String;
              }
              _avatarBytes = newAvatar;
              _allowedPhotoBytes = newAllowedPhotos;
              _photoAccessMode = newAccessMode;
            });
            await _saveAvatarToStorage(newAvatar, newAccessMode);
            return _persistPatch(
              patch,
              successMessage: 'Đã lưu thông tin cá nhân & ảnh đại diện',
            );
          },
          onRequestPermission: _requestNativePhotoPermission,
          onLoadNativePhotos: _loadNativeGrantedPhotos,
          onShowToast: _showToast,
        ),
      ),
    );
    if (updated == true && mounted) {
      _reloadProfile();
    }
  }

  Future<void> _openTrainingProfilePage() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _TrainingProfileDetailPage(
          fitnessGoal: _fitnessGoal,
          heightCm: _heightCm,
          experienceLevel: _experienceLevel,
          activityLevel: _activityLevel,
          onSave: (goal, height, exp, act) async {
            setState(() {
              _fitnessGoal = goal;
              _heightCm = height;
              _experienceLevel = exp;
              _activityLevel = act;
            });
            return _persistPatch({
              'fitnessGoal': goal,
              'heightCm': double.parse(height.toStringAsFixed(1)),
              'experienceLevel': exp,
              'activityLevel': act,
            }, successMessage: 'Đã lưu thể trạng & mục tiêu tập luyện');
          },
        ),
      ),
    );
  }

  Future<void> _openHealthNutritionPage() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _HealthNutritionDetailPage(
          healthNotes: _healthNotes,
          injuryNotes: _injuryNotes,
          dietaryPreferences: _dietaryPreferences,
          onSave: (health, injury, diet) async {
            setState(() {
              _healthNotes = health;
              _injuryNotes = injury;
              _dietaryPreferences = diet;
            });
            return _persistPatch({
              'healthNotes': health,
              'injuryNotes': injury,
              'dietaryPreferences': diet,
            }, successMessage: 'Đã lưu thông tin sức khỏe & dinh dưỡng');
          },
        ),
      ),
    );
  }

  Future<void> _openSecurityAccountPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _SecurityAccountDetailPage(
          email: _email,
          status: _status,
          roleLabel: _roleLabel,
          onChangePassword: (oldPass, newPass) async {
            final controller = context.read<ProfileController?>();
            if (controller == null) return false;
            final ok = await controller.changePassword(
              currentPassword: oldPass,
              newPassword: newPass,
            );
            return ok;
          },
          onSignOut: _confirmSignOut,
          onShowToast: _showToast,
        ),
      ),
    );
  }

  Future<void> _openCoachProfilePage() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _CoachProfileDetailPage(
          biography: _biography,
          specialties: _specialties,
          qualifications: _qualifications,
          experienceYears: _experienceYears,
          availabilityNote: _availabilityNote,
          onSave: (bio, specs, qual, years, avail) async {
            setState(() {
              _biography = bio;
              _specialties = specs;
              _qualifications = qual;
              _experienceYears = years;
              _availabilityNote = avail;
            });
            return _persistPatch({
              'biography': bio,
              'specialties': specs,
              'qualifications': qual,
              'experienceYears': years,
              'availabilityNote': avail,
            }, successMessage: 'Đã lưu hồ sơ chuyên môn huấn luyện viên');
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. BOTTOM SHEETS CHỈNH SỬA (GỌI THẬT PATCH /users/me & PATCH /users/me/password)
  // ===========================================================================
  static String _photoAccessModeLabel(_PhotoAccessMode mode) {
    switch (mode) {
      case _PhotoAccessMode.full:
        return 'Cho phép truy cập đầy đủ';
      case _PhotoAccessMode.selectedOnly:
        return 'Hạn chế quyền truy cập Ảnh và video';
      case _PhotoAccessMode.denied:
        return 'Không cho phép';
      case _PhotoAccessMode.unset:
        return 'Chưa cấp quyền truy cập ảnh';
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF162232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF453A),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<SessionController?>()?.signOut();
      } catch (_) {
        _showToast('Đã đăng xuất (chế độ xem trước)');
      }
    }
  }
}

InputDecoration _sheetInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFFB7B2AF), fontSize: 13),
    filled: true,
    fillColor: const Color(0x80211E1C),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x9A8C8176)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x9A8C8176)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.4),
    ),
  );
}

// =============================================================================
// CÁC COMPONENT LẤY CHÍNH XÁC TỪ member_dashboard_view.dart
// =============================================================================

class _ProfileGymBackground extends StatelessWidget {
  const _ProfileGymBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: _ProfilePageState._gymBannerAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: MetaGymTheme.darkCanvas),
          ),
          // Ambient depth lights: Cool blue top-right, warm orange bottom-left
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.85, -0.75),
                radius: 0.9,
                colors: [Color(0x2E8EB9E5), Colors.transparent],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.85, 0.75),
                radius: 0.8,
                colors: [Color(0x24FF5A36), Colors.transparent],
              ),
            ),
          ),
          // Scrim đồng bộ chính xác với member_dashboard_view.dart
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x9E0F1115),
                  Color(0x900F1115),
                  Color(0xAA0F1115),
                ],
                stops: [0.0, 0.48, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Giống chính xác `_buildMembershipGlassCard` trong `member_dashboard_view.dart`.
class _MembershipGlassCard extends StatelessWidget {
  const _MembershipGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    final surface = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xCD342D28), Color(0xC829241F)],
        ),
        borderRadius: radius,
        border: Border.all(color: const Color(0xB7B3A99D), width: 1.2),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 20,
            right: 20,
            top: 0,
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: Color(0x75FFF5E9)),
            ),
          ),
          child,
        ],
      ),
    );
    if (MediaQuery.disableAnimationsOf(context) ||
        MetaGymTheme.isFlutterTestEnvironment) {
      return surface;
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: surface,
        ),
      ),
    );
  }
}

/// Giống chính xác `_buildLiquidGlassCard` trong `member_dashboard_view.dart`.
class _DashboardGlassCard extends StatelessWidget {
  const _DashboardGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MetaGymTheme.radiusCard);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xC42B2622),
        borderRadius: radius,
        border: Border.all(color: const Color(0xA3A79D92), width: 1.1),
      ),
      child: child,
    );
  }
}

/// Giống chính xác `_CircleHeaderGlassButton` trong `member_dashboard_view.dart`.
class _CircleHeaderGlassButton extends StatelessWidget {
  const _CircleHeaderGlassButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x9E2F2924),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x95ADA295),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: MetaGymTheme.darkTextPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCategoryCard extends StatelessWidget {
  const _ProfileCategoryCard({
    required this.title,
    required this.icon,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final IconData icon;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MetaGymTheme.radiusCard);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xE12B2622),
        borderRadius: radius,
        border: Border.all(color: const Color(0xA3A79D92), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 76),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0x803D3029),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0x668C8176)),
                        ),
                        child: Icon(
                          icon,
                          color: MetaGymTheme.brandOrange,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: MetaGymTheme.darkTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count mục',
                              style: const TextStyle(
                                color: Color(0xFFB8B0A8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFFB8C2D0),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Color(0x668C8176),
            ),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1)
                const Divider(
                  height: 1,
                  indent: 58,
                  endIndent: 16,
                  color: Color(0x448C8176),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFA9C7E8), size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFEDE9E5),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF9EA8B5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubPageScaffold extends StatelessWidget {
  const _SubPageScaffold({
    required this.eyebrow,
    required this.title,
    required this.body,
    this.bottomBar,
  });

  final String eyebrow;
  final String title;
  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: _ProfileGymBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      _CircleHeaderGlassButton(
                        icon: Icons.arrow_back_rounded,
                        semanticLabel: 'Quay lại',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eyebrow.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    child: body,
                  ),
                ),
                if (bottomBar != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: bottomBar!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Color(0xFFF7F9FC), fontSize: 14),
      decoration: _sheetInputDecoration(label),
    );
  }
}

class _SheetChoiceChip extends StatelessWidget {
  const _SheetChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x38FF5A36) : const Color(0x80211E1C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? MetaGymTheme.brandOrange
                : const Color(0x9A8C8176),
            width: selected ? 1.3 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFF7F9FC) : const Color(0xFFEAE6E2),
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CÁC MÀN HÌNH CHI TIẾT TÙY CHỈNH HỒ SƠ (NAVIGATOR PUSH SUB-PAGES)
// =============================================================================

class _PersonalInfoDetailPage extends StatefulWidget {
  const _PersonalInfoDetailPage({
    required this.fullName,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.role,
    required this.initials,
    required this.avatarBytes,
    required this.allowedPhotos,
    required this.accessMode,
    required this.onSave,
    required this.onRequestPermission,
    required this.onLoadNativePhotos,
    required this.onShowToast,
  });

  final String fullName;
  final String phone;
  final String dateOfBirth;
  final String gender;
  final UserRole role;
  final String initials;
  final Uint8List? avatarBytes;
  final List<Uint8List> allowedPhotos;
  final _PhotoAccessMode accessMode;
  final Future<bool> Function(
    Map<String, dynamic> patch,
    Uint8List? newAvatar,
    List<Uint8List> newAllowedPhotos,
    _PhotoAccessMode newAccessMode,
  )
  onSave;
  final Future<_PhotoAccessMode> Function() onRequestPermission;
  final Future<List<Uint8List>> Function() onLoadNativePhotos;
  final void Function(String message, {bool isError}) onShowToast;

  @override
  State<_PersonalInfoDetailPage> createState() =>
      _PersonalInfoDetailPageState();
}

class _PersonalInfoDetailPageState extends State<_PersonalInfoDetailPage> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.fullName,
  );
  late final TextEditingController _phoneCtrl = TextEditingController(
    text: widget.phone,
  );
  late String _dob = widget.dateOfBirth;
  late String _gender = widget.gender;
  late Uint8List? _avatar = widget.avatarBytes;
  late List<Uint8List> _allowedPhotos = List<Uint8List>.from(
    widget.allowedPhotos,
  );
  late _PhotoAccessMode _accessMode = widget.accessMode;
  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAvatarUpload() async {
    final chosenMode = await widget.onRequestPermission();
    if (!mounted) return;
    setState(() => _accessMode = chosenMode);

    if (chosenMode == _PhotoAccessMode.denied) {
      setState(() => _allowedPhotos = []);
      widget.onShowToast('Đã từ chối quyền truy cập ảnh', isError: true);
      return;
    }

    try {
      if (chosenMode == _PhotoAccessMode.selectedOnly) {
        final nativePhotos = await widget.onLoadNativePhotos();
        if (nativePhotos.isNotEmpty) {
          if (mounted) {
            setState(() {
              _allowedPhotos = nativePhotos;
              _avatar = nativePhotos.first;
            });
          }
          return;
        }
        final files = await _imagePicker.pickMultiImage(
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (files.isEmpty) return;
        final pickedBytesList = <Uint8List>[];
        for (final f in files) {
          pickedBytesList.add(await f.readAsBytes());
        }
        if (mounted) {
          setState(() {
            _allowedPhotos = pickedBytesList;
            _avatar = pickedBytesList.first;
          });
        }
      } else {
        final file = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() => _avatar = bytes);
        }
      }
    } catch (_) {
      widget.onShowToast(
        'Không thể mở thư viện ảnh trên thiết bị. Vui lòng kiểm tra quyền ứng dụng.',
        isError: true,
      );
    }
  }

  Future<void> _handleSave() async {
    final trimmedName = _nameCtrl.text.trim();
    if (trimmedName.length < 2) {
      widget.onShowToast('Họ và tên cần ít nhất 2 ký tự', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    final patch = <String, dynamic>{
      'fullName': trimmedName,
      'phone': _phoneCtrl.text.trim(),
      if (widget.role == UserRole.member) ...{
        'dateOfBirth': _dob,
        'gender': _gender,
      },
    };
    final ok = await widget.onSave(patch, _avatar, _allowedPhotos, _accessMode);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      eyebrow: 'Hồ sơ cá nhân',
      title: 'Thông tin cá nhân',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _handleAvatarUpload,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: MetaGymTheme.coachAvatarBackground,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: MetaGymTheme.brandOrange,
                                  width: 1.6,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: _avatar != null
                                  ? ClipOval(
                                      child: Image.memory(
                                        _avatar!,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Text(
                                      widget.initials,
                                      style: const TextStyle(
                                        color:
                                            MetaGymTheme.coachAvatarForeground,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: MetaGymTheme.brandOrange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF282320),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ảnh đại diện (Avatar)',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _ProfilePageState._photoAccessModeLabel(
                                _accessMode,
                              ),
                              style: const TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _handleAvatarUpload,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x26FF5A36),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: MetaGymTheme.brandOrange,
                                    width: 0.8,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_library_outlined,
                                      size: 14,
                                      color: MetaGymTheme.brandOrange,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tải ảnh từ điện thoại',
                                      style: TextStyle(
                                        color: MetaGymTheme.brandOrange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_allowedPhotos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(
                      height: 1,
                      thickness: 0.6,
                      color: Color(0x389A8C81),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ảnh đã cấp quyền trên thiết bị:',
                      style: TextStyle(
                        color: Color(0xFFB7B2AF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _allowedPhotos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final photoBytes = _allowedPhotos[i];
                          final isSelected = _avatar == photoBytes;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _avatar = photoBytes);
                            },
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSelected
                                      ? MetaGymTheme.brandOrange
                                      : const Color(0x559A8C81),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  photoBytes,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetTextField(controller: _nameCtrl, label: 'Họ và tên'),
                  const SizedBox(height: 14),
                  _SheetTextField(
                    controller: _phoneCtrl,
                    label: 'Số điện thoại',
                    keyboardType: TextInputType.phone,
                  ),
                  if (widget.role == UserRole.member) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () async {
                        final initialDate =
                            DateTime.tryParse(_dob) ?? DateTime(2000);
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: initialDate,
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: MetaGymTheme.brandOrange,
                                surface: Color(0xFF282320),
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          final str = picked.toIso8601String().substring(0, 10);
                          setState(() => _dob = str);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x80211E1C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x9A8C8176)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ngày sinh',
                                    style: TextStyle(
                                      color: Color(0xFFB7B2AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _dob.isNotEmpty ? _dob : 'Chưa cập nhật',
                                    style: TextStyle(
                                      color: _dob.isNotEmpty
                                          ? const Color(0xFFF7F9FC)
                                          : const Color(0xFF8E8A86),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: Color(0xFFB7B2AF),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Giới tính',
                      style: TextStyle(
                        color: Color(0xFFEAE6E2),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final code in [
                          'MALE',
                          'FEMALE',
                          'OTHER',
                          'PREFER_NOT_TO_SAY',
                        ])
                          _SheetChoiceChip(
                            label: _ProfilePageState._genderLabel(code),
                            selected: _gender == code,
                            onTap: () => setState(() => _gender = code),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: Text(
            _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _TrainingProfileDetailPage extends StatefulWidget {
  const _TrainingProfileDetailPage({
    required this.fitnessGoal,
    required this.heightCm,
    required this.experienceLevel,
    required this.activityLevel,
    required this.onSave,
  });

  final String fitnessGoal;
  final double heightCm;
  final String experienceLevel;
  final String activityLevel;
  final Future<bool> Function(
    String goal,
    double height,
    String experience,
    String activity,
  )
  onSave;

  @override
  State<_TrainingProfileDetailPage> createState() =>
      _TrainingProfileDetailPageState();
}

class _TrainingProfileDetailPageState
    extends State<_TrainingProfileDetailPage> {
  late final TextEditingController _goalCtrl = TextEditingController(
    text: widget.fitnessGoal,
  );
  late double _height = widget.heightCm;
  late String _experience = widget.experienceLevel;
  late String _activity = widget.activityLevel;
  bool _isSaving = false;

  static const _goalPresets = [
    'Tăng cơ giảm mỡ · Duy trì 4 buổi/tuần',
    'Giảm mỡ siết cơ · Cardio & HIIT',
    'Tăng sức mạnh tối đa (Strength & Power)',
    'Cải thiện sức bền & Phục hồi vận động',
  ];

  @override
  void dispose() {
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final nextGoal = _goalCtrl.text.trim().isNotEmpty
        ? _goalCtrl.text.trim()
        : widget.fitnessGoal;
    final ok = await widget.onSave(nextGoal, _height, _experience, _activity);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      eyebrow: 'Hồ sơ cá nhân',
      title: 'Thể trạng & Mục tiêu',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetTextField(
                    controller: _goalCtrl,
                    label: 'Mục tiêu tập luyện',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final preset in _goalPresets)
                        _SheetChoiceChip(
                          label: preset,
                          selected: _goalCtrl.text.trim() == preset,
                          onTap: () => setState(() => _goalCtrl.text = preset),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chiều cao',
                        style: TextStyle(
                          color: Color(0xFFEAE6E2),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_height.round()} cm',
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: MetaGymTheme.brandOrange,
                      inactiveTrackColor: const Color(0x26FFFFFF),
                      thumbColor: MetaGymTheme.brandOrange,
                      overlayColor: const Color(0x29FF5A36),
                    ),
                    child: Slider(
                      value: _height.clamp(120, 220),
                      min: 120,
                      max: 220,
                      divisions: 100,
                      onChanged: (v) => setState(() => _height = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trình độ tập luyện',
                    style: TextStyle(
                      color: Color(0xFFEAE6E2),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final code in [
                        'BEGINNER',
                        'INTERMEDIATE',
                        'ADVANCED',
                      ])
                        _SheetChoiceChip(
                          label: _ProfilePageState._experienceLabel(code),
                          selected: _experience == code,
                          onTap: () => setState(() => _experience = code),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Mức độ vận động hàng ngày',
                    style: TextStyle(
                      color: Color(0xFFEAE6E2),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final code in ['LOW', 'MODERATE', 'HIGH'])
                        _SheetChoiceChip(
                          label: _ProfilePageState._activityLabel(code),
                          selected: _activity == code,
                          onTap: () => setState(() => _activity = code),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: Text(
            _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _HealthNutritionDetailPage extends StatefulWidget {
  const _HealthNutritionDetailPage({
    required this.healthNotes,
    required this.injuryNotes,
    required this.dietaryPreferences,
    required this.onSave,
  });

  final String healthNotes;
  final String injuryNotes;
  final String dietaryPreferences;
  final Future<bool> Function(String health, String injury, String diet) onSave;

  @override
  State<_HealthNutritionDetailPage> createState() =>
      _HealthNutritionDetailPageState();
}

class _HealthNutritionDetailPageState
    extends State<_HealthNutritionDetailPage> {
  late final TextEditingController _healthCtrl = TextEditingController(
    text: widget.healthNotes,
  );
  late final TextEditingController _injuryCtrl = TextEditingController(
    text: widget.injuryNotes,
  );
  late final TextEditingController _dietCtrl = TextEditingController(
    text: widget.dietaryPreferences,
  );
  bool _isSaving = false;

  @override
  void dispose() {
    _healthCtrl.dispose();
    _injuryCtrl.dispose();
    _dietCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final nextHealth = _healthCtrl.text.trim().isNotEmpty
        ? _healthCtrl.text.trim()
        : 'Không có lưu ý đặc biệt';
    final nextInjury = _injuryCtrl.text.trim().isNotEmpty
        ? _injuryCtrl.text.trim()
        : 'Không có chấn thương';
    final nextDiet = _dietCtrl.text.trim().isNotEmpty
        ? _dietCtrl.text.trim()
        : 'Ăn uống cân bằng';
    final ok = await widget.onSave(nextHealth, nextInjury, nextDiet);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      eyebrow: 'Hồ sơ cá nhân',
      title: 'Sức khỏe & Chấn thương',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x262ECC71),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x4D2ECC71), width: 0.8),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: MetaGymTheme.progressGreen,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chỉ bạn và Huấn luyện viên phụ trách mới có quyền xem thông tin sức khỏe này.',
                    style: TextStyle(
                      color: Color(0xFFEAE6E2),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetTextField(
                    controller: _healthCtrl,
                    label: 'Tình trạng sức khỏe (huyết áp, tim mạch...)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  _SheetTextField(
                    controller: _injuryCtrl,
                    label: 'Chấn thương hoặc hạn chế vận động',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  _SheetTextField(
                    controller: _dietCtrl,
                    label: 'Sở thích ăn uống / Dị ứng thực phẩm',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: Text(
            _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _SecurityAccountDetailPage extends StatefulWidget {
  const _SecurityAccountDetailPage({
    required this.email,
    required this.status,
    required this.roleLabel,
    required this.onChangePassword,
    required this.onSignOut,
    required this.onShowToast,
  });

  final String email;
  final String status;
  final String roleLabel;
  final Future<bool> Function(String oldPassword, String newPassword)
  onChangePassword;
  final VoidCallback onSignOut;
  final void Function(String message, {bool isError}) onShowToast;

  @override
  State<_SecurityAccountDetailPage> createState() =>
      _SecurityAccountDetailPageState();
}

class _SecurityAccountDetailPageState
    extends State<_SecurityAccountDetailPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _errorText;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordChange() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;
    final valid =
        next.length >= 8 &&
        RegExp(r'[a-z]').hasMatch(next) &&
        RegExp(r'[A-Z]').hasMatch(next) &&
        RegExp(r'[0-9]').hasMatch(next);

    if (current.isEmpty) {
      setState(() => _errorText = 'Vui lòng nhập mật khẩu hiện tại');
      return;
    }
    if (!valid) {
      setState(
        () => _errorText =
            'Mật khẩu mới cần ít nhất 8 ký tự, có chữ hoa, chữ thường và số',
      );
      return;
    }
    if (next != confirm) {
      setState(() => _errorText = 'Mật khẩu xác nhận không trùng khớp');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final ok = await widget.onChangePassword(current, next);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      widget.onShowToast('Đã đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
      Navigator.of(context).pop();
    } else {
      setState(
        () => _errorText =
            'Không thể đổi mật khẩu. Vui lòng kiểm tra lại mật khẩu hiện tại.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      eyebrow: 'Tài khoản & Thiết bị',
      title: 'Bảo mật & Tài khoản',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thông tin tài khoản',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Email đăng nhập',
                        style: TextStyle(
                          color: Color(0xFFB7B2AF),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        widget.email.isNotEmpty
                            ? widget.email
                            : 'member@metagym.vn',
                        style: const TextStyle(
                          color: Color(0xFFF7F9FC),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Trạng thái tài khoản',
                        style: TextStyle(
                          color: Color(0xFFB7B2AF),
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.status == 'ACTIVE'
                                  ? MetaGymTheme.progressGreen
                                  : MetaGymTheme.warningAmber,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.status == 'ACTIVE'
                                ? 'Đang hoạt động'
                                : 'Chờ kích hoạt',
                            style: const TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Vai trò',
                        style: TextStyle(
                          color: Color(0xFFB7B2AF),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        widget.roleLabel,
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đổi mật khẩu',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mật khẩu mới dài ít nhất 8 ký tự, có chữ hoa, chữ thường và chữ số.',
                    style: TextStyle(color: Color(0xFFB7B2AF), fontSize: 11.5),
                  ),
                  const SizedBox(height: 14),
                  _SheetTextField(
                    controller: _currentCtrl,
                    label: 'Mật khẩu hiện tại',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _SheetTextField(
                    controller: _newCtrl,
                    label: 'Mật khẩu mới',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _SheetTextField(
                    controller: _confirmCtrl,
                    label: 'Xác nhận mật khẩu mới',
                    obscureText: true,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: Color(0xFFF15B64),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: MetaGymTheme.brandOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _handlePasswordChange,
                      child: Text(
                        _isSaving ? 'Đang cập nhật...' : 'Cập nhật mật khẩu',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFFF6961),
                    size: 18,
                  ),
                  label: const Text(
                    'Đăng xuất khỏi thiết bị này',
                    style: TextStyle(
                      color: Color(0xFFFF6961),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0x55FF6961)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: widget.onSignOut,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachProfileDetailPage extends StatefulWidget {
  const _CoachProfileDetailPage({
    required this.biography,
    required this.specialties,
    required this.qualifications,
    required this.experienceYears,
    required this.availabilityNote,
    required this.onSave,
  });

  final String biography;
  final List<String> specialties;
  final String qualifications;
  final int experienceYears;
  final String availabilityNote;
  final Future<bool> Function(
    String bio,
    List<String> specs,
    String qual,
    int years,
    String avail,
  )
  onSave;

  @override
  State<_CoachProfileDetailPage> createState() =>
      _CoachProfileDetailPageState();
}

class _CoachProfileDetailPageState extends State<_CoachProfileDetailPage> {
  late final TextEditingController _bioCtrl = TextEditingController(
    text: widget.biography,
  );
  late final TextEditingController _specsCtrl = TextEditingController(
    text: widget.specialties.join(', '),
  );
  late final TextEditingController _qualCtrl = TextEditingController(
    text: widget.qualifications,
  );
  late final TextEditingController _availCtrl = TextEditingController(
    text: widget.availabilityNote,
  );
  late int _years = widget.experienceYears;
  bool _isSaving = false;

  @override
  void dispose() {
    _bioCtrl.dispose();
    _specsCtrl.dispose();
    _qualCtrl.dispose();
    _availCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final parsedSpecs = _specsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(20)
        .toList();
    final nextBio = _bioCtrl.text.trim().isNotEmpty
        ? _bioCtrl.text.trim()
        : widget.biography;
    final nextQual = _qualCtrl.text.trim().isNotEmpty
        ? _qualCtrl.text.trim()
        : widget.qualifications;
    final nextAvail = _availCtrl.text.trim().isNotEmpty
        ? _availCtrl.text.trim()
        : widget.availabilityNote;
    final nextSpecs = parsedSpecs.isNotEmpty ? parsedSpecs : widget.specialties;

    final ok = await widget.onSave(
      nextBio,
      nextSpecs,
      nextQual,
      _years,
      nextAvail,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      eyebrow: 'Hồ sơ Huấn luyện viên',
      title: 'Chuyên môn & Lịch dạy',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetTextField(
                    controller: _bioCtrl,
                    label: 'Giới thiệu bản thân (Bio)',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  _SheetTextField(
                    controller: _specsCtrl,
                    label: 'Chuyên môn (phân tách bằng dấu phẩy)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  _SheetTextField(
                    controller: _qualCtrl,
                    label: 'Chứng chỉ / Bằng cấp',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Số năm kinh nghiệm',
                        style: TextStyle(
                          color: Color(0xFFEAE6E2),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$_years năm',
                        style: const TextStyle(
                          color: MetaGymTheme.brandOrange,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: MetaGymTheme.brandOrange,
                      inactiveTrackColor: const Color(0x26FFFFFF),
                      thumbColor: MetaGymTheme.brandOrange,
                      overlayColor: const Color(0x29FF5A36),
                    ),
                    child: Slider(
                      value: _years.toDouble().clamp(0, 40),
                      min: 0,
                      max: 40,
                      divisions: 40,
                      onChanged: (v) => setState(() => _years = v.round()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SheetTextField(
                    controller: _availCtrl,
                    label: 'Khung giờ dạy & Lưu ý lịch',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: Text(
            _isSaving ? 'Đang lưu...' : 'Lưu hồ sơ Huấn luyện viên',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _PrivacySettingsDetailPage extends StatefulWidget {
  const _PrivacySettingsDetailPage({
    required this.accessMode,
    required this.shareJournalWithCoach,
    required this.shareMeasurementsWithCoach,
    required this.onSave,
  });

  final _PhotoAccessMode accessMode;
  final bool shareJournalWithCoach;
  final bool shareMeasurementsWithCoach;
  final Future<void> Function(
    _PhotoAccessMode mode,
    bool shareJournal,
    bool shareMeasurements,
  )
  onSave;

  @override
  State<_PrivacySettingsDetailPage> createState() =>
      _PrivacySettingsDetailPageState();
}

class _PrivacySettingsDetailPageState
    extends State<_PrivacySettingsDetailPage> {
  late _PhotoAccessMode _mode = widget.accessMode;
  late bool _shareJournal = widget.shareJournalWithCoach;
  late bool _shareMeasurements = widget.shareMeasurementsWithCoach;
  bool _saving = false;

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    await widget.onSave(_mode, _shareJournal, _shareMeasurements);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      eyebrow: 'Bảo vệ dữ liệu',
      title: 'Quyền riêng tư & Chia sẻ',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chia sẻ tiến độ với Huấn luyện viên',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: MetaGymTheme.brandOrange,
                    title: const Text(
                      'Nhật ký tập luyện hằng ngày',
                      style: TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: const Text(
                      'Cho phép Coach xem lịch sử bài tập & cảm nhận buổi tập',
                      style: TextStyle(color: Color(0xFFB7B2AF), fontSize: 12),
                    ),
                    value: _shareJournal,
                    onChanged: (v) => setState(() => _shareJournal = v),
                  ),
                  const Divider(color: Color(0x389A8C81), height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: MetaGymTheme.brandOrange,
                    title: const Text(
                      'Số đo 3 vòng & Cân nặng',
                      style: TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: const Text(
                      'Đồng bộ số đo cơ thể để Coach điều chỉnh giáo trình',
                      style: TextStyle(color: Color(0xFFB7B2AF), fontSize: 12),
                    ),
                    value: _shareMeasurements,
                    onChanged: (v) => setState(() => _shareMeasurements = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quyền truy cập thư viện ảnh',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final option in _PhotoAccessMode.values)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _mode = option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _mode == option
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 20,
                              color: _mode == option
                                  ? MetaGymTheme.brandOrange
                                  : const Color(0xFFB7B2AF),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _ProfilePageState._photoAccessModeLabel(option),
                                style: const TextStyle(
                                  color: Color(0xFFF7F9FC),
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _saving ? null : _handleSave,
          child: Text(
            _saving ? 'Đang lưu...' : 'Lưu cài đặt quyền riêng tư',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _AppSettingsDetailPage extends StatefulWidget {
  const _AppSettingsDetailPage({
    required this.unitSystem,
    required this.workoutReminderEnabled,
    required this.reminderTime,
    required this.onSave,
  });

  final String unitSystem;
  final bool workoutReminderEnabled;
  final String reminderTime;
  final void Function(String unit, bool reminderEnabled, String time) onSave;

  @override
  State<_AppSettingsDetailPage> createState() => _AppSettingsDetailPageState();
}

class _AppSettingsDetailPageState extends State<_AppSettingsDetailPage> {
  late String _unit = widget.unitSystem;
  late bool _reminderEnabled = widget.workoutReminderEnabled;
  late String _time = widget.reminderTime;

  static const _timeOptions = ['06:30', '17:30', '18:00', '19:30'];

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      eyebrow: 'Tùy chỉnh trải nghiệm',
      title: 'Cài đặt ứng dụng',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hệ đơn vị đo lường',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final unit in const ['cm / kg', 'inch / lbs']) ...[
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _unit = unit),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _unit == unit
                                    ? MetaGymTheme.brandOrange.withValues(
                                        alpha: 0.2,
                                      )
                                    : const Color(0x66211E1C),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _unit == unit
                                      ? MetaGymTheme.brandOrange
                                      : const Color(0x55A79D92),
                                ),
                              ),
                              child: Text(
                                unit,
                                style: TextStyle(
                                  color: _unit == unit
                                      ? MetaGymTheme.brandOrange
                                      : const Color(0xFFF7F9FC),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (unit == 'cm / kg') const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeTrackColor: MetaGymTheme.brandOrange,
                    title: const Text(
                      'Nhắc lịch tập hằng ngày',
                      style: TextStyle(
                        color: Color(0xFFF7F9FC),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Gửi thông báo nhắc chuẩn bị trước giờ tập',
                      style: TextStyle(color: Color(0xFFB7B2AF), fontSize: 12),
                    ),
                    value: _reminderEnabled,
                    onChanged: (v) => setState(() => _reminderEnabled = v),
                  ),
                  if (_reminderEnabled) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Khung giờ nhắc',
                      style: TextStyle(
                        color: Color(0xFFB7B2AF),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final t in _timeOptions)
                          ChoiceChip(
                            label: Text(t),
                            selected: _time == t,
                            selectedColor: MetaGymTheme.brandOrange.withValues(
                              alpha: 0.25,
                            ),
                            backgroundColor: const Color(0x66211E1C),
                            labelStyle: TextStyle(
                              color: _time == t
                                  ? MetaGymTheme.brandOrange
                                  : const Color(0xFFF7F9FC),
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: _time == t
                                  ? MetaGymTheme.brandOrange
                                  : const Color(0x55A79D92),
                            ),
                            onSelected: (_) => setState(() => _time = t),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () {
            widget.onSave(_unit, _reminderEnabled, _time);
            Navigator.of(context).pop();
          },
          child: const Text(
            'Lưu cài đặt',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _SupportInfoDetailPage extends StatelessWidget {
  const _SupportInfoDetailPage({required this.onShowToast});

  final void Function(String message) onShowToast;

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      eyebrow: 'Meta Gym Center',
      title: 'Thông tin phòng tập & Hỗ trợ',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Thông tin cơ sở chính',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  _InfoKeyValueRow(
                    label: 'Giờ mở cửa',
                    value: '05:30 – 22:00 (Thứ 2 – CN)',
                  ),
                  SizedBox(height: 8),
                  _InfoKeyValueRow(label: 'Hotline hỗ trợ', value: '1900 6868'),
                  SizedBox(height: 8),
                  _InfoKeyValueRow(
                    label: 'Email CSKH',
                    value: 'support@metagym.vn',
                  ),
                  SizedBox(height: 8),
                  _InfoKeyValueRow(
                    label: 'Địa chỉ',
                    value: 'Tầng 3, Meta Complex, Q.1, TP.HCM',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DashboardGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nội quy & Thông tin ứng dụng',
                    style: TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '• Mang giày tập chuyên dụng và khăn cá nhân khi vào khu vực máy.\n'
                    '• Quét mã QR tại quầy lễ tân trước mỗi buổi tập để tích lũy lịch sử.\n'
                    '• Đặt tạ về đúng giá sau khi hoàn thành bài tập.',
                    style: TextStyle(
                      color: Color(0xFFB7B2AF),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _InfoKeyValueRow(
                    label: 'Phiên bản ứng dụng',
                    value: 'Meta Gym v1.0.0',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MetaGymTheme.brandOrange,
                        side: const BorderSide(color: MetaGymTheme.brandOrange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        onShowToast(
                          'Đã gửi yêu cầu hỗ trợ tới bộ phận CSKH Meta Gym',
                        );
                      },
                      icon: const Icon(Icons.headset_mic_outlined, size: 18),
                      label: const Text(
                        'Liên hệ bộ phận hỗ trợ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoKeyValueRow extends StatelessWidget {
  const _InfoKeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB7B2AF), fontSize: 13),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFF7F9FC),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
