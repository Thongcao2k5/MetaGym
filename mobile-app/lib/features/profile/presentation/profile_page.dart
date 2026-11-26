import 'dart:io' show Directory, File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, Uint8List;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meta_gym_app/core/network/local_demo_interceptor.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/ai/presentation/ai_conversations_page.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/calls/presentation/calls_page.dart';
import 'package:meta_gym_app/features/catalog/presentation/gym_equipment_page.dart';
import 'package:meta_gym_app/features/coach/presentation/coach_schedule_management_pages.dart';
import 'package:meta_gym_app/features/coaching/data/coach_members_service.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_members_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_notifications_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/coach_offers_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_coaching_page.dart';
import 'package:meta_gym_app/features/coaching/presentation/member_health_declaration_page.dart';
import 'package:meta_gym_app/features/membership/presentation/membership_page.dart';
import 'package:meta_gym_app/features/messaging/presentation/conversations_page.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/personal_info_page.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_secondary_pages.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_shared_widgets.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/training_profile_page.dart';
import 'package:meta_gym_app/features/progress/data/member_measurement_service.dart';
import 'package:meta_gym_app/features/progress/presentation/member_measurement_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_booking_history_page.dart';
import 'package:meta_gym_app/features/sessions/presentation/coach_sessions_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_nutrition_page.dart';
import 'package:meta_gym_app/features/training/presentation/coach_training_page.dart';
import 'package:provider/provider.dart';
import 'package:meta_gym_app/core/theme/theme_controller.dart';

/// Màn hình **5.1 Hồ sơ (Member)** & **6.1 Hồ sơ Huấn luyện viên (Coach)**
/// đồng bộ `tab5-profile.js` / `workspace.js` (`coach-profile`),
/// `DESIGN.md` và Lõi Design System Dark + Light:
/// - Nền [MetaGymBackground] Spatial Light Ribbons (`bg_app_dark.webp` / `bg_app_light.webp`) + [MetaGymBrandHeader]
/// - Hero Profile Card ([MetaGymHeroGlassCard] Warm Glass): Avatar 60px + camera badge,
///   vai trò, trạng thái hoạt động, email (`comm_email.svg`), SĐT (`call_audio_badge.svg`)
/// - 3 nhóm accordion card kiểu Member (`ProfileAccordionCard` / `MetaGymGlassCard(solid: false)`)
/// - Thẻ Đăng xuất + Modal Level 3 Overlay Glass xác nhận đăng xuất.
class ProfilePage extends StatefulWidget {
  const ProfilePage({this.bottomPadding, this.coachMode, super.key});

  final double? bottomPadding;
  final bool? coachMode;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const MethodChannel _mediaPermissionChannel = MethodChannel(
    'com.metagym.meta_gym_app/media_permission',
  );
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final ImagePicker _imagePicker = ImagePicker();

  bool _initialized = false;
  int? _expandedCategory;

  // Trạng thái Avatar & Quyền truy cập ảnh
  Uint8List? _avatarBytes;
  List<Uint8List> _allowedPhotoBytes = const [];
  PhotoAccessMode _photoAccessMode = PhotoAccessMode.unset;

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

  // Trường dành cho Hội viên (`member_profiles` & số đo mới nhất)
  String _dateOfBirth = '1999-08-15';
  String _gender = 'MALE';
  double _heightCm = 174;
  double _latestWeightKg = 72.4;
  String _fitnessGoal = '';
  String _experienceLevel = 'INTERMEDIATE';
  String _activityLevel = 'MODERATE';

  // Trường dành cho Huấn luyện viên (`coach_profiles`)
  String _biography =
      'Huấn luyện viên cá nhân chuyên Hypertrophy, Strength & Mobility.';
  List<String> _specialties = ['Hypertrophy', 'Giảm mỡ', 'Phục hồi vận động'];
  String _qualifications = 'CPT NASM · Chứng chỉ Dinh dưỡng Thể thao';
  int _experienceYears = 4;
  String _availabilityNote = 'Thứ 2 – Thứ 7 · 06:00 – 20:00';
  int? _activeMemberCount;

  bool get _isCoach => _role == UserRole.coach || (widget.coachMode ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MetaGymTheme.isFlutterTestEnvironment) {
      precacheImage(
        MetaGymBackground.darkAppBackgroundAsset,
        context,
      ).catchError((_) {});
      precacheImage(
        MetaGymBackground.lightAppBackgroundAsset,
        context,
      ).catchError((_) {});
    }
    if (_initialized) return;
    _initialized = true;

    final user = context.read<SessionController?>()?.user;
    if (user != null) {
      _syncFromUser(user);
    } else if (widget.coachMode == true) {
      _role = UserRole.coach;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reloadProfile();
        _loadSavedAvatar();
        _loadLatestWeight();
        _loadCoachActiveMemberCount();
      }
    });
  }

  Future<void> _loadCoachActiveMemberCount() async {
    if (!_isCoach) return;
    try {
      final membersService = context.read<CoachMembersService?>();
      if (membersService == null) return;
      final members = await membersService.getMembers();
      if (!mounted) return;
      final activeCount = members.where((m) => m.status == 'ACTIVE').length;
      setState(() => _activeMemberCount = activeCount);
    } catch (_) {
      // Giữ null nếu không có CoachMembersService trong scope.
    }
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

  Future<void> _loadLatestWeight() async {
    if (_role != UserRole.member) return;
    try {
      final measurementService = context.read<MemberMeasurementService?>();
      if (measurementService == null) return;
      final items = await measurementService.getPage(1);
      if (items.isNotEmpty && mounted && items.first.weightKg > 0) {
        setState(() => _latestWeightKg = items.first.weightKg);
      }
    } catch (_) {
      // Giữ giá trị mặc định nếu dịch vụ số đo không khả dụng.
    }
  }

  Future<void> _loadSavedAvatar() async {
    if (MetaGymTheme.isFlutterTestEnvironment) return;
    try {
      final user = context.read<SessionController?>()?.user;
      final controller = context.read<ProfileController?>();
      final userId = user?.id ?? _email;
      final file = _getAvatarCacheFile(userId);

      if (file != null && await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty && mounted) {
          setState(() => _avatarBytes = bytes);
        }
      }

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

      final rawPerm = await _secureStorage.read(key: _permissionStorageKey);
      if (rawPerm != null && mounted) {
        setState(() {
          _photoAccessMode = PhotoAccessMode.values.firstWhere(
            (e) => e.name == rawPerm,
            orElse: () => PhotoAccessMode.unset,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _saveAvatarToStorage(
    Uint8List? avatarBytes,
    PhotoAccessMode mode,
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
        if (file != null) {
          await file.writeAsBytes(avatarBytes, flush: true);
        }
        if (controller != null) {
          await controller.uploadAvatar(avatarBytes);
        }
      }
      await _secureStorage.write(key: _permissionStorageKey, value: mode.name);
    } catch (_) {}
  }

  Future<PhotoAccessMode> _requestNativePhotoPermission() async {
    if (MetaGymTheme.isFlutterTestEnvironment) return PhotoAccessMode.full;
    try {
      final result = await _mediaPermissionChannel.invokeMethod<String>(
        'request',
      );
      return switch (result) {
        'FULL' => PhotoAccessMode.full,
        'SELECTED' => PhotoAccessMode.selectedOnly,
        'DENIED' => PhotoAccessMode.denied,
        _ => PhotoAccessMode.full,
      };
    } catch (_) {
      return PhotoAccessMode.full;
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

  Future<void> _handleQuickAvatarAction() async {
    final action = await showProfileAvatarPickerSheet(
      context,
      accessMode: _photoAccessMode,
      hasCustomAvatar: _avatarBytes != null,
    );
    if (!mounted || action == null) return;

    if (action == ProfileAvatarAction.remove) {
      setState(() => _avatarBytes = null);
      await _saveAvatarToStorage(null, _photoAccessMode);
      if (mounted) {
        _showToast('Đã gỡ ảnh đại diện (dùng chữ viết tắt $_initials)');
      }
      return;
    }

    try {
      final source = action == ProfileAvatarAction.camera
          ? ImageSource.camera
          : ImageSource.gallery;
      if (source == ImageSource.gallery) {
        final mode = await _requestNativePhotoPermission();
        if (!mounted) return;
        setState(() => _photoAccessMode = mode);
        if (mode == PhotoAccessMode.denied) {
          _showToast('Đã từ chối quyền truy cập ảnh', isError: true);
          return;
        }
      }
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _avatarBytes = bytes);
      await _saveAvatarToStorage(bytes, _photoAccessMode);
      if (mounted) {
        _showToast('Đã cập nhật ảnh đại diện');
      }
    } catch (_) {
      if (mounted) {
        _showToast(
          'Không thể mở nguồn ảnh trên thiết bị. Vui lòng kiểm tra quyền ứng dụng.',
          isError: true,
        );
      }
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
        _loadLatestWeight();
      }
    } catch (_) {
      // Giữ trạng thái hiện tại nếu chạy ở chế độ xem trước độc lập.
    }
  }

  void _syncFromUser(AuthUser user) {
    _fullName = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : (user.role == UserRole.coach
              ? 'Huấn luyện viên Meta Gym'
              : 'Hội viên Meta Gym');
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
      if (height is num && height > 0) {
        _heightCm = height.toDouble();
      }

      final goal = p['fitnessGoal'] as String?;
      _fitnessGoal = goal?.trim() ?? '';

      final exp = p['experienceLevel'] as String?;
      if (exp != null && exp.trim().isNotEmpty) _experienceLevel = exp.trim();

      final act = p['activityLevel'] as String?;
      if (act != null && act.trim().isNotEmpty) _activityLevel = act.trim();
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
    setState(() {});
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

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    showProfileToast(context, message, isError: isError);
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

  void _toggleCategory(int index) {
    setState(
      () => _expandedCategory = _expandedCategory == index ? null : index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final sessionUser = context.watch<SessionController?>()?.user;
    if (sessionUser != null && _email.isEmpty) {
      _syncFromUser(sessionUser);
    }
    final isCoachView = _isCoach;
    final isBusy = context.watch<ProfileController?>()?.isBusy ?? false;
    final effectiveBottomPadding =
        widget.bottomPadding ?? MetaGymBottomNav.contentBottomPadding(context);

    final personalRows = _buildPersonalSectionRows(isCoachView);
    final activityRows = _buildActivityServiceRows(isCoachView);
    final accountRows = _buildAccountSupportRows(isCoachView);

    return Material(
      color: colors.canvas,
      child: Stack(
        children: [
          const Positioned.fill(child: MetaGymBackground()),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: MetaGymTheme.brandOrange,
              backgroundColor: colors.surface,
              onRefresh: _reloadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  MetaGymTheme.pageGutter,
                  0,
                  MetaGymTheme.pageGutter,
                  effectiveBottomPadding + 28,
                ),
                children: [
                  const SizedBox(height: 6),
                  MetaGymBrandHeader(
                    eyebrow: isCoachView ? 'META GYM · COACH' : 'META GYM',
                    title: isCoachView ? 'Hồ sơ cá nhân' : 'Hồ sơ',
                    subtitle: isCoachView
                        ? 'Tài khoản & thiết lập huấn luyện viên'
                        : null,
                    inlineSubtitle: isCoachView,
                    actions: [
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
                  SizedBox(height: isCoachView ? 12 : 14),

                  // 1. Hero Profile Card (Level 2 Warm Smoked-Glass khớp preview 5.1 & 6.1)
                  _buildHeroProfileCard(colors),
                  const SizedBox(height: 14),

                  // 2. Ba nhóm Accordion kiểu thẻ của Member (Warm Smoked Card) khớp 5.1 & 6.1
                  ProfileAccordionCard(
                    title: isCoachView
                        ? 'Cá nhân & chuyên môn'
                        : 'Cá nhân & thể trạng',
                    svgIcon: MetaGymIcons.settingPersonalInfo,
                    count: personalRows.length,
                    expanded: _expandedCategory == 0,
                    onToggle: () => _toggleCategory(0),
                    children: personalRows,
                  ),
                  const SizedBox(height: 12),

                  ProfileAccordionCard(
                    title: isCoachView
                        ? 'Công việc & giảng dạy'
                        : 'Tập luyện & dịch vụ',
                    svgIcon: isCoachView
                        ? MetaGymIcons.coachAchievement
                        : MetaGymIcons.equipDumbbell,
                    count: activityRows.length,
                    expanded: _expandedCategory == 1,
                    onToggle: () => _toggleCategory(1),
                    children: activityRows,
                  ),
                  const SizedBox(height: 12),

                  ProfileAccordionCard(
                    title: isCoachView
                        ? 'Tài khoản & bảo mật'
                        : 'Tài khoản & hỗ trợ',
                    svgIcon: MetaGymIcons.settingSecurityShield,
                    count: accountRows.length,
                    expanded: _expandedCategory == 2,
                    onToggle: () => _toggleCategory(2),
                    children: accountRows,
                  ),
                  const SizedBox(height: 16),

                  // 3. Thẻ Đăng xuất khớp preview 5.1 & 6.1
                  _buildSignOutCard(colors),
                  const SizedBox(height: 14),

                  // 4. Bảng điều khiển Demo Offline của nhánh develop
                  _buildOfflineDemoCard(colors),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroProfileCard(MetaGymColors colors) {
    final isCoachHero = _isCoach;
    final isActive = _status == 'ACTIVE';
    final displayRole = isCoachHero ? 'Huấn luyện viên' : _roleLabel;
    final statusText = isCoachHero
        ? (isActive ? '● Đang nhận lịch' : '● Tạm ngưng nhận lịch')
        : (isActive ? '● Đang hoạt động' : '● Chờ kích hoạt');

    return MetaGymHeroGlassCard(
      padding: EdgeInsets.zero,
      child: MetaGymTap(
        key: const Key('profile-hero-card'),
        onTap: isCoachHero ? _openCoachProfilePage : _openPersonalInfoPage,
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar 60px + badge camera chạm mở Avatar Picker Sheet
              Semantics(
                button: true,
                label: 'Đổi ảnh đại diện',
                child: InkWell(
                  key: const Key('profile-avatar-btn'),
                  onTap: _handleQuickAvatarAction,
                  customBorder: const CircleBorder(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isCoachHero
                              ? MetaGymTheme.coachAvatarBackground
                              : null,
                          gradient: isCoachHero
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    MetaGymTheme.brandOrange,
                                    MetaGymTheme.warningAmber,
                                  ],
                                ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCoachHero
                                ? MetaGymTheme.coachAvatarBackground
                                : const Color(0x80FFE2D9),
                          ),
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
                                style: TextStyle(
                                  color: isCoachHero
                                      ? MetaGymTheme.coachAvatarForeground
                                      : MetaGymTheme.onPrimary,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : ClipOval(
                                child: Image.memory(
                                  _avatarBytes!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: colors.circleButtonBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.warmGlassBorder,
                              width: 1.1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const MetaGymIcon(
                            MetaGymIcons.commonCamera,
                            size: 13,
                            color: MetaGymTheme.onPrimary,
                            adaptForLightMode: false,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fullName.isEmpty
                          ? (isCoachHero
                                ? 'Huấn luyện viên Meta Gym'
                                : 'Hội viên Meta Gym')
                          : _fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          displayRole,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: isActive ? colors.success : colors.warning,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const MetaGymIcon(
                          MetaGymIcons.commEmail,
                          size: 16,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _email.isEmpty ? 'Chưa cập nhật email' : _email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const MetaGymIcon(
                            MetaGymIcons.callAudioBadge,
                            size: 16,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _phone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
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
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineDemoCard(MetaGymColors colors) {
    return ValueListenableBuilder<DemoUiStateMode>(
      valueListenable: OfflineDemoControl.mode,
      builder: (context, activeMode, _) {
        return MetaGymGlassCard(
          solid: false,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.science_rounded,
                    color: MetaGymTheme.brandOrange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chế độ Demo Offline',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colors.success.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Text(
                      'Không gọi API',
                      style: TextStyle(
                        color: colors.success,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Chuyển trạng thái dữ liệu mẫu để kiểm thử giao diện (Trống, Đang tải, Lỗi, Bình thường):',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in DemoUiStateMode.values)
                    ChoiceChip(
                      label: Text(OfflineDemoControl.modeLabel(mode)),
                      selected: activeMode == mode,
                      onSelected: (_) {
                        OfflineDemoControl.mode.value = mode;
                        _showToast(
                          'Đã chuyển sang chế độ: ${OfflineDemoControl.modeLabel(mode)}',
                        );
                      },
                      selectedColor: MetaGymTheme.brandOrange,
                      backgroundColor: colors.metricPanelBg,
                      labelStyle: TextStyle(
                        color: activeMode == mode
                            ? MetaGymTheme.onPrimary
                            : colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: activeMode == mode
                            ? MetaGymTheme.brandOrange
                            : colors.metricPanelBorder,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await OfflineDemoControl.resetData();
                    if (!mounted) return;
                    await _reloadProfile();
                    _showToast('Đã đặt lại toàn bộ dữ liệu mẫu offline.');
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Đặt lại dữ liệu mẫu gốc'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    backgroundColor: colors.metricPanelBg,
                    side: BorderSide(color: colors.metricPanelBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPersonalSectionRows(bool isCoach) {
    if (isCoach) {
      return [
        ProfileAccordionRow(
          title: 'Chuyên môn, Bằng cấp & Liên hệ',
          trailingBadge: _experienceYears > 0 ? '$_experienceYears năm' : null,
          onTap: _openCoachProfilePage,
        ),
      ];
    }
    return [
      ProfileAccordionRow(
        title: 'Thông tin cá nhân',
        onTap: _openPersonalInfoPage,
      ),
      ProfileAccordionRow(
        title: 'Thể trạng & Mục tiêu',
        onTap: _openTrainingProfilePage,
      ),
      ProfileAccordionRow(
        title: 'Khai báo thể trạng cho Coach',
        onTap: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const MemberHealthDeclarationPage(),
            ),
          );
          if (saved == true && mounted) {
            await _reloadProfile();
          }
        },
      ),
    ];
  }

  List<Widget> _buildActivityServiceRows(bool isCoach) {
    if (isCoach) {
      final currentUserId =
          context.read<SessionController?>()?.user?.id ?? 'coach';
      return [
        ProfileAccordionRow(
          title: 'Hội viên đang phụ trách',
          trailingBadge: _activeMemberCount != null
              ? '$_activeMemberCount/8'
              : null,
          onTap: () => _navigateOrPushWidget(
            route: '/coach/features/members',
            fallbackPage: const CoachMembersPage(),
          ),
        ),
        ProfileAccordionRow(
          title: 'Lịch dạy & buổi hẹn',
          onTap: () => _navigateOrPushWidget(
            route: '/coach/features/sessions',
            fallbackPage: CoachSessionsPage(coachId: currentUserId),
          ),
        ),
        ProfileAccordionRow(
          title: 'Lịch làm việc cố định (Tuần)',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => CoachWorkWeekPage(coachId: currentUserId),
            ),
          ),
        ),
        ProfileAccordionRow(
          title: 'Chặn khung giờ bận',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => CoachBlockedSlotsPage(coachId: currentUserId),
            ),
          ),
        ),
        ProfileAccordionRow(
          title: 'Giáo án tập luyện',
          onTap: () => _navigateOrPushWidget(
            route: '/coach/features/training',
            fallbackPage: const CoachTrainingPage(),
          ),
        ),
        ProfileAccordionRow(
          title: 'Thực đơn 7 ngày',
          onTap: () => _navigateOrPushWidget(
            route: '/coach/features/nutrition',
            fallbackPage: const CoachNutritionPage(structured: true),
          ),
        ),
        ProfileAccordionRow(
          title: 'Lịch sử buổi dạy',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const CoachBookingHistoryPage(coachMode: true),
            ),
          ),
        ),
        ProfileAccordionRow(
          title: 'Gói PT & Bảng giá',
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => CoachOffersPage(coachId: currentUserId),
            ),
          ),
        ),
        ProfileAccordionRow(
          title: 'Tin nhắn học viên',
          onTap: () => _navigateOrPushWidget(
            route: '/coach/features/messages',
            fallbackPage: ConversationsPage(
              currentUserId: currentUserId,
              coachMode: true,
            ),
          ),
        ),
        ProfileAccordionRow(
          title: 'Cuộc gọi 1:1 học viên',
          onTap: () => _navigateOrPushWidget(
            route: '/coach/features/calls',
            fallbackPage: CallsPage(
              currentUserId: currentUserId,
              coachMode: true,
            ),
          ),
        ),
        ProfileAccordionRow(
          title: 'Trợ lý AI Coach',
          onTap: () => _navigateOrPushWidget(
            route: '/coach/features/ai',
            fallbackPage: const AiConversationsPage(coachMode: true),
          ),
        ),
        ProfileAccordionRow(
          title: 'Phòng gym & Thiết bị',
          onTap: () => _navigateOrPushWidget(
            route: '/coach/features/gym',
            fallbackPage: const GymEquipmentPage(),
          ),
        ),
      ];
    }
    return [
      ProfileAccordionRow(
        title: 'Nhật ký & Số đo cơ thể',
        onTap: () => _navigateOrPushWidget(
          route: '/member/features/measurements',
          fallbackPage: const MemberMeasurementPage(),
        ),
      ),
      ProfileAccordionRow(
        title: 'Coach & Lịch hẹn',
        onTap: () => _navigateOrPushWidget(
          route: '/member/features/my-coach',
          fallbackPage: const MemberCoachingPage(),
        ),
      ),
      ProfileAccordionRow(
        title: 'Gói tập & Ưu đãi',
        onTap: () => _navigateOrPushWidget(
          route: '/member/features/membership',
          fallbackPage: const MembershipPage(),
        ),
      ),
    ];
  }

  List<Widget> _buildAccountSupportRows(bool isCoach) {
    if (isCoach) {
      return [
        ProfileAccordionRow(
          title: 'Thông báo Coach',
          onTap: _openCoachNotifications,
        ),
        ProfileAccordionRow(
          title: 'Bảo mật & Đổi mật khẩu',
          onTap: _openSecurityAccountPage,
        ),
        ProfileAccordionRow(
          title: 'Cài đặt ứng dụng',
          onTap: _openAppSettingsPage,
        ),
        ProfileAccordionRow(
          title: 'Phòng tập & Hỗ trợ',
          onTap: _openSupportInfoPage,
        ),
      ];
    }
    return [
      ProfileAccordionRow(title: 'Thông báo', onTap: _openCoachNotifications),
      ProfileAccordionRow(
        title: 'Bảo mật & Tài khoản',
        onTap: _openSecurityAccountPage,
      ),
      ProfileAccordionRow(
        title: 'Quyền riêng tư & Chia sẻ',
        onTap: _openPrivacySettingsPage,
      ),
      ProfileAccordionRow(
        title: 'Cài đặt ứng dụng',
        onTap: _openAppSettingsPage,
      ),
      ProfileAccordionRow(
        title: 'Phòng tập & Hỗ trợ',
        onTap: _openSupportInfoPage,
      ),
    ];
  }

  Widget _buildSignOutCard(MetaGymColors colors) {
    return MetaGymGlassCard(
      solid: false,
      padding: EdgeInsets.zero,
      child: MetaGymTap(
        key: const Key('profile-sign-out-btn'),
        onTap: _confirmSignOut,
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusCard),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MetaGymIcon(
                  MetaGymIcons.settingLogout,
                  size: MetaGymIconSize.sm,
                  color: colors.error,
                  adaptForLightMode: false,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 8),
                Text(
                  'Đăng xuất',
                  style: TextStyle(
                    color: colors.error,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCoachNotifications() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CoachNotificationsPage(coachMode: _isCoach),
      ),
    );
  }

  Future<void> _openPersonalInfoPage() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PersonalInfoDetailPage(
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
        builder: (_) => TrainingProfileDetailPage(
          fitnessGoal: _fitnessGoal,
          heightCm: _heightCm,
          weightKg: _latestWeightKg,
          experienceLevel: _experienceLevel,
          activityLevel: _activityLevel,
          onSave: (goal, height, updatedWeight, exp, act) async {
            setState(() {
              _fitnessGoal = goal;
              _heightCm = height;
              if (updatedWeight != null) {
                _latestWeightKg = updatedWeight;
              }
              _experienceLevel = exp;
              _activityLevel = act;
            });
            if (updatedWeight != null) {
              try {
                final measurementService = context
                    .read<MemberMeasurementService?>();
                if (measurementService != null) {
                  await measurementService.create({
                    'weightKg': double.parse(updatedWeight.toStringAsFixed(1)),
                    'notes': 'Cập nhật từ Thể trạng & Mục tiêu',
                  });
                }
              } catch (_) {
                // Không chặn việc lưu hồ sơ tập luyện nếu dịch vụ số đo lỗi tạm thời.
              }
            }
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

  Future<void> _openCoachProfilePage() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CoachProfileDetailPage(
          initialFullName: _fullName,
          initialPhone: _phone,
          email: _email,
          biography: _biography,
          specialties: _specialties,
          qualifications: _qualifications,
          experienceYears: _experienceYears,
          availabilityNote: _availabilityNote,
          onShowToast: _showToast,
          onSaveProfilePatch: (patch) async {
            setState(() {
              _fullName = patch['fullName'] as String? ?? _fullName;
              _phone = patch['phone'] as String? ?? _phone;
              _biography = patch['biography'] as String? ?? _biography;
              final nextSpecs = patch['specialties'];
              if (nextSpecs is List<String>) {
                _specialties = nextSpecs;
              }
              _qualifications =
                  patch['qualifications'] as String? ?? _qualifications;
              final nextYears = patch['experienceYears'];
              if (nextYears is int) {
                _experienceYears = nextYears;
              }
              _availabilityNote =
                  patch['availabilityNote'] as String? ?? _availabilityNote;
            });
            return _persistPatch(
              patch,
              successMessage: 'Đã lưu hồ sơ chuyên môn huấn luyện viên',
            );
          },
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
    if (updated == true && mounted) {
      _reloadProfile();
    }
  }

  Future<void> _openSecurityAccountPage() async {
    final effectiveRoleLabel = _isCoach ? 'Huấn luyện viên' : _roleLabel;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SecurityAccountDetailPage(
          email: _email,
          status: _status,
          roleLabel: effectiveRoleLabel,
          onChangePassword: (oldPass, newPass) async {
            final controller = context.read<ProfileController?>();
            if (controller == null) return false;
            return controller.changePassword(
              currentPassword: oldPass,
              newPassword: newPass,
            );
          },
          onSignOut: _confirmSignOut,
          onShowToast: _showToast,
        ),
      ),
    );
  }

  Future<void> _openPrivacySettingsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PrivacySettingsDetailPage(
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
        builder: (_) => AppSettingsDetailPage(
          onThemeModeChanged: context.read<ThemeController?>()?.setMode,
          initialReduceBlur:
              context.read<ThemeController?>()?.reduceBlur ?? false,
          onReduceBlurChanged: context.read<ThemeController?>()?.setReduceBlur,
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
        builder: (_) =>
            SupportInfoDetailPage(onShowToast: _showToast, isCoach: _isCoach),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final effectiveRoleLabel = _isCoach ? 'Huấn luyện viên' : _roleLabel;
    final confirmed = await showProfileSignOutDialog(
      context,
      fullName: _fullName,
      email: _email,
      roleLabel: effectiveRoleLabel,
      isCoach: _isCoach,
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
