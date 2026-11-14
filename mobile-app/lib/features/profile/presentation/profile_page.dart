import 'dart:convert' show base64Decode, base64Encode;
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
  final ImagePicker _imagePicker = ImagePicker();

  bool _initialized = false;
  VoidCallback? _activeSectionRefresh;

  // Trạng thái Avatar & Quyền truy cập ảnh
  Uint8List? _avatarBytes;
  List<Uint8List> _allowedPhotoBytes = const [];
  _PhotoAccessMode _photoAccessMode = _PhotoAccessMode.unset;

  // Trạng thái đồng bộ với `/users/me`
  String _fullName = '';
  String _email = '';
  String _phone = '';
  UserRole _role = UserRole.member;
  String _status = 'ACTIVE';

  // Trường dành cho Hội viên (`member_profiles`)
  String _dateOfBirth = '1999-08-15';
  String _gender = 'MALE';
  double _heightCm = 174;
  String _fitnessGoal = 'Tăng cơ giảm mỡ · Duy trì 4 buổi/tuần';
  String _experienceLevel = 'INTERMEDIATE';
  String _activityLevel = 'MODERATE';
  String _healthNotes = 'Huyết áp ổn định, không bệnh nền';
  String _injuryNotes = 'Lưu ý nhẹ khớp vai phải khi đẩy nặng';
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

  Future<void> _loadSavedAvatar() async {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      final rawAvatar = await _secureStorage.read(key: _avatarStorageKey);
      final rawPerm = await _secureStorage.read(key: _permissionStorageKey);
      if (!mounted) return;
      setState(() {
        if (rawAvatar != null && rawAvatar.isNotEmpty) {
          _avatarBytes = base64Decode(rawAvatar);
        }
        if (rawPerm != null) {
          _photoAccessMode = _PhotoAccessMode.values.firstWhere(
            (e) => e.name == rawPerm,
            orElse: () => _PhotoAccessMode.unset,
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _saveAvatarToStorage(
    Uint8List? avatarBytes,
    _PhotoAccessMode mode,
  ) async {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      if (avatarBytes == null || avatarBytes.isEmpty) {
        await _secureStorage.delete(key: _avatarStorageKey);
      } else {
        await _secureStorage.write(
          key: _avatarStorageKey,
          value: base64Encode(avatarBytes),
        );
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
      if (height is num && height > 0) _heightCm = height.toDouble();

      final goal = p['fitnessGoal'] as String?;
      if (goal != null && goal.trim().isNotEmpty) _fitnessGoal = goal.trim();

      final exp = p['experienceLevel'] as String?;
      if (exp != null && exp.trim().isNotEmpty) _experienceLevel = exp.trim();

      final act = p['activityLevel'] as String?;
      if (act != null && act.trim().isNotEmpty) _activityLevel = act.trim();

      final health = p['healthNotes'] as String?;
      if (health != null && health.trim().isNotEmpty) {
        _healthNotes = health.trim();
      }

      final injury = p['injuryNotes'] as String?;
      if (injury != null && injury.trim().isNotEmpty) {
        _injuryNotes = injury.trim();
      }

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

  String _genderLabel(String code) => switch (code) {
    'MALE' => 'Nam',
    'FEMALE' => 'Nữ',
    'OTHER' => 'Khác',
    _ => 'Không tiết lộ',
  };

  String _experienceLabel(String code) => switch (code) {
    'BEGINNER' => 'Mới bắt đầu',
    'INTERMEDIATE' => 'Trung cấp',
    'ADVANCED' => 'Nâng cao',
    _ => code,
  };

  String _activityLabel(String code) => switch (code) {
    'LOW' => 'Ít vận động',
    'MODERATE' => 'Trung bình',
    'HIGH' => 'Năng động cao',
    _ => code,
  };

  int get _profileCompletionPercent {
    if (_role == UserRole.member) {
      final checks = [
        _fullName.trim().isNotEmpty,
        _phone.trim().isNotEmpty,
        _dateOfBirth.trim().isNotEmpty,
        _gender.trim().isNotEmpty,
        _heightCm > 0,
        _fitnessGoal.trim().isNotEmpty,
        _experienceLevel.trim().isNotEmpty,
        _activityLevel.trim().isNotEmpty,
        _healthNotes.trim().isNotEmpty || _injuryNotes.trim().isNotEmpty,
        _dietaryPreferences.trim().isNotEmpty,
      ];
      final done = checks.where((c) => c).length;
      return ((done / checks.length) * 100).round();
    }
    if (_role == UserRole.coach) {
      final checks = [
        _fullName.trim().isNotEmpty,
        _phone.trim().isNotEmpty,
        _biography.trim().isNotEmpty,
        _specialties.isNotEmpty,
        _qualifications.trim().isNotEmpty,
        _availabilityNote.trim().isNotEmpty,
      ];
      final done = checks.where((c) => c).length;
      return ((done / checks.length) * 100).round();
    }
    return _phone.trim().isNotEmpty ? 100 : 80;
  }

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

                  // 4 nút điều hướng nhanh đồng bộ hoàn toàn với _buildQuickActionDock trên Trang chủ
                  if (_role != UserRole.admin) ...[
                    _buildQuickActionDock(),
                    const SizedBox(height: 14),
                  ],

                  // Thẻ Hero Hồ sơ đồng bộ _buildMembershipGlassCard trên Trang chủ
                  _buildHeroProfileCard(),
                  const SizedBox(height: 14),

                  // Danh mục hồ sơ chi tiết đồng bộ _buildLiquidGlassCard trên Trang chủ
                  _buildSectionHeader(
                    'Thông tin cá nhân',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildPersonalInfoCard(),
                  const SizedBox(height: 14),

                  if (_role == UserRole.member) ...[
                    _buildSectionHeader(
                      'Thể trạng & Mục tiêu tập luyện',
                      icon: Icons.fitness_center_rounded,
                    ),
                    const SizedBox(height: 8),
                    _buildTrainingProfileCard(),
                    const SizedBox(height: 14),
                    _buildSectionHeader(
                      'Sức khỏe, Chấn thương & Dinh dưỡng',
                      icon: Icons.favorite_border_rounded,
                      trailingBadge: 'Chỉ bạn & Coach',
                    ),
                    const SizedBox(height: 8),
                    _buildHealthNutritionCard(),
                    const SizedBox(height: 14),
                  ] else if (_role == UserRole.coach) ...[
                    _buildSectionHeader(
                      'Hồ sơ chuyên môn Huấn luyện viên',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 8),
                    _buildCoachProfileCard(),
                    const SizedBox(height: 14),
                  ],

                  _buildSectionHeader(
                    'Bảo mật & Tài khoản',
                    icon: Icons.shield_outlined,
                  ),
                  const SizedBox(height: 8),
                  _buildSecurityAndAccountCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                  'Hồ sơ cá nhân',
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
          _CircleHeaderGlassButton(
            icon: Icons.edit_outlined,
            semanticLabel: 'Chỉnh sửa thông tin cá nhân',
            onTap: _openPersonalInfoSheet,
          ),
          const SizedBox(width: 4),
          _CircleHeaderGlassButton(
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFFF6961),
            semanticLabel: 'Đăng xuất',
            onTap: _confirmSignOut,
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
  // 3. HERO PROFILE CARD (GIỐNG CHÍNH XÁC _buildMembershipGlassCard & _buildMembershipMetricPanel)
  // ===========================================================================
  Widget _buildHeroProfileCard() {
    final completion = _profileCompletionPercent;

    return _MembershipGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _openPersonalInfoSheet,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: MetaGymTheme.coachAvatarBackground,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _avatarBytes != null
                                ? MetaGymTheme.brandOrange
                                : const Color(0x389A8C81),
                            width: _avatarBytes != null ? 1.4 : 0.8,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _avatarBytes != null
                            ? ClipOval(
                                child: Image.memory(
                                  _avatarBytes!,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                _initials,
                                style: const TextStyle(
                                  color: MetaGymTheme.coachAvatarForeground,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
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
                            color: MetaGymTheme.brandOrange,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1F1C1A),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _fullName,
                              style: const TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x262ECC71),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0x4D2ECC71),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              _roleLabel,
                              style: const TextStyle(
                                color: MetaGymTheme.progressGreen,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _email.isNotEmpty ? _email : 'member@metagym.vn',
                        style: const TextStyle(
                          color: Color(0xFFEAE6E2),
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _status == 'ACTIVE'
                                  ? MetaGymTheme.progressGreen
                                  : MetaGymTheme.warningAmber,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _phone.isNotEmpty
                                  ? 'Đang hoạt động · SĐT: $_phone'
                                  : 'Đang hoạt động · Chưa cập nhật SĐT',
                              style: const TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2 ô Metric Panel giống hệt _buildMembershipMetricPanel trên Trang chủ
            if (_role == UserRole.member)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MetricPanel(
                        onTap: _openTrainingProfileSheet,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_heightCm.round()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'chiều cao (cm)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.show_chart_rounded,
                                  color: MetaGymTheme.brandOrange,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _experienceLabel(_experienceLevel),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFEAE6E2),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricPanel(
                        onTap: _openTrainingProfileSheet,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: MetaGymTheme.brandOrange,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _activityLabel(_activityLevel),
                                    style: const TextStyle(
                                      color: Color(0xFFF7F9FC),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _fitnessGoal,
                              style: const TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 10.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Hoàn thiện hồ sơ',
                                    style: TextStyle(
                                      color: Color(0xFFEAE6E2),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x242ECC71),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '$completion%',
                                    style: const TextStyle(
                                      color: MetaGymTheme.progressGreen,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_role == UserRole.coach)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MetricPanel(
                        onTap: _openCoachProfileSheet,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_experienceYears',
                              style: const TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'năm kinh nghiệm',
                              style: TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricPanel(
                        onTap: _openCoachProfileSheet,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_specialties.length}',
                              style: const TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'chuyên môn',
                              style: TextStyle(
                                color: Color(0xFFB7B2AF),
                                fontSize: 11,
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
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    required IconData icon,
    String? trailingBadge,
  }) {
    return Row(
      children: [
        Icon(icon, color: MetaGymTheme.brandOrange, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF7F9FC),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailingBadge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x262ECC71),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x4D2ECC71), width: 0.6),
            ),
            child: Text(
              trailingBadge,
              style: const TextStyle(
                color: MetaGymTheme.progressGreen,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // 4. THẺ CHI TIẾT HỒ SƠ (GIỐNG CHÍNH XÁC _buildLiquidGlassCard CỦA TRANG CHỦ)
  // ===========================================================================
  Widget _buildPersonalInfoCard() {
    return _DashboardGlassCard(
      featured: true,
      child: Column(
        children: [
          _ProfileRowTile(
            icon: Icons.person_outline_rounded,
            label: 'Họ và tên',
            value: _fullName,
            onTap: _openPersonalInfoSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.phone_outlined,
            label: 'Số điện thoại',
            value: _phone.isNotEmpty ? _phone : 'Chưa cập nhật',
            isPlaceholder: _phone.isEmpty,
            onTap: _openPersonalInfoSheet,
          ),
          if (_role == UserRole.member) ...[
            _rowDivider(),
            _ProfileRowTile(
              icon: Icons.cake_outlined,
              label: 'Ngày sinh',
              value: _dateOfBirth,
              onTap: _openPersonalInfoSheet,
            ),
            _rowDivider(),
            _ProfileRowTile(
              icon: Icons.wc_rounded,
              label: 'Giới tính',
              value: _genderLabel(_gender),
              onTap: _openPersonalInfoSheet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrainingProfileCard() {
    return _DashboardGlassCard(
      child: Column(
        children: [
          _ProfileRowTile(
            icon: Icons.flag_outlined,
            label: 'Mục tiêu tập luyện',
            value: _fitnessGoal,
            onTap: _openTrainingProfileSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.straighten_rounded,
            label: 'Chiều cao',
            value: '${_heightCm.round()} cm',
            onTap: _openTrainingProfileSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.trending_up_rounded,
            label: 'Trình độ tập luyện',
            value: _experienceLabel(_experienceLevel),
            onTap: _openTrainingProfileSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.bolt_rounded,
            label: 'Mức độ vận động',
            value: _activityLabel(_activityLevel),
            onTap: _openTrainingProfileSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthNutritionCard() {
    return _DashboardGlassCard(
      child: Column(
        children: [
          _ProfileRowTile(
            icon: Icons.favorite_border_rounded,
            label: 'Tình trạng sức khỏe',
            value: _healthNotes,
            onTap: _openHealthNutritionSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.healing_outlined,
            label: 'Chấn thương & Hạn chế vận động',
            value: _injuryNotes,
            onTap: _openHealthNutritionSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.restaurant_menu_rounded,
            label: 'Chế độ ăn & Dị ứng thực phẩm',
            value: _dietaryPreferences,
            onTap: _openHealthNutritionSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildCoachProfileCard() {
    return _DashboardGlassCard(
      child: Column(
        children: [
          _ProfileRowTile(
            icon: Icons.badge_outlined,
            label: 'Giới thiệu bản thân',
            value: _biography,
            onTap: _openCoachProfileSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.auto_awesome_outlined,
            label: 'Chuyên môn huấn luyện',
            value: _specialties.join(' · '),
            onTap: _openCoachProfileSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.workspace_premium_outlined,
            label: 'Bằng cấp & Chứng chỉ',
            value: _qualifications,
            onTap: _openCoachProfileSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.timeline_rounded,
            label: 'Số năm kinh nghiệm',
            value: '$_experienceYears năm',
            onTap: _openCoachProfileSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.schedule_rounded,
            label: 'Khung giờ hướng dẫn',
            value: _availabilityNote,
            onTap: _openCoachProfileSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityAndAccountCard() {
    return _DashboardGlassCard(
      child: Column(
        children: [
          _ProfileRowTile(
            icon: Icons.lock_outline_rounded,
            label: 'Đổi mật khẩu',
            value: 'Cập nhật mật khẩu bảo vệ tài khoản',
            onTap: _openChangePasswordSheet,
          ),
          _rowDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6961),
                  side: const BorderSide(color: Color(0x4DFF453A)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _confirmSignOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Đăng xuất',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowDivider() {
    return const Divider(
      height: 1,
      thickness: 0.7,
      indent: 58,
      endIndent: 14,
      color: Color(0x389A8C81),
    );
  }

  // ===========================================================================
  // 5. BOTTOM SHEETS CHỈNH SỬA (GỌI THẬT PATCH /users/me & PATCH /users/me/password)
  // ===========================================================================
  String _photoAccessModeLabel(_PhotoAccessMode mode) {
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

  Future<void> _openPersonalInfoSheet() async {
    final nameCtrl = TextEditingController(text: _fullName);
    final phoneCtrl = TextEditingController(text: _phone);
    var dob = _dateOfBirth;
    var gender = _gender;
    var draftAvatar = _avatarBytes;
    var draftAllowedPhotos = List<Uint8List>.from(_allowedPhotoBytes);
    var draftAccessMode = _photoAccessMode;
    var isSaving = false;

    Future<void> handleAvatarUpload(
      BuildContext sheetCtx,
      StateSetter setModalState,
    ) async {
      final chosenMode = await _requestNativePhotoPermission();
      setModalState(() => draftAccessMode = chosenMode);

      if (chosenMode == _PhotoAccessMode.denied) {
        setModalState(() {
          draftAllowedPhotos = [];
        });
        await _saveAvatarToStorage(draftAvatar, _PhotoAccessMode.denied);
        _showToast('Đã từ chối quyền truy cập ảnh', isError: true);
        return;
      }

      try {
        if (chosenMode == _PhotoAccessMode.selectedOnly) {
          final nativePhotos = await _loadNativeGrantedPhotos();
          if (nativePhotos.isNotEmpty) {
            setModalState(() {
              draftAllowedPhotos = nativePhotos;
              draftAvatar = nativePhotos.first;
            });
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
          setModalState(() {
            draftAllowedPhotos = pickedBytesList;
            draftAvatar = pickedBytesList.first;
          });
        } else {
          final file = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 800,
            maxHeight: 800,
            imageQuality: 85,
          );
          if (file == null) return;
          final bytes = await file.readAsBytes();
          setModalState(() {
            draftAvatar = bytes;
          });
        }
      } catch (_) {
        _showToast(
          'Không thể mở thư viện ảnh trên thiết bị. Vui lòng kiểm tra quyền ứng dụng.',
          isError: true,
        );
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _ProfileEditSheet(
          title: 'Thông tin cá nhân',
          subtitle: 'Đồng bộ trực tiếp với hồ sơ tài khoản Meta Gym',
          isBusy: isSaving,
          onSave: () async {
            final trimmedName = nameCtrl.text.trim();
            if (trimmedName.length < 2) {
              _showToast('Họ và tên cần ít nhất 2 ký tự', isError: true);
              return;
            }
            setModalState(() => isSaving = true);
            setState(() {
              _fullName = trimmedName;
              _phone = phoneCtrl.text.trim();
              _dateOfBirth = dob;
              _gender = gender;
              _avatarBytes = draftAvatar;
              _allowedPhotoBytes = draftAllowedPhotos;
              _photoAccessMode = draftAccessMode;
            });
            await _saveAvatarToStorage(draftAvatar, draftAccessMode);
            final patch = <String, Object?>{
              'fullName': trimmedName,
              'phone': phoneCtrl.text.trim(),
              if (_role == UserRole.member) ...{
                'dateOfBirth': dob,
                'gender': gender,
              },
            };
            if (ctx.mounted) Navigator.pop(ctx);
            await _persistPatch(
              patch,
              successMessage: 'Đã lưu thông tin cá nhân & ảnh đại diện',
            );
          },
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF282320),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x479A8C81), width: 0.7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => handleAvatarUpload(ctx, setModalState),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: MetaGymTheme.coachAvatarBackground,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: MetaGymTheme.brandOrange,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: draftAvatar != null
                                  ? ClipOval(
                                      child: Image.memory(
                                        draftAvatar!,
                                        width: 58,
                                        height: 58,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Text(
                                      _initials,
                                      style: const TextStyle(
                                        color:
                                            MetaGymTheme.coachAvatarForeground,
                                        fontSize: 18,
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
                                  Icons.photo_camera_outlined,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ảnh đại diện (Avatar)',
                              style: TextStyle(
                                color: Color(0xFFF7F9FC),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _photoAccessModeLabel(draftAccessMode),
                              style: TextStyle(
                                color:
                                    draftAccessMode == _PhotoAccessMode.denied
                                    ? const Color(0xFFE74C3C)
                                    : const Color(0xFFB7B2AF),
                                fontSize: 11.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                InkWell(
                                  onTap: () =>
                                      handleAvatarUpload(ctx, setModalState),
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x26E06D3C),
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color: MetaGymTheme.brandOrange,
                                        width: 0.7,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.upload_file_outlined,
                                          size: 14,
                                          color: MetaGymTheme.brandOrange,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'Tải ảnh từ điện thoại',
                                          style: TextStyle(
                                            color: MetaGymTheme.brandOrange,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (draftAvatar != null)
                                  InkWell(
                                    onTap: () => setModalState(() {
                                      draftAvatar = null;
                                    }),
                                    borderRadius: BorderRadius.circular(9),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0x1FE74C3C),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: const Color(0x4DE74C3C),
                                          width: 0.7,
                                        ),
                                      ),
                                      child: const Text(
                                        'Gỡ ảnh',
                                        style: TextStyle(
                                          color: Color(0xFFE74C3C),
                                          fontSize: 11.2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (draftAccessMode == _PhotoAccessMode.selectedOnly &&
                      draftAllowedPhotos.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    const Divider(height: 1, color: Color(0x389A8C81)),
                    const SizedBox(height: 9),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ảnh đã tích cho phép (${draftAllowedPhotos.length} ảnh):',
                          style: const TextStyle(
                            color: Color(0xFFEAE6E2),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        InkWell(
                          onTap: () => handleAvatarUpload(ctx, setModalState),
                          child: const Text(
                            '+ Chọn lại ảnh tích',
                            style: TextStyle(
                              color: MetaGymTheme.brandOrange,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: draftAllowedPhotos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, idx) {
                          final photo = draftAllowedPhotos[idx];
                          final isSelected = identical(draftAvatar, photo);
                          return GestureDetector(
                            onTap: () => setModalState(() {
                              draftAvatar = photo;
                            }),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? MetaGymTheme.brandOrange
                                      : const Color(0x479A8C81),
                                  width: isSelected ? 2 : 0.8,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(photo, fit: BoxFit.cover),
                                    if (isSelected)
                                      Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.check_circle_rounded,
                                          color: MetaGymTheme.brandOrange,
                                          size: 18,
                                        ),
                                      ),
                                  ],
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
            const SizedBox(height: 14),
            _SheetTextField(controller: nameCtrl, label: 'Họ và tên'),
            const SizedBox(height: 12),
            _SheetTextField(
              controller: phoneCtrl,
              label: 'Số điện thoại',
              keyboardType: TextInputType.phone,
            ),
            if (_role == UserRole.member) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final initial =
                      DateTime.tryParse(dob) ?? DateTime(1999, 8, 15);
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: initial,
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    final y = picked.year.toString().padLeft(4, '0');
                    final m = picked.month.toString().padLeft(2, '0');
                    final d = picked.day.toString().padLeft(2, '0');
                    setModalState(() => dob = '$y-$m-$d');
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: _sheetInputDecoration('Ngày sinh (YYYY-MM-DD)'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dob,
                        style: const TextStyle(color: Color(0xFFF7F9FC)),
                      ),
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFFB7B2AF),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Giới tính',
                style: TextStyle(
                  color: Color(0xFFEAE6E2),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
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
                      label: _genderLabel(code),
                      selected: gender == code,
                      onTap: () => setModalState(() => gender = code),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openTrainingProfileSheet() async {
    final goalCtrl = TextEditingController(text: _fitnessGoal);
    var height = _heightCm;
    var experience = _experienceLevel;
    var activity = _activityLevel;
    var isSaving = false;

    const goalPresets = [
      'Tăng cơ giảm mỡ · Duy trì 4 buổi/tuần',
      'Giảm mỡ siết cơ · Cardio & HIIT',
      'Tăng sức mạnh tối đa (Strength & Power)',
      'Cải thiện sức bền & Phục hồi vận động',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _ProfileEditSheet(
          title: 'Thể trạng & Mục tiêu',
          subtitle: 'Giúp Coach & AI cá nhân hóa giáo án tập luyện',
          isBusy: isSaving,
          onSave: () async {
            setModalState(() => isSaving = true);
            final nextGoal = goalCtrl.text.trim().isNotEmpty
                ? goalCtrl.text.trim()
                : _fitnessGoal;
            setState(() {
              _fitnessGoal = nextGoal;
              _heightCm = height;
              _experienceLevel = experience;
              _activityLevel = activity;
            });
            if (ctx.mounted) Navigator.pop(ctx);
            await _persistPatch({
              'fitnessGoal': nextGoal,
              'heightCm': double.parse(height.toStringAsFixed(1)),
              'experienceLevel': experience,
              'activityLevel': activity,
            }, successMessage: 'Đã lưu thể trạng & mục tiêu tập luyện');
          },
          children: [
            _SheetTextField(
              controller: goalCtrl,
              label: 'Mục tiêu tập luyện',
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final preset in goalPresets)
                  _SheetChoiceChip(
                    label: preset,
                    selected: goalCtrl.text.trim() == preset,
                    onTap: () => setModalState(() => goalCtrl.text = preset),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chiều cao',
                  style: TextStyle(
                    color: Color(0xFFEAE6E2),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${height.round()} cm',
                  style: const TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(ctx).copyWith(
                activeTrackColor: MetaGymTheme.brandOrange,
                inactiveTrackColor: const Color(0x26FFFFFF),
                thumbColor: MetaGymTheme.brandOrange,
                overlayColor: const Color(0x29FF5A36),
              ),
              child: Slider(
                value: height.clamp(120, 220),
                min: 120,
                max: 220,
                divisions: 100,
                onChanged: (v) => setModalState(() => height = v),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trình độ tập luyện',
              style: TextStyle(
                color: Color(0xFFEAE6E2),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final code in ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'])
                  _SheetChoiceChip(
                    label: _experienceLabel(code),
                    selected: experience == code,
                    onTap: () => setModalState(() => experience = code),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Mức độ vận động hàng ngày',
              style: TextStyle(
                color: Color(0xFFEAE6E2),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final code in ['LOW', 'MODERATE', 'HIGH'])
                  _SheetChoiceChip(
                    label: _activityLabel(code),
                    selected: activity == code,
                    onTap: () => setModalState(() => activity = code),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openHealthNutritionSheet() async {
    final healthCtrl = TextEditingController(text: _healthNotes);
    final injuryCtrl = TextEditingController(text: _injuryNotes);
    final dietCtrl = TextEditingController(text: _dietaryPreferences);
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _ProfileEditSheet(
          title: 'Sức khỏe & Dinh dưỡng',
          subtitle:
              'Chỉ bạn và Coach đang phụ trách được phép xem thông tin này',
          isBusy: isSaving,
          onSave: () async {
            setModalState(() => isSaving = true);
            final nextHealth = healthCtrl.text.trim().isNotEmpty
                ? healthCtrl.text.trim()
                : 'Không có lưu ý đặc biệt';
            final nextInjury = injuryCtrl.text.trim().isNotEmpty
                ? injuryCtrl.text.trim()
                : 'Không có chấn thương';
            final nextDiet = dietCtrl.text.trim().isNotEmpty
                ? dietCtrl.text.trim()
                : 'Ăn uống cân bằng';
            setState(() {
              _healthNotes = nextHealth;
              _injuryNotes = nextInjury;
              _dietaryPreferences = nextDiet;
            });
            if (ctx.mounted) Navigator.pop(ctx);
            await _persistPatch({
              'healthNotes': nextHealth,
              'injuryNotes': nextInjury,
              'dietaryPreferences': nextDiet,
            }, successMessage: 'Đã lưu thông tin sức khỏe & dinh dưỡng');
          },
          children: [
            _SheetTextField(
              controller: healthCtrl,
              label: 'Tình trạng sức khỏe',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              controller: injuryCtrl,
              label: 'Chấn thương hoặc hạn chế vận động',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              controller: dietCtrl,
              label: 'Sở thích ăn uống / Dị ứng thực phẩm',
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCoachProfileSheet() async {
    final bioCtrl = TextEditingController(text: _biography);
    final specsCtrl = TextEditingController(text: _specialties.join(', '));
    final qualCtrl = TextEditingController(text: _qualifications);
    final availCtrl = TextEditingController(text: _availabilityNote);
    var years = _experienceYears;
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _ProfileEditSheet(
          title: 'Hồ sơ Huấn luyện viên',
          subtitle:
              'Thông tin hiển thị cho Hội viên khi tìm và đăng ký gói Coach',
          isBusy: isSaving,
          onSave: () async {
            setModalState(() => isSaving = true);
            final parsedSpecs = specsCtrl.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .take(20)
                .toList();
            final nextBio = bioCtrl.text.trim().isNotEmpty
                ? bioCtrl.text.trim()
                : _biography;
            final nextQual = qualCtrl.text.trim().isNotEmpty
                ? qualCtrl.text.trim()
                : _qualifications;
            final nextAvail = availCtrl.text.trim().isNotEmpty
                ? availCtrl.text.trim()
                : _availabilityNote;
            final nextSpecs = parsedSpecs.isNotEmpty
                ? parsedSpecs
                : _specialties;
            setState(() {
              _biography = nextBio;
              _specialties = nextSpecs;
              _qualifications = nextQual;
              _experienceYears = years;
              _availabilityNote = nextAvail;
            });
            if (ctx.mounted) Navigator.pop(ctx);
            await _persistPatch({
              'biography': nextBio,
              'specialties': nextSpecs,
              'qualifications': nextQual,
              'experienceYears': years,
              'availabilityNote': nextAvail,
            }, successMessage: 'Đã lưu hồ sơ Huấn luyện viên');
          },
          children: [
            _SheetTextField(
              controller: bioCtrl,
              label: 'Giới thiệu bản thân',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              controller: specsCtrl,
              label: 'Chuyên môn (ngăn cách bằng dấu phẩy)',
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              controller: qualCtrl,
              label: 'Bằng cấp & Chứng chỉ',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Số năm kinh nghiệm',
                  style: TextStyle(
                    color: Color(0xFFEAE6E2),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: years > 0
                          ? () => setModalState(() => years--)
                          : null,
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Color(0xFFB7B2AF),
                      ),
                    ),
                    Text(
                      '$years năm',
                      style: const TextStyle(
                        color: MetaGymTheme.brandOrange,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setModalState(() => years++),
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: MetaGymTheme.brandOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SheetTextField(
              controller: availCtrl,
              label: 'Khung giờ hướng dẫn',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChangePasswordSheet() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;
    var isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _ProfileEditSheet(
          title: 'Đổi mật khẩu',
          subtitle:
              'Mật khẩu mới dài 8–72 ký tự, gồm chữ hoa, chữ thường và chữ số',
          saveLabel: 'Cập nhật mật khẩu',
          isBusy: isSaving,
          onSave: () async {
            final current = currentCtrl.text;
            final next = newCtrl.text;
            final confirm = confirmCtrl.text;
            final valid =
                next.length >= 8 &&
                RegExp(r'[a-z]').hasMatch(next) &&
                RegExp(r'[A-Z]').hasMatch(next) &&
                RegExp(r'[0-9]').hasMatch(next);
            if (current.isEmpty) {
              setModalState(
                () => errorText = 'Vui lòng nhập mật khẩu hiện tại',
              );
              return;
            }
            if (!valid) {
              setModalState(
                () => errorText = 'Mật khẩu mới cần ít nhất 8 ký tự, có chữ hoa, chữ thường và số',
              );
              return;
            }
            if (next != confirm) {
              setModalState(
                () => errorText = 'Mật khẩu xác nhận không trùng khớp',
              );
              return;
            }
            setModalState(() {
              errorText = null;
              isSaving = true;
            });
            final controller = context.read<ProfileController?>();
            if (controller != null) {
              final ok = await controller.changePassword(
                currentPassword: current,
                newPassword: next,
              );
              if (!ctx.mounted) return;
              if (!ok) {
                setModalState(() {
                  isSaving = false;
                  errorText =
                      controller.errorMessage ??
                      'Không thể đổi mật khẩu. Kiểm tra lại mật khẩu hiện tại.';
                });
                return;
              }
            }
            if (ctx.mounted) Navigator.pop(ctx);
            _showToast('Đã đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
          },
          children: [
            _SheetTextField(
              controller: currentCtrl,
              label: 'Mật khẩu hiện tại',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              controller: newCtrl,
              label: 'Mật khẩu mới',
              obscureText: true,
            ),
            const SizedBox(height: 12),
            _SheetTextField(
              controller: confirmCtrl,
              label: 'Xác nhận mật khẩu mới',
              obscureText: true,
            ),
            if (errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                errorText!,
                style: const TextStyle(
                  color: Color(0xFFF15B64),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
  const _MembershipGlassCard({required this.child, this.borderRadius});

  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
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

/// Giống chính xác `_buildMembershipMetricPanel` trong `member_dashboard_view.dart`.
class _MetricPanel extends StatelessWidget {
  const _MetricPanel({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x80211E1C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0x9A8C8176), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 82),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Giống chính xác `_buildLiquidGlassCard` trong `member_dashboard_view.dart`.
class _DashboardGlassCard extends StatelessWidget {
  const _DashboardGlassCard({required this.child, this.featured = false});

  final Widget child;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MetaGymTheme.radiusCard);
    final surface = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: featured ? const Color(0xB82D2824) : const Color(0xC42B2622),
        borderRadius: radius,
        border: Border.all(color: const Color(0xA3A79D92), width: 1.1),
      ),
      child: featured
          ? Stack(
              children: [
                const Positioned(
                  top: 0,
                  left: 18,
                  right: 18,
                  child: SizedBox(
                    height: 1,
                    child: ColoredBox(color: Color(0x70FFF6EA)),
                  ),
                ),
                child,
              ],
            )
          : child,
    );
    if (!featured ||
        MediaQuery.disableAnimationsOf(context) ||
        MetaGymTheme.isFlutterTestEnvironment) {
      return surface;
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: surface,
        ),
      ),
    );
  }
}

/// Giống chính xác `_CircleHeaderGlassButton` trong `member_dashboard_view.dart`.
class _CircleHeaderGlassButton extends StatelessWidget {
  const _CircleHeaderGlassButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final Color? iconColor;

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
                    color: iconColor ?? MetaGymTheme.darkTextPrimary,
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

class _ProfileRowTile extends StatelessWidget {
  const _ProfileRowTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.isPlaceholder = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0x80211E1C),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0x9A8C8176),
                    width: 0.9,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: MetaGymTheme.brandOrange, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFB7B2AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: isPlaceholder
                            ? const Color(0xFF8E8A86)
                            : const Color(0xFFF7F9FC),
                        fontSize: 13.5,
                        fontWeight: isPlaceholder
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8E9AA8),
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileEditSheet extends StatelessWidget {
  const _ProfileEditSheet({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.onSave,
    this.saveLabel = 'Lưu thay đổi',
    this.isBusy = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback onSave;
  final String saveLabel;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
      child: _MembershipGlassCard(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x75FFF5E9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0xFFB7B2AF),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFEAE6E2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...children,
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.brandOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: isBusy ? null : onSave,
                    child: Text(
                      isBusy ? 'Đang lưu...' : saveLabel,
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
