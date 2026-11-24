import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Trang Hồ sơ chuyên môn dành cho Huấn luyện viên (đồng bộ Core Design System).
class CoachProfileDetailPage extends StatefulWidget {
  const CoachProfileDetailPage({
    required this.biography,
    required this.specialties,
    required this.qualifications,
    required this.experienceYears,
    required this.availabilityNote,
    required this.onSave,
    super.key,
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
  State<CoachProfileDetailPage> createState() => _CoachProfileDetailPageState();
}

class _CoachProfileDetailPageState extends State<CoachProfileDetailPage> {
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
    final colors = MetaGymColors.of(context);
    return ProfileSubPageScaffold(
      eyebrow: 'Hồ sơ Huấn luyện viên',
      title: 'Chuyên môn & Lịch dạy',
      body: MetaGymGlassCard(
        solid: false,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileLabeledTextField(
              controller: _bioCtrl,
              label: 'Giới thiệu bản thân (Bio)',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            ProfileLabeledTextField(
              controller: _specsCtrl,
              label: 'Chuyên môn (phân tách bằng dấu phẩy)',
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            ProfileLabeledTextField(
              controller: _qualCtrl,
              label: 'Chứng chỉ / Bằng cấp',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Số năm kinh nghiệm',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$_years năm',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: MetaGymTheme.brandOrange,
                inactiveTrackColor: colors.border,
                thumbColor: MetaGymTheme.brandOrange,
                overlayColor: MetaGymTheme.brandOrange.withValues(alpha: 0.16),
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
            ProfileLabeledTextField(
              controller: _availCtrl,
              label: 'Khung giờ dạy & Lưu ý lịch',
              maxLines: 2,
            ),
          ],
        ),
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: MetaGymTheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
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

/// Phương thức sinh trắc học cho màn hình 5.11 Bảo mật & Tài khoản.
enum _BiometricMethod { faceId, fingerprint }

extension _BiometricMethodX on _BiometricMethod {
  String get label => switch (this) {
    _BiometricMethod.faceId => 'Face ID',
    _BiometricMethod.fingerprint => 'Vân tay',
  };

  String get svgAsset => switch (this) {
    _BiometricMethod.faceId => MetaGymIcons.authFaceId,
    _BiometricMethod.fingerprint => MetaGymIcons.authFingerprint,
  };
}

/// Trang **5.11 Bảo mật & Tài khoản** đồng bộ `tab5-profile-sub.js` (`member-security`):
/// - Card 1 (`MetaGymHeroGlassCard`): Email + trạng thái tài khoản (`setting_security_shield.svg`)
/// - Card 2 (`MetaGymGlassCard`): Sinh trắc học (`auth_face_id.svg`) với badge trạng thái,
///   2 công tắc (Đăng nhập Face ID / Vân tay + Xác thực khi thanh toán) & modal thiết lập
/// - Card 3 (`MetaGymGlassCard`): Đổi mật khẩu đăng nhập (`setting_password_key.svg`)
/// - Card 4 (`MetaGymGlassCard`): Đăng xuất khỏi thiết bị này (`setting_logout.svg`)
/// - Thanh CTA đáy `.bottom-cta-dock`: `Cập nhật mật khẩu`.
class SecurityAccountDetailPage extends StatefulWidget {
  const SecurityAccountDetailPage({
    required this.email,
    required this.status,
    required this.roleLabel,
    required this.onChangePassword,
    required this.onSignOut,
    required this.onShowToast,
    this.initialBiometricLoginEnabled = false,
    this.initialBiometricPaymentEnabled = true,
    super.key,
  });

  final String email;
  final String status;
  final String roleLabel;
  final Future<bool> Function(String oldPassword, String newPassword)
  onChangePassword;
  final VoidCallback onSignOut;
  final void Function(String message, {bool isError}) onShowToast;
  final bool initialBiometricLoginEnabled;
  final bool initialBiometricPaymentEnabled;

  @override
  State<SecurityAccountDetailPage> createState() =>
      _SecurityAccountDetailPageState();
}

class _SecurityAccountDetailPageState extends State<SecurityAccountDetailPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  String? _errorText;
  bool _isSaving = false;

  late bool _biometricLoginEnabled = widget.initialBiometricLoginEnabled;
  late bool _biometricPaymentEnabled = widget.initialBiometricPaymentEnabled;
  _BiometricMethod _biometricMethod = _BiometricMethod.faceId;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _clearErrorOnEdit(String _) {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  Future<void> _handleBiometricLoginToggle(bool nextValue) async {
    if (!nextValue) {
      setState(() => _biometricLoginEnabled = false);
      widget.onShowToast('Đã tắt đăng nhập Sinh trắc học');
      return;
    }
    await _openBiometricSetupDialog();
  }

  Future<void> _openBiometricSetupDialog() async {
    final chosen = await _showBiometricSetupDialog(
      context,
      initialMethod: _biometricMethod,
    );
    if (!mounted || chosen == null) return;
    setState(() {
      _biometricMethod = chosen;
      _biometricLoginEnabled = true;
    });
    widget.onShowToast('Đã bật đăng nhập bằng ${chosen.label}');
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
    if (next == current) {
      setState(() => _errorText = 'Mật khẩu mới cần khác mật khẩu hiện tại');
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

    bool ok = false;
    try {
      ok = await widget.onChangePassword(current, next);
    } catch (_) {
      ok = false;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
    if (!mounted) return;
    if (ok) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      widget.onShowToast('Đã đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
      }
    } else {
      setState(
        () => _errorText =
            'Không thể đổi mật khẩu. Vui lòng kiểm tra lại mật khẩu hiện tại.',
      );
    }
  }

  Widget _passwordToggle({
    required Key key,
    required bool hidden,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      onPressed: onPressed,
      icon: MetaGymIcon(
        hidden ? MetaGymIcons.authShowPassword : MetaGymIcons.authHidePassword,
        size: MetaGymIconSize.sm,
        excludeFromSemantics: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isActive = widget.status.trim().toUpperCase() == 'ACTIVE';
    final displayEmail = widget.email.trim().isNotEmpty
        ? widget.email.trim()
        : 'member@metagym.vn';

    return ProfileSubPageScaffold(
      eyebrow: 'Tài khoản & Thiết bị',
      title: 'Bảo mật & Tài khoản',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card 1: Thông tin tài khoản (Warm Smoked-Glass Card khớp 5.11)
          MetaGymHeroGlassCard(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const _QuickIconWell(
                  svgAsset: MetaGymIcons.settingSecurityShield,
                  size: 42,
                  iconSize: MetaGymIconSize.md,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '● Tài khoản ${widget.roleLabel} · ${isActive ? 'Đang hoạt động' : 'Chờ kích hoạt'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isActive ? colors.success : colors.warning,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 2: Sinh trắc học (Face ID / Vân tay) khớp tab5-profile-sub.js 5.11
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const MetaGymIcon(
                      MetaGymIcons.authFaceId,
                      size: MetaGymIconSize.sm,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Sinh trắc học',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 0,
                      child: _StatusPill(
                        key: const Key('security-bio-status-pill'),
                        label: _biometricLoginEnabled
                            ? '● Đang bật (${_biometricMethod.label})'
                            : '● Chưa bật',
                        accentColor: _biometricLoginEnabled
                            ? colors.success
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _SettingToggleRow(
                  switchKey: const Key('security-bio-login-toggle'),
                  title: 'Đăng nhập Face ID / Vân tay',
                  subtitle: 'Mở ứng dụng nhanh sau khi đăng nhập tài khoản',
                  value: _biometricLoginEnabled,
                  onChanged: _handleBiometricLoginToggle,
                ),
                _buildWarmDivider(colors),
                _SettingToggleRow(
                  switchKey: const Key('security-bio-payment-toggle'),
                  title: 'Xác thực khi thanh toán',
                  subtitle: 'Yêu cầu sinh trắc học khi mua hoặc nâng cấp gói',
                  value: _biometricPaymentEnabled,
                  onChanged: (next) {
                    setState(() => _biometricPaymentEnabled = next);
                    widget.onShowToast(
                      next
                          ? 'Đã bật xác thực sinh trắc học khi thanh toán'
                          : 'Đã tắt xác thực sinh trắc học khi thanh toán',
                    );
                  },
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    key: const Key('security-bio-setup-btn'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.metricPanelBg,
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.metricPanelBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _openBiometricSetupDialog,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const MetaGymIcon(
                          MetaGymIcons.authFingerprint,
                          size: MetaGymIconSize.xs,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Thiết lập Face ID / Vân tay',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 12),

          // Card 3: Đổi mật khẩu đăng nhập
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const MetaGymIcon(
                      MetaGymIcons.settingPasswordKey,
                      size: MetaGymIconSize.sm,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Đổi mật khẩu đăng nhập',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Mật khẩu mới dài ít nhất 8 ký tự, có chữ hoa, chữ thường và chữ số.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                ProfileLabeledTextField(
                  key: const Key('security-current-pass-field'),
                  controller: _currentCtrl,
                  label: 'Mật khẩu hiện tại',
                  obscureText: _hideCurrent,
                  onChanged: _clearErrorOnEdit,
                  trailing: _passwordToggle(
                    key: const Key('security-current-pass-eye'),
                    hidden: _hideCurrent,
                    onPressed: () =>
                        setState(() => _hideCurrent = !_hideCurrent),
                  ),
                ),
                const SizedBox(height: 12),
                ProfileLabeledTextField(
                  key: const Key('security-new-pass-field'),
                  controller: _newCtrl,
                  label: 'Mật khẩu mới',
                  obscureText: _hideNew,
                  onChanged: _clearErrorOnEdit,
                  trailing: _passwordToggle(
                    key: const Key('security-new-pass-eye'),
                    hidden: _hideNew,
                    onPressed: () => setState(() => _hideNew = !_hideNew),
                  ),
                ),
                const SizedBox(height: 12),
                ProfileLabeledTextField(
                  key: const Key('security-confirm-pass-field'),
                  controller: _confirmCtrl,
                  label: 'Xác nhận mật khẩu mới',
                  obscureText: _hideConfirm,
                  onChanged: _clearErrorOnEdit,
                  trailing: _passwordToggle(
                    key: const Key('security-confirm-pass-eye'),
                    hidden: _hideConfirm,
                    onPressed: () =>
                        setState(() => _hideConfirm = !_hideConfirm),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('security-password-error'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.error.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: colors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 4: Đăng xuất khỏi thiết bị này
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                key: const Key('security-sign-out-btn'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.error.withValues(alpha: 0.08),
                  side: BorderSide(color: colors.error.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: widget.onSignOut,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MetaGymIcon(
                      MetaGymIcons.settingLogout,
                      size: 18,
                      color: colors.error,
                      adaptForLightMode: false,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Đăng xuất khỏi thiết bị này',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          key: const Key('security-update-password-btn'),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: MetaGymTheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          onPressed: _isSaving ? null : _handlePasswordChange,
          child: Text(
            _isSaving ? 'Đang cập nhật...' : 'Cập nhật mật khẩu',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Trang **5.12 Quyền riêng tư & Chia sẻ** đồng bộ `tab5-profile-sub.js` (`member-privacy`):
/// - Card 1 (`MetaGymGlassCard`): 3 công tắc chia sẻ dữ liệu với Coach & ảnh thành quả
/// - Card 2 (`MetaGymGlassCard`): Quyền thư viện ảnh thiết bị (`setting_photo_permission.svg`)
///   kèm trạng thái hiện tại + danh sách chọn mức quyền
/// - Thanh CTA đáy `.bottom-cta-dock`: `Lưu cài đặt quyền riêng tư`.
class PrivacySettingsDetailPage extends StatefulWidget {
  const PrivacySettingsDetailPage({
    required this.accessMode,
    required this.shareJournalWithCoach,
    required this.shareMeasurementsWithCoach,
    required this.onSave,
    this.allowAchievementPhotos = false,
    super.key,
  });

  final PhotoAccessMode accessMode;
  final bool shareJournalWithCoach;
  final bool shareMeasurementsWithCoach;
  final Future<void> Function(
    PhotoAccessMode mode,
    bool shareJournal,
    bool shareMeasurements,
  )
  onSave;
  final bool allowAchievementPhotos;

  @override
  State<PrivacySettingsDetailPage> createState() =>
      _PrivacySettingsDetailPageState();
}

class _PrivacySettingsDetailPageState extends State<PrivacySettingsDetailPage> {
  late PhotoAccessMode _mode = widget.accessMode;
  late bool _shareJournal = widget.shareJournalWithCoach;
  late bool _shareMeasurements = widget.shareMeasurementsWithCoach;
  late bool _allowAchievementPhotos = widget.allowAchievementPhotos;
  bool _saving = false;

  String _photoPermissionSummary(PhotoAccessMode mode) => switch (mode) {
    PhotoAccessMode.selectedOnly => 'Đang cho phép truy cập ảnh đã chọn',
    PhotoAccessMode.full => 'Đang cho phép truy cập đầy đủ thư viện ảnh',
    PhotoAccessMode.denied => 'Đang từ chối quyền truy cập thư viện ảnh',
    PhotoAccessMode.unset => 'Chưa cấp quyền truy cập thư viện ảnh',
  };

  Color _photoPermissionStatusColor(
    PhotoAccessMode mode,
    MetaGymColors colors,
  ) => switch (mode) {
    PhotoAccessMode.selectedOnly || PhotoAccessMode.full => colors.success,
    PhotoAccessMode.denied => colors.error,
    PhotoAccessMode.unset => colors.warning,
  };

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_mode, _shareJournal, _shareMeasurements);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return ProfileSubPageScaffold(
      eyebrow: 'Bảo vệ dữ liệu',
      title: 'Quyền riêng tư & Chia sẻ',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card 1: 3 công tắc quyền riêng tư khớp tab5-profile-sub.js 5.12
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingToggleRow(
                  switchKey: const Key('privacy-share-measurements-toggle'),
                  title: 'Chia sẻ chỉ số & Ảnh tiến độ',
                  subtitle: 'Cho phép Coach phụ trách xem biểu đồ cơ thể',
                  value: _shareMeasurements,
                  onChanged: (v) => setState(() => _shareMeasurements = v),
                ),
                _buildWarmDivider(colors),
                _SettingToggleRow(
                  switchKey: const Key('privacy-share-journal-toggle'),
                  title: 'Chia sẻ nhật ký dinh dưỡng',
                  subtitle: 'Coach đối chiếu khẩu phần ăn hàng ngày',
                  value: _shareJournal,
                  onChanged: (v) => setState(() => _shareJournal = v),
                ),
                _buildWarmDivider(colors),
                _SettingToggleRow(
                  switchKey: const Key('privacy-allow-achievement-toggle'),
                  title: 'Cho phép hiển thị ảnh thành quả',
                  subtitle: 'Chỉ khi bạn xác nhận trong mục Duyệt thành quả',
                  value: _allowAchievementPhotos,
                  onChanged: (v) => setState(() => _allowAchievementPhotos = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 2: Quyền thư viện ảnh thiết bị (.card-liquid khớp 5.12)
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const MetaGymIcon(
                      MetaGymIcons.settingPhotoPermission,
                      size: MetaGymIconSize.sm,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quyền thư viện ảnh thiết bị',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _photoPermissionSummary(_mode),
                            key: const Key('privacy-photo-status-text'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _photoPermissionStatusColor(_mode, colors),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildWarmDivider(colors),
                const SizedBox(height: 8),
                for (final option in PhotoAccessMode.values) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Material(
                      color: _mode == option
                          ? colors.metricPanelBg
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _mode == option
                              ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
                              : Colors.transparent,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: MetaGymTap(
                        key: Key('privacy-photo-mode-${option.name}'),
                        borderRadius: BorderRadius.circular(12),
                        selected: _mode == option,
                        semanticLabel: photoAccessModeLabel(option),
                        onTap: () => setState(() => _mode = option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 10,
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
                                    : colors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  photoAccessModeLabel(option),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: _mode == option
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          key: const Key('privacy-save-btn'),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: MetaGymTheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          onPressed: _saving ? null : _handleSave,
          child: Text(
            _saving ? 'Đang lưu...' : 'Lưu cài đặt quyền riêng tư',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Trang **5.13 Cài đặt ứng dụng** đồng bộ `tab5-profile-sub.js` (`member-app-settings`):
/// - Hàng 1: Giao diện hiển thị (`setting_theme_appearance.svg`) + chuyển nhanh `Tối` / `Sáng`
/// - Hàng 2: Đơn vị đo lường (`setting_unit_measurement.svg`) + pill `kg · cm` / `lbs · in`
/// - Hàng 3: Nhắc lịch tập & Dinh dưỡng (`setting_notifications_bell.svg`) + chọn khung giờ nhắc
/// - Hàng 4: Giảm hiệu ứng mờ (Pin yếu) (`setting_accessibility.svg`)
/// - Thanh CTA đáy `.bottom-cta-dock`: `Lưu cài đặt`.
class AppSettingsDetailPage extends StatefulWidget {
  const AppSettingsDetailPage({
    required this.unitSystem,
    required this.workoutReminderEnabled,
    required this.reminderTime,
    required this.onSave,
    this.initialReduceBlur = false,
    this.onThemeModeChanged,
    super.key,
  });

  final String unitSystem;
  final bool workoutReminderEnabled;
  final String reminderTime;
  final void Function(String unit, bool reminderEnabled, String time) onSave;
  final bool initialReduceBlur;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  @override
  State<AppSettingsDetailPage> createState() => _AppSettingsDetailPageState();
}

class _AppSettingsDetailPageState extends State<AppSettingsDetailPage> {
  late String _unit = widget.unitSystem;
  late bool _reminderEnabled = widget.workoutReminderEnabled;
  late String _time = widget.reminderTime;
  late bool _reduceBlur = widget.initialReduceBlur;
  bool _themeInitialized = false;
  bool _isLightMode = false;

  static const List<String> _timeOptions = <String>[
    '06:30',
    '17:30',
    '18:00',
    '19:30',
  ];

  bool get _isMetric => _unit != 'inch / lbs';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeInitialized) {
      _themeInitialized = true;
      _isLightMode = Theme.of(context).brightness == Brightness.light;
    }
  }

  void _selectThemeMode(bool nextIsLight) {
    if (_isLightMode == nextIsLight) return;
    setState(() => _isLightMode = nextIsLight);
    widget.onThemeModeChanged?.call(
      nextIsLight ? ThemeMode.light : ThemeMode.dark,
    );
  }

  void _toggleUnitSystem() {
    setState(() {
      _unit = _isMetric ? 'inch / lbs' : 'cm / kg';
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = _isLightMode ? MetaGymTheme.light : MetaGymTheme.dark;

    return Theme(
      data: activeTheme,
      child: Builder(
        builder: (themedContext) {
          final colors = MetaGymColors.of(themedContext);
          return ProfileSubPageScaffold(
            eyebrow: 'Tùy chỉnh trải nghiệm',
            title: 'Cài đặt ứng dụng',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetaGymGlassCard(
                  solid: _reduceBlur,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hàng 1: Giao diện hiển thị (Tối / Sáng)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const MetaGymIcon(
                              MetaGymIcons.settingThemeAppearance,
                              size: MetaGymIconSize.sm,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Giao diện hiển thị',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isLightMode
                                        ? 'Sáng · Crisp Daylight Glass'
                                        : 'Tối · Futuristic Performance Glass',
                                    key: const Key('app-settings-theme-desc'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              key: const Key('app-settings-theme-switch'),
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: colors.metricPanelBg,
                                borderRadius: BorderRadius.circular(
                                  MetaGymTheme.radiusFull,
                                ),
                                border: Border.all(
                                  color: colors.metricPanelBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _CompactThemeSegment(
                                    key: const Key('app-settings-theme-dark'),
                                    label: 'Tối',
                                    selected: !_isLightMode,
                                    onTap: () => _selectThemeMode(false),
                                  ),
                                  const SizedBox(width: 3),
                                  _CompactThemeSegment(
                                    key: const Key('app-settings-theme-light'),
                                    label: 'Sáng',
                                    selected: _isLightMode,
                                    onTap: () => _selectThemeMode(true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildWarmDivider(colors),

                      // Hàng 2: Đơn vị đo lường (kg · cm / lbs · in)
                      Semantics(
                        button: true,
                        label:
                            'Đơn vị đo lường, ${_isMetric ? 'kg và cm' : 'lbs và inch'}, chạm để chuyển đổi',
                        child: InkWell(
                          key: const Key('app-settings-unit-row'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: _toggleUnitSystem,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const MetaGymIcon(
                                  MetaGymIcons.settingUnitMeasurement,
                                  size: MetaGymIconSize.sm,
                                  excludeFromSemantics: true,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Đơn vị đo lường',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isMetric
                                            ? 'Hệ mét chuẩn quốc tế'
                                            : 'Hệ đo lường Anh – Mỹ',
                                        key: const Key(
                                          'app-settings-unit-desc',
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatusPill(
                                  key: const Key('app-settings-unit-pill'),
                                  label: _isMetric ? 'kg · cm' : 'lbs · in',
                                  tabularFigures: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _buildWarmDivider(colors),

                      // Hàng 3: Nhắc lịch tập & Dinh dưỡng + Khung giờ nhắc
                      _SettingToggleRow(
                        switchKey: const Key('app-settings-reminder-toggle'),
                        svgIcon: MetaGymIcons.settingNotificationsBell,
                        title: 'Nhắc lịch tập & Dinh dưỡng',
                        subtitle: 'Thông báo trước buổi tập 30 phút',
                        value: _reminderEnabled,
                        onChanged: (v) => setState(() => _reminderEnabled = v),
                      ),
                      if (_reminderEnabled) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 0, 0, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Khung giờ nhắc',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final t in _timeOptions)
                                    ProfileFilterPill(
                                      key: Key('app-settings-time-$t'),
                                      label: t,
                                      compact: true,
                                      selected: _time == t,
                                      onTap: () => setState(() => _time = t),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      _buildWarmDivider(colors),

                      // Hàng 4: Giảm hiệu ứng mờ (Pin yếu)
                      _SettingToggleRow(
                        switchKey: const Key('app-settings-reduce-blur-toggle'),
                        svgIcon: MetaGymIcons.settingAccessibility,
                        title: 'Giảm hiệu ứng mờ (Pin yếu)',
                        subtitle: 'Chuyển sang bề mặt đặc mượt hơn',
                        value: _reduceBlur,
                        onChanged: (v) => setState(() => _reduceBlur = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomBar: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                key: const Key('app-settings-save-btn'),
                style: FilledButton.styleFrom(
                  backgroundColor: MetaGymTheme.brandOrange,
                  foregroundColor: MetaGymTheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusInput,
                    ),
                  ),
                ),
                onPressed: () {
                  widget.onSave(_unit, _reminderEnabled, _time);
                  final nav = Navigator.of(themedContext);
                  if (nav.canPop()) {
                    nav.pop();
                  }
                },
                child: const Text(
                  'Lưu cài đặt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Trang **5.14 Phòng tập & Hỗ trợ** đồng bộ `tab5-profile-sub.js` (`member-support`)
/// và modal 3 kênh liên hệ (`openSupportContactModal` trong `screens-preview.html`):
/// - Card 1 (`MetaGymHeroGlassCard`): Logo MG + Meta Gym Flagship Studio
/// - Card 2 (`MetaGymGlassCard`): 5 thông tin phòng tập & phiên bản
/// - Thanh CTA đáy `.bottom-cta-dock`: `Liên hệ hỗ trợ ngay` (`setting_support_headset.svg`)
///   mở Level 3 Overlay Glass modal chọn Chat CSKH / Gọi Hotline 1900 6868 / Gửi Email CSKH.
class SupportInfoDetailPage extends StatelessWidget {
  const SupportInfoDetailPage({required this.onShowToast, super.key});

  final void Function(String message) onShowToast;

  Future<void> _openSupportModal(BuildContext context) async {
    final action = await _showSupportContactDialog(context);
    if (action == null) return;
    switch (action) {
      case _SupportContactChannel.chat:
        onShowToast('Đã mở phòng chat Hỗ trợ Meta Gym');
      case _SupportContactChannel.call:
        onShowToast('Đang kết nối tổng đài Meta Gym 1900 6868...');
        if (!MetaGymTheme.isFlutterTestEnvironment) {
          try {
            await launchUrl(Uri(scheme: 'tel', path: '19006868'));
          } catch (_) {}
        }
      case _SupportContactChannel.email:
        onShowToast('Đã mở soạn email tới cskh@metagym.vn');
        if (!MetaGymTheme.isFlutterTestEnvironment) {
          try {
            await launchUrl(
              Uri(
                scheme: 'mailto',
                path: 'cskh@metagym.vn',
                queryParameters: const <String, String>{
                  'subject': 'Hỗ trợ Hội viên Meta Gym',
                },
              ),
            );
          } catch (_) {}
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return ProfileSubPageScaffold(
      eyebrow: 'Meta Gym Center',
      title: 'Phòng tập & Hỗ trợ',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MetaGymHeroGlassCard(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF6A42), Color(0xFFFF4520)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0x40FFFFFF),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x52FF5E36),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'MG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta Gym Flagship Studio',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Không gian tập luyện hiệu suất cao',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SafeInfoKeyValueRow(
                  label: 'Giờ mở cửa',
                  value: '05:30 – 22:00 (Hàng ngày)',
                  tabularFigures: true,
                ),
                _buildWarmDivider(colors),
                _SafeInfoKeyValueRow(
                  label: 'Hotline hỗ trợ',
                  value: '1900 6868',
                  valueColor: colors.primaryText,
                  tabularFigures: true,
                ),
                _buildWarmDivider(colors),
                const _SafeInfoKeyValueRow(
                  label: 'Email CSKH',
                  value: 'cskh@metagym.vn',
                ),
                _buildWarmDivider(colors),
                const _SafeInfoKeyValueRow(
                  label: 'Địa chỉ',
                  value: '128 Nguyễn Huệ, Q.1, TP.HCM',
                ),
                _buildWarmDivider(colors),
                const _SafeInfoKeyValueRow(
                  label: 'Phiên bản ứng dụng',
                  value: 'v1.0.0 · Build 2026.11',
                  tabularFigures: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          key: const Key('support-contact-btn'),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: MetaGymTheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
            ),
          ),
          onPressed: () => _openSupportModal(context),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MetaGymIcon(
                MetaGymIcons.settingSupportHeadset,
                size: 20,
                color: MetaGymTheme.onPrimary,
                adaptForLightMode: false,
                excludeFromSemantics: true,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Liên hệ hỗ trợ ngay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Private shared helpers for 5.11–5.14 Member Profile Secondary Pages
// =============================================================================

Widget _buildWarmDivider(MetaGymColors colors) =>
    Divider(height: 1, color: colors.metricPanelBorder.withValues(alpha: 0.55));

class _QuickIconWell extends StatelessWidget {
  const _QuickIconWell({
    required this.svgAsset,
    this.size = 42,
    this.iconSize = MetaGymIconSize.md,
  });

  final String svgAsset;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isLight
            ? null
            : MetaGymTheme.brandOrange.withValues(alpha: 0.16),
        gradient: isLight
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8EEF7), Color(0xFFDCE5F2)],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight
              ? const Color(0xFFBAC7D9)
              : MetaGymTheme.brandOrange.withValues(alpha: 0.32),
        ),
      ),
      alignment: Alignment.center,
      child: MetaGymIcon(svgAsset, size: iconSize, excludeFromSemantics: true),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    this.accentColor,
    this.tabularFigures = false,
    super.key,
  });

  final String label;
  final Color? accentColor;
  final bool tabularFigures;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isAccent = accentColor != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isAccent
            ? accentColor!.withValues(alpha: 0.16)
            : colors.metricPanelBg,
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
        border: Border.all(
          color: isAccent
              ? accentColor!.withValues(alpha: 0.36)
              : colors.metricPanelBorder,
          width: 0.9,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isAccent ? accentColor : colors.textWarmMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: tabularFigures
              ? const [FontFeature.tabularFigures()]
              : null,
        ),
      ),
    );
  }
}

class _SettingToggleRow extends StatelessWidget {
  const _SettingToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.svgIcon,
    this.switchKey,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? svgIcon;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (svgIcon != null) ...[
              MetaGymIcon(
                svgIcon!,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              key: switchKey,
              value: value,
              onChanged: onChanged,
              thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
              activeTrackColor: MetaGymTheme.brandOrange,
              inactiveTrackColor: isLight
                  ? const Color(0xFFCBD4DF)
                  : const Color(0x33FFFFFF),
              trackOutlineColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactThemeSegment extends StatelessWidget {
  const _CompactThemeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? MetaGymTheme.brandOrange : Colors.transparent,
        borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MetaGymTheme.radiusFull),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? MetaGymTheme.onPrimary : colors.textSecondary,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafeInfoKeyValueRow extends StatelessWidget {
  const _SafeInfoKeyValueRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.tabularFigures = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool tabularFigures;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? colors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                fontFeatures: tabularFigures
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _wrapOverlayGlassDialog({
  required BuildContext context,
  required Widget child,
}) {
  final colors = MetaGymColors.of(context);
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  final panel = Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: colors.overlayGlass,
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusGlassDock),
              border: Border.all(color: colors.overlayGlassBorder, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 36,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    ),
  );

  if (disableAnimations || MetaGymTheme.isFlutterTestEnvironment) {
    return panel;
  }
  return BackdropFilter(
    filter: ImageFilter.blur(
      sigmaX: math.min(MetaGymTheme.overlayGlassBlur, 14),
      sigmaY: math.min(MetaGymTheme.overlayGlassBlur, 14),
    ),
    child: panel,
  );
}

Future<_BiometricMethod?> _showBiometricSetupDialog(
  BuildContext context, {
  required _BiometricMethod initialMethod,
}) {
  return showDialog<_BiometricMethod>(
    context: context,
    barrierColor: MetaGymColors.of(context).scrim,
    builder: (ctx) => _BiometricSetupDialog(initialMethod: initialMethod),
  );
}

class _BiometricSetupDialog extends StatefulWidget {
  const _BiometricSetupDialog({required this.initialMethod});

  final _BiometricMethod initialMethod;

  @override
  State<_BiometricSetupDialog> createState() => _BiometricSetupDialogState();
}

class _BiometricSetupDialogState extends State<_BiometricSetupDialog> {
  late _BiometricMethod _method = widget.initialMethod;
  bool _verified = false;

  Future<void> _handleVerify() async {
    if (_verified) return;
    setState(() => _verified = true);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (!disableAnimations && !MetaGymTheme.isFlutterTestEnvironment) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
    if (!mounted) return;
    Navigator.of(context).pop(_method);
  }

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    final ringColor = _verified ? colors.success : MetaGymTheme.brandOrange;
    return _wrapOverlayGlassDialog(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.metricPanelBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.metricPanelBorder),
            ),
            child: Row(
              children: [
                for (final option in _BiometricMethod.values)
                  Expanded(
                    child: Material(
                      color: _method == option
                          ? MetaGymTheme.brandOrange
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: Key('bio-modal-method-${option.name}'),
                        onTap: _verified
                            ? null
                            : () => setState(() => _method = option),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Text(
                            option.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _method == option
                                  ? MetaGymTheme.onPrimary
                                  : colors.textSecondary,
                              fontSize: 13,
                              fontWeight: _method == option
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ringColor.withValues(alpha: 0.16),
                border: Border.all(
                  color: ringColor.withValues(alpha: 0.72),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ringColor.withValues(alpha: 0.28),
                    blurRadius: 24,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: MetaGymIcon(
                _method.svgAsset,
                size: 38,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_verified) ...[
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.success,
                  size: 20,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  _verified
                      ? 'Đã xác thực ${_method.label}'
                      : 'Kích hoạt ${_method.label}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Liên kết ${_method.label} của thiết bị này để đăng nhập nhanh sau mỗi phiên sử dụng Meta Gym.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    key: const Key('bio-modal-cancel-btn'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: colors.metricPanelBg,
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.metricPanelBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _verified
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Để sau',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    key: const Key('bio-modal-verify-btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaGymTheme.brandOrange,
                      foregroundColor: MetaGymTheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _verified ? null : _handleVerify,
                    child: const Text(
                      'Xác thực ngay',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SupportContactChannel { chat, call, email }

Future<_SupportContactChannel?> _showSupportContactDialog(
  BuildContext context,
) {
  return showDialog<_SupportContactChannel>(
    context: context,
    barrierColor: MetaGymColors.of(context).scrim,
    builder: (ctx) {
      final colors = MetaGymColors.of(ctx);
      return _wrapOverlayGlassDialog(
        context: ctx,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Liên hệ Hỗ trợ Meta Gym',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: _StatusPill(
                    label: '● Trực tuyến',
                    accentColor: colors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn kênh hỗ trợ nhanh nhất cho bạn',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            _SupportChannelOptionTile(
              key: const Key('support-channel-chat'),
              svgAsset: MetaGymIcons.commChat,
              accentColor: MetaGymTheme.brandOrange,
              highlighted: true,
              title: 'Chat trực tuyến với CSKH',
              subtitle: 'Phản hồi nhanh trong ~2 phút',
              onTap: () => Navigator.of(ctx).pop(_SupportContactChannel.chat),
            ),
            const SizedBox(height: 8),
            _SupportChannelOptionTile(
              key: const Key('support-channel-call'),
              svgAsset: MetaGymIcons.callAudioBadge,
              accentColor: colors.success,
              title: 'Gọi Hotline 1900 6868',
              subtitle: '05:30 – 22:00 · Tất cả các ngày',
              tabularFigures: true,
              onTap: () => Navigator.of(ctx).pop(_SupportContactChannel.call),
            ),
            const SizedBox(height: 8),
            _SupportChannelOptionTile(
              key: const Key('support-channel-email'),
              svgAsset: MetaGymIcons.commEmail,
              accentColor: colors.info,
              title: 'Gửi Email CSKH',
              subtitle: 'cskh@metagym.vn',
              onTap: () => Navigator.of(ctx).pop(_SupportContactChannel.email),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                key: const Key('support-modal-close-btn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  backgroundColor: colors.metricPanelBg,
                  side: BorderSide(color: colors.metricPanelBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Đóng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _SupportChannelOptionTile extends StatelessWidget {
  const _SupportChannelOptionTile({
    required this.svgAsset,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
    this.tabularFigures = false,
    super.key,
  });

  final String svgAsset;
  final Color accentColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;
  final bool tabularFigures;

  @override
  Widget build(BuildContext context) {
    final colors = MetaGymColors.of(context);
    return MetaGymTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      semanticLabel: '$title, $subtitle',
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: highlighted
              ? MetaGymTheme.brandOrange.withValues(alpha: 0.12)
              : colors.metricPanelBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted
                ? MetaGymTheme.brandOrange.withValues(alpha: 0.42)
                : colors.metricPanelBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.36)),
              ),
              alignment: Alignment.center,
              child: MetaGymIcon(
                svgAsset,
                size: MetaGymIconSize.sm,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: tabularFigures
                          ? const [FontFeature.tabularFigures()]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                      fontFeatures: tabularFigures
                          ? const [FontFeature.tabularFigures()]
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: highlighted ? colors.primaryText : colors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
