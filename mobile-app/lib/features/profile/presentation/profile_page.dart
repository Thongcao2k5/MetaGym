import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_bottom_nav.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/auth/presentation/session_controller.dart';
import 'package:meta_gym_app/features/profile/presentation/profile_controller.dart';
import 'package:provider/provider.dart';

/// Màn hình Hồ sơ đồng bộ layout & chất liệu kính tối khói ấm từ Member Home.
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

  bool _initialized = false;
  VoidCallback? _activeSectionRefresh;

  // Trạng thái UI cục bộ bám sát đầy đủ schema backend `/users/me`.
  String _fullName = '';
  String _email = '';
  String _phone = '';
  UserRole _role = UserRole.member;
  String _status = 'ACTIVE';

  // Trường dành cho Hội viên (memberSchema)
  String _dateOfBirth = '1999-08-15';
  String _gender = 'MALE';
  double _heightCm = 174;
  String _fitnessGoal = 'Tăng cơ giảm mỡ · Duy trì 4 buổi/tuần';
  String _experienceLevel = 'INTERMEDIATE';
  String _activityLevel = 'MODERATE';
  String _healthNotes = 'Huyết áp ổn định, không bệnh nền';
  String _injuryNotes = 'Lưu ý nhẹ khớp vai phải khi đẩy nặng';
  String _dietaryPreferences = 'Ưu tiên đạm cao (~150g/ngày), ít đường';

  // Trường dành cho HLV (coachSchema)
  String _biography = 'Huấn luyện viên cá nhân chuyên Hypertrophy & Mobility.';
  List<String> _specialties = ['Hypertrophy', 'Giảm mỡ', 'Phục hồi vận động'];
  String _qualifications = 'CPT NASM · Dinh dưỡng thể thao cơ bản';
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

    final user = context.read<SessionController>().user;
    if (user != null) {
      _syncFromUser(user);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloadProfile();
    });
  }

  Future<void> _reloadProfile() async {
    try {
      final controller = context.read<ProfileController>();
      if (!await controller.load() || !mounted) return;
      final user = context.read<SessionController>().user;
      if (user != null) {
        setState(() => _syncFromUser(user));
      }
    } catch (_) {
      // Giữ trạng thái UI mặc định nếu chưa có backend hoặc controller.
    }
  }

  void _syncFromUser(AuthUser user) {
    _fullName = user.fullName.trim().isNotEmpty ? user.fullName : 'Hội viên Meta Gym';
    _email = user.email;
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
      if (health != null && health.trim().isNotEmpty) _healthNotes = health.trim();

      final injury = p['injuryNotes'] as String?;
      if (injury != null && injury.trim().isNotEmpty) _injuryNotes = injury.trim();

      final diet = p['dietaryPreferences'] as String?;
      if (diet != null && diet.trim().isNotEmpty) {
        _dietaryPreferences = diet.trim();
      }
    } else if (user.role == UserRole.coach) {
      final bio = p['biography'] as String?;
      if (bio != null && bio.trim().isNotEmpty) _biography = bio.trim();

      final specs = p['specialties'];
      if (specs is List && specs.isNotEmpty) {
        _specialties = specs.map((e) => e.toString()).toList();
      }

      final qual = p['qualifications'] as String?;
      if (qual != null && qual.trim().isNotEmpty) _qualifications = qual.trim();

      final years = p['experienceYears'];
      if (years is int) _experienceYears = years;

      final avail = p['availabilityNote'] as String?;
      if (avail != null && avail.trim().isNotEmpty) {
        _availabilityNote = avail.trim();
      }
    }
  }

  String get _initials {
    final clean = _fullName.trim();
    final parts = clean.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
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

  void _showSavedToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2B2622),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x669C9084)),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: MetaGymTheme.progressGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Color(0xFFF7F9FC), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBottomPadding =
        widget.bottomPadding ?? MetaGymBottomNav.contentBottomPadding(context);

    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ProfileGymBackground(),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                effectiveBottomPadding + 24,
              ),
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildHeroProfileCard(),
                const SizedBox(height: 16),
                _buildSectionHeader('Danh mục hồ sơ'),
                const SizedBox(height: 8),
                _SmokedGlassCard(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    children: [
                      _ProfileVerticalButton(
                        icon: Icons.person_outline_rounded,
                        accentColor: MetaGymTheme.reflectionBlue,
                        title: 'Thông tin cá nhân',
                        subtitle: _phone.isNotEmpty
                            ? '$_fullName · $_phone'
                            : '$_fullName · Chưa có SĐT',
                        onTap: () => _openSectionPage(
                          title: 'Thông tin cá nhân',
                          subtitle: 'Chạm vào từng mục để chỉnh sửa',
                          buildContent: _buildPersonalInfoCard,
                        ),
                      ),
                      _rowDivider(),
                      _ProfileVerticalButton(
                        icon: _role == UserRole.coach
                            ? Icons.badge_outlined
                            : Icons.fitness_center_rounded,
                        accentColor: MetaGymTheme.brandOrange,
                        title: _role == UserRole.coach
                            ? 'Hồ sơ Huấn luyện viên'
                            : 'Thể trạng & Mục tiêu',
                        subtitle: _role == UserRole.coach
                            ? '$_experienceYears năm kinh nghiệm · ${_specialties.length} chuyên môn'
                            : '${_heightCm.round()} cm · ${_experienceLabel(_experienceLevel)} · ${_activityLabel(_activityLevel)}',
                        onTap: () => _openSectionPage(
                          title: _role == UserRole.coach
                              ? 'Hồ sơ Huấn luyện viên'
                              : 'Thể trạng & Mục tiêu',
                          subtitle: 'Chạm vào từng mục để cập nhật',
                          buildContent: _role == UserRole.coach
                              ? _buildCoachProfileCard
                              : _buildTrainingProfileCard,
                        ),
                      ),
                      _rowDivider(),
                      _ProfileVerticalButton(
                        icon: _role == UserRole.coach
                            ? Icons.schedule_rounded
                            : Icons.favorite_border_rounded,
                        accentColor: MetaGymTheme.progressGreen,
                        title: _role == UserRole.coach
                            ? 'Chuyên môn & Lịch rảnh'
                            : 'Sức khỏe & Dinh dưỡng',
                        subtitle: _role == UserRole.coach
                            ? _availabilityNote
                            : _dietaryPreferences,
                        onTap: () => _openSectionPage(
                          title: _role == UserRole.coach
                              ? 'Chuyên môn & Lịch rảnh'
                              : 'Sức khỏe & Dinh dưỡng',
                          subtitle: 'Lưu ý sức khỏe, chấn thương & ăn uống',
                          buildContent: _role == UserRole.coach
                              ? _buildCoachProfileCard
                              : _buildHealthNutritionCard,
                        ),
                      ),
                      _rowDivider(),
                      _ProfileVerticalButton(
                        icon: Icons.lock_outline_rounded,
                        accentColor: const Color(0xFFD5DEE8),
                        title: 'Đổi mật khẩu',
                        subtitle: 'Cập nhật mật khẩu bảo vệ tài khoản',
                        onTap: _openChangePasswordSheet,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SmokedGlassCard(
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: _confirmSignOut,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: MetaGymTheme.dangerCoral,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Đăng xuất',
                            style: TextStyle(
                              color: MetaGymTheme.dangerCoral,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MetaGymTheme.brandOrange,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'MG',
            style: TextStyle(
              color: Color(0xFF111317),
              fontSize: 13.5,
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
                style: TextStyle(
                  color: MetaGymTheme.brandOrange,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Hồ sơ cá nhân',
                style: TextStyle(
                  color: Color(0xFFF7F9FC),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        _ProfileIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Chỉnh sửa thông tin',
          onTap: _openPersonalInfoSheet,
        ),
      ],
    );
  }

  Widget _buildHeroProfileCard() {
    return _SmokedGlassCard(
      featured: true,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0x33FF5A36),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MetaGymTheme.brandOrange,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    color: MetaGymTheme.brandOrange,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x2423C997),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0x4D23C997),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            _roleLabel,
                            style: const TextStyle(
                              color: MetaGymTheme.progressGreen,
                              fontSize: 10,
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
                        color: Color(0xFFB8C2D0),
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
                        Text(
                          _status == 'ACTIVE'
                              ? 'Tài khoản đang hoạt động'
                              : 'Trạng thái: $_status',
                          style: const TextStyle(
                            color: Color(0xFF8E9AA8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_role == UserRole.member) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 0.7, color: Color(0x1FFFFFFF)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeroStatTile(
                    label: 'Chiều cao',
                    value: '${_heightCm.round()} cm',
                    onTap: _openTrainingProfileSheet,
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0x1FFFFFFF)),
                Expanded(
                  child: _HeroStatTile(
                    label: 'Trình độ',
                    value: _experienceLabel(_experienceLevel),
                    onTap: _openTrainingProfileSheet,
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0x1FFFFFFF)),
                Expanded(
                  child: _HeroStatTile(
                    label: 'Vận động',
                    value: _activityLabel(_activityLevel),
                    onTap: _openTrainingProfileSheet,
                  ),
                ),
              ],
            ),
          ] else if (_role == UserRole.coach) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 0.7, color: Color(0x1FFFFFFF)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeroStatTile(
                    label: 'Kinh nghiệm',
                    value: '$_experienceYears năm',
                    onTap: _openCoachProfileSheet,
                  ),
                ),
                Container(width: 1, height: 28, color: const Color(0x1FFFFFFF)),
                Expanded(
                  child: _HeroStatTile(
                    label: 'Chuyên môn',
                    value: '${_specialties.length} lĩnh vực',
                    onTap: _openCoachProfileSheet,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF9BA5B4),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return _SmokedGlassCard(
      borderRadius: BorderRadius.circular(16),
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
    return _SmokedGlassCard(
      borderRadius: BorderRadius.circular(16),
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
            icon: Icons.fitness_center_rounded,
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
    return _SmokedGlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          _ProfileRowTile(
            icon: Icons.favorite_border_rounded,
            label: 'Ghi chú sức khỏe',
            value: _healthNotes,
            onTap: _openHealthNutritionSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.healing_outlined,
            label: 'Tiền sử chấn thương',
            value: _injuryNotes,
            onTap: _openHealthNutritionSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.restaurant_outlined,
            label: 'Chế độ ăn uống',
            value: _dietaryPreferences,
            onTap: _openHealthNutritionSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildCoachProfileCard() {
    return _SmokedGlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          _ProfileRowTile(
            icon: Icons.badge_outlined,
            label: 'Giới thiệu',
            value: _biography,
            onTap: _openCoachProfileSheet,
          ),
          _rowDivider(),
          _ProfileRowTile(
            icon: Icons.star_outline_rounded,
            label: 'Chuyên môn',
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
            icon: Icons.schedule_rounded,
            label: 'Lịch rảnh hỗ trợ',
            value: _availabilityNote,
            onTap: _openCoachProfileSheet,
          ),
        ],
      ),
    );
  }

  Widget _rowDivider() =>
      const Divider(height: 1, thickness: 0.7, color: Color(0x2E9C9084));

  // ---------------------------------------------------------------------------
  // Bottom Sheets chỉnh sửa từng nhóm chức năng
  // ---------------------------------------------------------------------------

  Future<void> _openPersonalInfoSheet() async {
    final nameCtrl = TextEditingController(text: _fullName);
    final phoneCtrl = TextEditingController(text: _phone);
    var dob = _dateOfBirth;
    var gender = _gender;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _ProfileEditSheet(
          title: 'Thông tin cá nhân',
          subtitle: 'Cập nhật họ tên, liên hệ và thông tin cơ bản',
          onSave: () {
            final trimmedName = nameCtrl.text.trim();
            if (trimmedName.length < 2) {
              _showSavedToast('Họ và tên cần ít nhất 2 ký tự');
              return;
            }
            setState(() {
              _fullName = trimmedName;
              _phone = phoneCtrl.text.trim();
              _dateOfBirth = dob;
              _gender = gender;
            });
            _refreshBoth();
            Navigator.pop(ctx);
            _showSavedToast('Đã cập nhật thông tin cá nhân');
          },
          children: [
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
                  final initial = DateTime.tryParse(dob) ?? DateTime(1999, 8, 15);
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
                  decoration: _sheetInputDecoration('Ngày sinh'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dob,
                        style: const TextStyle(color: Color(0xFFF7F9FC)),
                      ),
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF9BA5B4),
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
                  color: Color(0xFFB8C2D0),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final code in ['MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'])
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => _ProfileEditSheet(
          title: 'Thể trạng & Mục tiêu',
          subtitle: 'Giúp Coach & AI cá nhân hóa giáo án tập luyện',
          onSave: () {
            setState(() {
              _fitnessGoal = goalCtrl.text.trim().isNotEmpty
                  ? goalCtrl.text.trim()
                  : _fitnessGoal;
              _heightCm = height;
              _experienceLevel = experience;
              _activityLevel = activity;
            });
            _refreshBoth();
            Navigator.pop(ctx);
            _showSavedToast('Đã cập nhật thể trạng & mục tiêu');
          },
          children: [
            _SheetTextField(
              controller: goalCtrl,
              label: 'Mục tiêu tập luyện',
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chiều cao',
                  style: TextStyle(
                    color: Color(0xFFB8C2D0),
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
            Slider(
              value: height.clamp(130, 220),
              min: 130,
              max: 220,
              divisions: 90,
              activeColor: MetaGymTheme.brandOrange,
              inactiveColor: const Color(0x3D9C9084),
              onChanged: (v) => setModalState(() => height = v),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trình độ tập luyện',
              style: TextStyle(
                color: Color(0xFFB8C2D0),
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
                color: Color(0xFFB8C2D0),
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfileEditSheet(
        title: 'Sức khỏe & Dinh dưỡng',
        subtitle: 'Lưu ý quan trọng để tránh chấn thương và tối ưu thực đơn',
        onSave: () {
          setState(() {
            _healthNotes = healthCtrl.text.trim();
            _injuryNotes = injuryCtrl.text.trim();
            _dietaryPreferences = dietCtrl.text.trim();
          });
          _refreshBoth();
          Navigator.pop(ctx);
          _showSavedToast('Đã cập nhật ghi chú sức khỏe & dinh dưỡng');
        },
        children: [
          _SheetTextField(
            controller: healthCtrl,
            label: 'Ghi chú sức khỏe',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _SheetTextField(
            controller: injuryCtrl,
            label: 'Tiền sử chấn thương',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          _SheetTextField(
            controller: dietCtrl,
            label: 'Chế độ / sở thích ăn uống',
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Future<void> _openCoachProfileSheet() async {
    final bioCtrl = TextEditingController(text: _biography);
    final specsCtrl = TextEditingController(text: _specialties.join(', '));
    final qualCtrl = TextEditingController(text: _qualifications);
    final yearsCtrl = TextEditingController(text: '$_experienceYears');
    final availCtrl = TextEditingController(text: _availabilityNote);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProfileEditSheet(
        title: 'Hồ sơ Huấn luyện viên',
        subtitle: 'Thông tin hiển thị với học viên Meta Gym',
        onSave: () {
          setState(() {
            _biography = bioCtrl.text.trim();
            _specialties = specsCtrl.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            _qualifications = qualCtrl.text.trim();
            _experienceYears =
                int.tryParse(yearsCtrl.text.trim()) ?? _experienceYears;
            _availabilityNote = availCtrl.text.trim();
          });
          _refreshBoth();
          Navigator.pop(ctx);
          _showSavedToast('Đã cập nhật hồ sơ Huấn luyện viên');
        },
        children: [
          _SheetTextField(
            controller: bioCtrl,
            label: 'Giới thiệu bản thân',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _SheetTextField(
            controller: specsCtrl,
            label: 'Chuyên môn (cách nhau bởi dấu phẩy)',
          ),
          const SizedBox(height: 12),
          _SheetTextField(
            controller: qualCtrl,
            label: 'Bằng cấp & Chứng chỉ',
          ),
          const SizedBox(height: 12),
          _SheetTextField(
            controller: yearsCtrl,
            label: 'Số năm kinh nghiệm',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _SheetTextField(
            controller: availCtrl,
            label: 'Lịch rảnh hỗ trợ',
          ),
        ],
      ),
    );
  }

  Future<void> _openChangePasswordSheet() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    var hideCurrent = true;
    var hideNew = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final newPwd = newCtrl.text;
          final hasLength = newPwd.length >= 8;
          final hasUpper = RegExp('[A-Z]').hasMatch(newPwd);
          final hasLower = RegExp('[a-z]').hasMatch(newPwd);
          final hasDigit = RegExp('[0-9]').hasMatch(newPwd);
          final matches = newPwd.isNotEmpty && newPwd == confirmCtrl.text;

          return _ProfileEditSheet(
            title: 'Đổi mật khẩu',
            subtitle: 'Mật khẩu mới cần đủ mạnh để bảo vệ tài khoản',
            saveLabel: 'Cập nhật mật khẩu',
            onSave: () {
              if (currentCtrl.text.isEmpty ||
                  !hasLength ||
                  !hasUpper ||
                  !hasLower ||
                  !hasDigit ||
                  !matches) {
                _showSavedToast('Vui lòng kiểm tra lại điều kiện mật khẩu');
                return;
              }
              Navigator.pop(ctx);
              _showSavedToast('Đã cập nhật mật khẩu mới');
            },
            children: [
              _SheetTextField(
                controller: currentCtrl,
                label: 'Mật khẩu hiện tại',
                obscureText: hideCurrent,
                suffixIcon: IconButton(
                  icon: Icon(
                    hideCurrent ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF9BA5B4),
                    size: 18,
                  ),
                  onPressed: () =>
                      setModalState(() => hideCurrent = !hideCurrent),
                ),
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                controller: newCtrl,
                label: 'Mật khẩu mới',
                obscureText: hideNew,
                onChanged: (_) => setModalState(() {}),
                suffixIcon: IconButton(
                  icon: Icon(
                    hideNew ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF9BA5B4),
                    size: 18,
                  ),
                  onPressed: () => setModalState(() => hideNew = !hideNew),
                ),
              ),
              const SizedBox(height: 12),
              _SheetTextField(
                controller: confirmCtrl,
                label: 'Xác nhận mật khẩu mới',
                obscureText: hideNew,
                onChanged: (_) => setModalState(() {}),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _PasswordRuleChip(label: '≥ 8 ký tự', met: hasLength),
                  _PasswordRuleChip(label: 'Chữ hoa', met: hasUpper),
                  _PasswordRuleChip(label: 'Chữ thường', met: hasLower),
                  _PasswordRuleChip(label: 'Chữ số', met: hasDigit),
                  _PasswordRuleChip(label: 'Khớp mật khẩu', met: matches),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSectionPage({
    required String title,
    required String subtitle,
    required Widget Function() buildContent,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ProfileSectionPage(
          title: title,
          subtitle: subtitle,
          buildContent: buildContent,
          onRegisterRefresh: (refresh) => _activeSectionRefresh = refresh,
        ),
      ),
    );
    _activeSectionRefresh = null;
  }

  void _refreshBoth() {
    if (mounted) setState(() {});
    _activeSectionRefresh?.call();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF231F1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x529C9084)),
        ),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(
            color: Color(0xFFF7F9FC),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi Meta Gym không?',
          style: TextStyle(color: Color(0xFFB8C2D0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF9BA5B4)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MetaGymTheme.dangerCoral,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<SessionController>().signOut();
    }
  }
}

// =============================================================================
// 4 nút menu chính & trang chi tiết bên trong
// =============================================================================

class _ProfileVerticalButton extends StatelessWidget {
  const _ProfileVerticalButton({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF9BA5B4),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF7B8794),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSectionPage extends StatefulWidget {
  const _ProfileSectionPage({
    required this.title,
    required this.subtitle,
    required this.buildContent,
    required this.onRegisterRefresh,
  });

  final String title;
  final String subtitle;
  final Widget Function() buildContent;
  final void Function(VoidCallback refresh) onRegisterRefresh;

  @override
  State<_ProfileSectionPage> createState() => _ProfileSectionPageState();
}

class _ProfileSectionPageState extends State<_ProfileSectionPage> {
  @override
  void initState() {
    super.initState();
    widget.onRegisterRefresh(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaGymTheme.darkCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ProfileGymBackground(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Row(
                  children: [
                    _ProfileIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: 'Quay lại',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Color(0xFFF7F9FC),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              color: Color(0xFF9BA5B4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                widget.buildContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Nền ảnh phòng gym đồng bộ Member Home
// =============================================================================

class _ProfileGymBackground extends StatelessWidget {
  const _ProfileGymBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: MetaGymTheme.darkCanvas),
        if (!MetaGymTheme.isFlutterTestEnvironment)
          Opacity(
            opacity: 0.72,
            child: Image.asset(
              'assets/images/gym_banner.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.25),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xD90E0C0A),
                Color(0x9E14110E),
                Color(0xF00B0A08),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Thẻ kính tối khói ấm (đồng bộ Member Home, không bóng nhựa)
// =============================================================================

class _SmokedGlassCard extends StatelessWidget {
  const _SmokedGlassCard({
    required this.child,
    this.borderRadius,
    this.padding,
    this.featured = false,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(MetaGymTheme.radiusCard);
    final enableBlur = featured && !MetaGymTheme.isFlutterTestEnvironment;

    final body = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: featured ? const Color(0xB325201C) : const Color(0xB8211C19),
        borderRadius: radius,
        border: Border.all(
          color: featured ? const Color(0x4DA79D92) : const Color(0x2E9C9084),
          width: 0.85,
        ),
      ),
      child: Stack(
        children: [
          if (featured)
            const Positioned(
              top: 0,
              left: 18,
              right: 18,
              height: 1,
              child: ColoredBox(color: Color(0x45FFF6EA)),
            ),
          if (padding != null) Padding(padding: padding!, child: child) else child,
        ],
      ),
    );

    if (!enableBlur) return body;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: body,
        ),
      ),
    );
  }
}

class _ProfileIconButton extends StatelessWidget {
  const _ProfileIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xA6231F1C),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x529C9084), width: 1.0),
            ),
            child: Icon(icon, color: const Color(0xFFF7F9FC), size: 18),
          ),
        ),
      ),
    );
  }
}

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9BA5B4),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFF7F9FC),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
    required this.onTap,
    this.isPlaceholder = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0x7A1E1A17),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFD5DEE8), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFF7F9FC),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: isPlaceholder
                          ? const Color(0xFF7B8794)
                          : const Color(0xFF9BA5B4),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF7B8794),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Bottom Sheet chỉnh sửa chung
// =============================================================================

class _ProfileEditSheet extends StatelessWidget {
  const _ProfileEditSheet({
    required this.title,
    required this.subtitle,
    required this.onSave,
    required this.children,
    this.saveLabel = 'Lưu thay đổi',
  });

  final String title;
  final String subtitle;
  final VoidCallback onSave;
  final List<Widget> children;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF211D1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0x669C9084), width: 1.0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x529C9084),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF7F9FC),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: MetaGymTheme.brandOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onSave,
                child: Text(
                  saveLabel,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _sheetInputDecoration(String label, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF9BA5B4), fontSize: 13),
    filled: true,
    fillColor: const Color(0x80151210),
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x4D9C9084)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0x4D9C9084)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: MetaGymTheme.brandOrange, width: 1.4),
    ),
  );
}

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(color: Color(0xFFF7F9FC), fontSize: 14),
      decoration: _sheetInputDecoration(label, suffixIcon: suffixIcon),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0x2EFF5A36) : const Color(0x80151210),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? MetaGymTheme.brandOrange
                : const Color(0x4D9C9084),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFFF7F9FC) : const Color(0xFFB8C2D0),
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PasswordRuleChip extends StatelessWidget {
  const _PasswordRuleChip({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: met ? const Color(0x2423C997) : const Color(0x52151210),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: met ? const Color(0x6623C997) : const Color(0x3D9C9084),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_rounded : Icons.circle_outlined,
            size: 12,
            color: met ? MetaGymTheme.progressGreen : const Color(0xFF8E9AA8),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: met ? MetaGymTheme.progressGreen : const Color(0xFF9BA5B4),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
