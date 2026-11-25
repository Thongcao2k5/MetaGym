import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_glass_surface.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';
import 'package:meta_gym_app/features/auth/domain/auth_models.dart';
import 'package:meta_gym_app/features/profile/presentation/widgets/profile_shared_widgets.dart';

/// Màn hình **5.2 Thông tin cá nhân** đồng bộ `tab5-profile.js` (`member-personal-info`):
/// - Card 1 (`MetaGymHeroGlassCard`): Avatar 64px + badge camera + nút mini cam `Tải ảnh từ điện thoại`
/// - Card 2 (`MetaGymGlassCard` solid Level 1): Form Họ và tên, Số điện thoại, Ngày sinh (`dd/MM/yyyy`), Giới tính (4 pill)
/// - Thanh CTA đáy `.bottom-cta-dock`: `Lưu thay đổi`.
class PersonalInfoDetailPage extends StatefulWidget {
  const PersonalInfoDetailPage({
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
    super.key,
  });

  final String fullName;
  final String phone;
  final String dateOfBirth;
  final String gender;
  final UserRole role;
  final String initials;
  final Uint8List? avatarBytes;
  final List<Uint8List> allowedPhotos;
  final PhotoAccessMode accessMode;
  final Future<bool> Function(
    Map<String, dynamic> patch,
    Uint8List? newAvatar,
    List<Uint8List> newAllowedPhotos,
    PhotoAccessMode newAccessMode,
  )
  onSave;
  final Future<PhotoAccessMode> Function() onRequestPermission;
  final Future<List<Uint8List>> Function() onLoadNativePhotos;
  final void Function(String message, {bool isError}) onShowToast;

  static String genderLabel(String code) => switch (code) {
    'MALE' => 'Nam',
    'FEMALE' => 'Nữ',
    'OTHER' => 'Khác',
    _ => 'Không tiết lộ',
  };

  static String formatDobDisplay(String isoDate) {
    final parsed = DateTime.tryParse(isoDate.trim());
    if (parsed == null) return isoDate.trim();
    final d = parsed.day.toString().padLeft(2, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    return '$d/$m/${parsed.year}';
  }

  @override
  State<PersonalInfoDetailPage> createState() => _PersonalInfoDetailPageState();
}

class _PersonalInfoDetailPageState extends State<PersonalInfoDetailPage> {
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
  late PhotoAccessMode _accessMode = widget.accessMode;
  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAvatarActionSheet() async {
    final action = await showProfileAvatarPickerSheet(
      context,
      accessMode: _accessMode,
      hasCustomAvatar: _avatar != null,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ProfileAvatarAction.camera:
        await _pickFromCamera();
      case ProfileAvatarAction.gallery:
        await _handleGalleryUpload();
      case ProfileAvatarAction.remove:
        setState(() => _avatar = null);
        widget.onShowToast('Đã gỡ ảnh đại diện hiện tại');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() => _avatar = bytes);
      }
    } catch (_) {
      widget.onShowToast(
        'Không thể mở máy ảnh trên thiết bị. Vui lòng kiểm tra quyền ứng dụng.',
        isError: true,
      );
    }
  }

  Future<void> _handleGalleryUpload() async {
    final chosenMode = await widget.onRequestPermission();
    if (!mounted) return;
    setState(() => _accessMode = chosenMode);

    if (chosenMode == PhotoAccessMode.denied) {
      setState(() => _allowedPhotos = []);
      widget.onShowToast('Đã từ chối quyền truy cập ảnh', isError: true);
      return;
    }

    try {
      if (chosenMode == PhotoAccessMode.selectedOnly) {
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

  Future<void> _pickBirthDate() async {
    final initialDate = DateTime.tryParse(_dob) ?? DateTime(1999, 5, 14);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = MetaGymColors.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isLight
              ? ColorScheme.light(
                  primary: MetaGymTheme.brandOrange,
                  onPrimary: MetaGymTheme.onPrimary,
                  surface: colors.surface,
                  onSurface: colors.textPrimary,
                )
              : ColorScheme.dark(
                  primary: MetaGymTheme.brandOrange,
                  onPrimary: MetaGymTheme.onPrimary,
                  surface: colors.surface,
                  onSurface: colors.textPrimary,
                ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked.toIso8601String().substring(0, 10));
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
    final colors = MetaGymColors.of(context);
    final isCoach = widget.role == UserRole.coach;
    return ProfileSubPageScaffold(
      eyebrow: 'Hồ sơ cá nhân',
      title: 'Thông tin cá nhân',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card 1: Ảnh đại diện (Warm Smoked-Glass Card khớp preview 5.2)
          MetaGymHeroGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Đổi ảnh đại diện',
                      child: InkWell(
                        onTap: _openAvatarActionSheet,
                        customBorder: const CircleBorder(),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: isCoach
                                    ? MetaGymTheme.coachAvatarBackground
                                    : null,
                                gradient: isCoach
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
                                  color: MetaGymTheme.brandOrange,
                                  width: 1.8,
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
                                      style: TextStyle(
                                        color: isCoach
                                            ? MetaGymTheme.coachAvatarForeground
                                            : MetaGymTheme.onPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
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
                                  color: MetaGymTheme.brandOrange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.surface,
                                    width: 2,
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ảnh đại diện (Avatar)',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Quyền truy cập thư viện: ${photoAccessModeLabel(_accessMode)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          MetaGymTap(
                            onTap: _openAvatarActionSheet,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: MetaGymTheme.brandOrange.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: MetaGymTheme.brandOrange.withValues(
                                    alpha: 0.50,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const MetaGymIcon(
                                    MetaGymIcons.mediaGallery,
                                    size: 16,
                                    excludeFromSemantics: true,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Tải ảnh từ điện thoại',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.primaryText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
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
                  ],
                ),
                if (_allowedPhotos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: colors.border),
                  const SizedBox(height: 10),
                  Text(
                    'Ảnh đã cấp quyền trên thiết bị:',
                    style: TextStyle(
                      color: colors.textSecondary,
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
                          onTap: () => setState(() => _avatar = photoBytes),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? MetaGymTheme.brandOrange
                                    : colors.border,
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
          const SizedBox(height: 14),

          // Card 2: Form Thông tin cá nhân (Solid Level 1 khớp preview 5.2)
          MetaGymGlassCard(
            solid: false,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileLabeledTextField(
                  controller: _nameCtrl,
                  label: 'Họ và tên',
                  hintText: 'Nhập họ và tên',
                  leadingSvg: MetaGymIcons.settingPersonalInfo,
                ),
                const SizedBox(height: 14),
                ProfileLabeledTextField(
                  controller: _phoneCtrl,
                  label: 'Số điện thoại',
                  hintText: '0909 123 456',
                  leadingSvg: MetaGymIcons.callAudioBadge,
                  keyboardType: TextInputType.phone,
                  tabularFigures: true,
                ),
                if (widget.role == UserRole.member) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Ngày sinh',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  MetaGymTap(
                    onTap: _pickBirthDate,
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusInput,
                    ),
                    semanticLabel: 'Chọn ngày sinh',
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.metricPanelBg,
                        borderRadius: BorderRadius.circular(
                          MetaGymTheme.radiusInput,
                        ),
                        border: Border.all(color: colors.metricPanelBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dob.isNotEmpty
                                  ? PersonalInfoDetailPage.formatDobDisplay(
                                      _dob,
                                    )
                                  : 'Chưa cập nhật',
                              style: TextStyle(
                                color: _dob.isNotEmpty
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          const MetaGymIcon(
                            MetaGymIcons.workoutPlanCalendar,
                            size: MetaGymIconSize.sm,
                            excludeFromSemantics: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Giới tính',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final code in const [
                        'MALE',
                        'FEMALE',
                        'OTHER',
                        'PREFER_NOT_TO_SAY',
                      ])
                        ProfileFilterPill(
                          label: PersonalInfoDetailPage.genderLabel(code),
                          selected: _gender == code,
                          onTap: () => setState(() => _gender = code),
                        ),
                    ],
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
          key: const Key('personal-info-save-btn'),
          style: FilledButton.styleFrom(
            backgroundColor: MetaGymTheme.brandOrange,
            foregroundColor: MetaGymTheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MetaGymTheme.radiusInput),
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
