import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Level 3 Overlay Glass Modal hiển thị mã QR Check-in động theo ngày
/// (đồng bộ 1:1 với `data-qr-modal` trong `tab1-home.js`).
Future<void> showMemberQrCheckinModal(
  BuildContext context, {
  required String memberName,
  required String memberCode,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: MetaGymTheme.scrim,
    builder: (dialogContext) => _MemberQrCheckinDialog(
      memberName: memberName,
      memberCode: memberCode,
    ),
  );
}

class _MemberQrCheckinDialog extends StatefulWidget {
  const _MemberQrCheckinDialog({
    required this.memberName,
    required this.memberCode,
  });

  final String memberName;
  final String memberCode;

  @override
  State<_MemberQrCheckinDialog> createState() => _MemberQrCheckinDialogState();
}

class _MemberQrCheckinDialogState extends State<_MemberQrCheckinDialog> {
  final _random = math.Random();
  late String _sessionToken;
  late String _todayLabel;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayLabel =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _sessionToken = _generateToken(now);
  }

  String _generateToken(DateTime now) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final suffix = List.generate(
      4,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
    return 'MG-$yy$mm$dd-$suffix';
  }

  void _regenerate() {
    setState(() => _sessionToken = _generateToken(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final isLight = MetaGymTheme.isLightPalette(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final enableBlur =
        !isLight && !disableAnimations && !MetaGymTheme.isFlutterTestEnvironment;
    final radius = BorderRadius.circular(MetaGymTheme.radiusGlassDock);

    final content = Container(
      constraints: const BoxConstraints(maxWidth: 356),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: isLight ? palette.surfaceSolid : MetaGymTheme.overlayGlass,
        borderRadius: radius,
        border: Border.all(
          color: isLight
              ? palette.borderSolid
              : MetaGymTheme.overlayGlassBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.success.withValues(
                      alpha: isLight ? 0.12 : 0.16,
                    ),
                    borderRadius: BorderRadius.circular(
                      MetaGymTheme.radiusFull,
                    ),
                  ),
                  child: Text(
                    '● Hôm nay · $_todayLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFeatures: MetaGymTheme.tabularFigures,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ID ${widget.memberCode}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: MetaGymTheme.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'QR Check-in Phòng Tập',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Mã riêng của ${widget.memberName} · Chỉ dùng trong ngày',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: isLight ? Border.all(color: palette.borderSolid) : null,
            ),
            child: QrImageView(
              data: 'METAGYM:CHECKIN:${widget.memberCode}:$_sessionToken',
              size: 172,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F1115),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0F1115),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: palette.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderSolid),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Mã phiên duy nhất',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _sessionToken,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          fontFeatures: MetaGymTheme.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Hết hạn 23:59 hôm nay · Đổi mã mới mỗi lần mở hoặc tạo lại',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 10.5,
                    fontFeatures: MetaGymTheme.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    key: const Key('qr-regen-btn'),
                    onPressed: _regenerate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MetaGymSvgIcon(
                          MetaGymIcons.commonRefresh,
                          size: 16,
                          fallbackIcon: Icons.refresh_rounded,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Tạo mã mới',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    key: const Key('qr-close-btn'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      child: enableBlur
          ? RepaintBoundary(
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: MetaGymTheme.overlayGlassBlur,
                    sigmaY: MetaGymTheme.overlayGlassBlur,
                  ),
                  child: content,
                ),
              ),
            )
          : content,
    );
  }
}
