import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/app_theme.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_svg_icon.dart';
import 'package:meta_gym_app/core/widgets/meta_gym_tap.dart';

/// Target muscle-group / training focus displayed on the 1-person anatomy tile.
enum MuscleFocus {
  chest,
  shoulders,
  back,
  arms,
  core,
  legs,
  glutes,
  upper,
  full,
  cardio,
  none,
}

/// Ordered muscle regions selectable in personal training & workouts.
const List<MuscleFocus> selectableMuscleFocuses = [
  MuscleFocus.chest,
  MuscleFocus.shoulders,
  MuscleFocus.back,
  MuscleFocus.arms,
  MuscleFocus.core,
  MuscleFocus.legs,
  MuscleFocus.glutes,
  MuscleFocus.full,
  MuscleFocus.cardio,
];

/// Returns the short Vietnamese display label for [focus].
String muscleFocusLabel(MuscleFocus focus) => switch (focus) {
  MuscleFocus.chest => 'Ngực',
  MuscleFocus.shoulders => 'Vai',
  MuscleFocus.back => 'Lưng · Xô',
  MuscleFocus.arms => 'Tay',
  MuscleFocus.core => 'Bụng',
  MuscleFocus.legs => 'Chân · Đùi',
  MuscleFocus.glutes => 'Mông',
  MuscleFocus.upper => 'Thân trên',
  MuscleFocus.full => 'Toàn thân',
  MuscleFocus.cardio => 'Cardio',
  MuscleFocus.none => 'Mặc định',
};

/// Serializes [focus] into a stable storage key, or `null` for `none`.
String? muscleFocusKey(MuscleFocus focus) =>
    focus == MuscleFocus.none ? null : focus.name;

/// Serializes a set of [MuscleFocus] items into a compact storage key string.
String? serializeMuscleFocuses(Iterable<MuscleFocus> focuses) {
  final list = focuses
      .where((item) => item != MuscleFocus.none)
      .map((item) => item.name)
      .toSet()
      .toList();
  if (list.isEmpty) return null;
  return list.join(',');
}

/// Parses a single key string into [MuscleFocus].
MuscleFocus muscleFocusFromKey(String? key) {
  if (key == null || key.trim().isEmpty) return MuscleFocus.none;
  final first = key.split(',').first.trim().toLowerCase();
  for (final value in MuscleFocus.values) {
    if (value.name == first) return value;
  }
  return MuscleFocus.none;
}

/// Parses a stored comma-separated focus key string into a set of [MuscleFocus].
Set<MuscleFocus> parseMuscleFocusSet(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const {};
  final result = <MuscleFocus>{};
  for (final token in raw.split(',')) {
    final normalized = token.trim().toLowerCase();
    for (final value in MuscleFocus.values) {
      if (value != MuscleFocus.none && value.name == normalized) {
        result.add(value);
      }
    }
  }
  return result;
}

/// Infers all active [MuscleFocus] targets from an explicit key, title, exercises, or muscles.
Set<MuscleFocus> resolveMuscleFocusSet(
  String? title, {
  List<String> exerciseNames = const [],
  List<String> targetMuscles = const [],
  String? explicitKey,
}) {
  final explicit = parseMuscleFocusSet(explicitKey);
  if (explicit.isNotEmpty) return explicit;

  final combined = [
    if (title != null && title.trim().isNotEmpty) title.trim(),
    ...targetMuscles,
    ...exerciseNames,
  ].join(' ').toLowerCase();
  if (combined.isEmpty) return const {};

  final matched = <MuscleFocus>{};
  if (combined.contains('toàn thân') || combined.contains('full body')) {
    matched.add(MuscleFocus.full);
  }
  if (combined.contains('cardio') ||
      combined.contains('hiit') ||
      combined.contains('tim mạch') ||
      combined.contains('chạy bộ') ||
      combined.contains('đạp xe')) {
    matched.add(MuscleFocus.cardio);
  }
  if (combined.contains('thân trên') || combined.contains('upper')) {
    matched.add(MuscleFocus.upper);
  }
  if (combined.contains('ngực') ||
      combined.contains('chest') ||
      combined.contains('bench')) {
    matched.add(MuscleFocus.chest);
  }
  if (combined.contains('vai') ||
      combined.contains('shoulder') ||
      combined.contains('delt')) {
    matched.add(MuscleFocus.shoulders);
  }
  if (combined.contains('lưng') ||
      combined.contains('xô') ||
      combined.contains('back') ||
      combined.contains('lat') ||
      combined.contains('pull') ||
      combined.contains('row')) {
    matched.add(MuscleFocus.back);
  }
  if (combined.contains('tay') ||
      combined.contains('bicep') ||
      combined.contains('tricep') ||
      combined.contains('arm')) {
    matched.add(MuscleFocus.arms);
  }
  if (combined.contains('bụng') ||
      combined.contains('core') ||
      combined.contains('abs') ||
      combined.contains('plank')) {
    matched.add(MuscleFocus.core);
  }
  if (combined.contains('mông') ||
      combined.contains('glute') ||
      combined.contains('hip thrust')) {
    matched.add(MuscleFocus.glutes);
  }
  if (combined.contains('chân') ||
      combined.contains('đùi') ||
      combined.contains('leg') ||
      combined.contains('squat') ||
      combined.contains('quad') ||
      combined.contains('bắp chân')) {
    matched.add(MuscleFocus.legs);
  }
  return matched;
}

/// Primary [MuscleFocus] resolved from [title] and optional exercise/muscle metadata.
MuscleFocus resolveMuscleFocus(
  String? title, {
  List<String> exerciseNames = const [],
  List<String> targetMuscles = const [],
  String? explicitKey,
}) {
  final set = resolveMuscleFocusSet(
    title,
    exerciseNames: exerciseNames,
    targetMuscles: targetMuscles,
    explicitKey: explicitKey,
  );
  if (set.isEmpty) return MuscleFocus.none;
  return set.first;
}

/// Returns `true` when [targets] should face the posterior (back) side.
///
/// Front muscles (chest, core, front shoulders) keep the front facing view;
/// posterior muscles (back/lats, glutes) flip to the back facing view unless
/// chest is explicitly highlighted.
bool isPosteriorMuscleView(Set<MuscleFocus> targets) {
  if (targets.isEmpty) return false;
  if (targets.contains(MuscleFocus.chest) ||
      targets.contains(MuscleFocus.core) ||
      targets.contains(MuscleFocus.full) ||
      targets.contains(MuscleFocus.cardio) ||
      targets.contains(MuscleFocus.upper)) {
    return false;
  }
  return targets.contains(MuscleFocus.back) ||
      targets.contains(MuscleFocus.glutes);
}

/// Human-readable label summarizing one or more selected [targets].
String summarizeMuscleFocuses(Set<MuscleFocus> targets) {
  final valid = targets.where((item) => item != MuscleFocus.none).toList();
  if (valid.isEmpty) return muscleFocusLabel(MuscleFocus.none);
  return valid.map(muscleFocusLabel).join(' · ');
}

/// Resolves the corresponding anatomical human-body SVG asset in
/// `assets/svg/muscles/` for one or more selected [targets].
String resolveMuscleSvgAsset(Set<MuscleFocus> targets) {
  final active = targets.where((item) => item != MuscleFocus.none).toSet();
  if (active.isEmpty) return MetaGymIcons.musclesDefault;

  if (active.length == 1) {
    return switch (active.first) {
      MuscleFocus.chest => MetaGymIcons.muscleChest,
      MuscleFocus.shoulders => MetaGymIcons.muscleShoulders,
      MuscleFocus.back => MetaGymIcons.muscleBack,
      MuscleFocus.arms => MetaGymIcons.muscleArms,
      MuscleFocus.core => MetaGymIcons.muscleCore,
      MuscleFocus.legs => MetaGymIcons.muscleLegs,
      MuscleFocus.glutes => MetaGymIcons.muscleGlutes,
      MuscleFocus.upper => MetaGymIcons.muscleUpper,
      MuscleFocus.full => MetaGymIcons.muscleFullBody,
      MuscleFocus.cardio => MetaGymIcons.muscleCardio,
      MuscleFocus.none => MetaGymIcons.musclesDefault,
    };
  }

  if (active.contains(MuscleFocus.full)) return MetaGymIcons.muscleFullBody;

  const lowerTargets = {MuscleFocus.legs, MuscleFocus.glutes};
  const upperTargets = {
    MuscleFocus.chest,
    MuscleFocus.shoulders,
    MuscleFocus.arms,
    MuscleFocus.back,
    MuscleFocus.upper,
  };

  if (active.every(lowerTargets.contains)) return MetaGymIcons.muscleLower;
  if (active.every(upperTargets.contains)) {
    return isPosteriorMuscleView(active)
        ? MetaGymIcons.muscleBack
        : MetaGymIcons.muscleUpper;
  }

  final hasUpper = active.any(upperTargets.contains);
  final hasLower = active.any(lowerTargets.contains);
  if (hasUpper && hasLower) return MetaGymIcons.muscleFullBody;

  return resolveMuscleSvgAsset({active.first});
}

/// Compact 1-person full-body SVG thumbnail highlighting target muscles.
class MuscleAnatomyTile extends StatelessWidget {
  const MuscleAnatomyTile({
    this.focus = MuscleFocus.none,
    this.focuses,
    this.width = 58,
    this.height = 68,
    this.isUpcoming = true,
    this.selected = false,
    super.key,
  });

  final MuscleFocus focus;
  final Set<MuscleFocus>? focuses;
  final double width;
  final double height;
  final bool isUpcoming;
  final bool selected;

  Set<MuscleFocus> get _resolvedTargets {
    if (focuses != null && focuses!.isNotEmpty) {
      return focuses!.where((item) => item != MuscleFocus.none).toSet();
    }
    if (focus != MuscleFocus.none) return {focus};
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final isLight = MetaGymTheme.isLightPalette(context);
    final palette = MetaGymTheme.paletteOf(context);
    final targets = _resolvedTargets;
    final hasFocus = targets.isNotEmpty;
    final radius = width <= 48 ? 11.0 : 14.0;
    return Opacity(
      opacity: isUpcoming ? 1.0 : 0.72,
      child: Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isLight
                ? const [Color(0xFFF3F6FB), Color(0xFFE5ECF5)]
                : const [Color(0xFF1B2230), Color(0xFF12161F)],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            width: selected ? 1.6 : 1.0,
            color: selected
                ? MetaGymTheme.brandOrange
                : hasFocus && isUpcoming
                ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
                : isLight
                ? palette.metricPanelBorder
                : const Color(0xFF2B3547),
          ),
          boxShadow: (selected || isUpcoming)
              ? [
                  BoxShadow(
                    color: selected
                        ? MetaGymTheme.brandOrange.withValues(
                            alpha: isLight ? 0.20 : 0.24,
                          )
                        : isLight
                        ? const Color(0x140F172A)
                        : const Color(0x59000000),
                    blurRadius: selected ? 14 : (isLight ? 10 : 12),
                    offset: Offset(0, isLight && !selected ? 3 : 5),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: MetaGymSvgIcon(
            resolveMuscleSvgAsset(targets),
            width: width - 6,
            height: height - 6,
            fit: BoxFit.contain,
            adaptForLightMode: false,
          ),
        ),
      ),
    );
  }
}

/// Interactive multi-group muscle selector with live 1-person preview card.
class MuscleFocusPicker extends StatelessWidget {
  const MuscleFocusPicker({
    required this.selectedKey,
    required this.onSelected,
    this.inferredTargets = const {},
    super.key,
  });

  final String? selectedKey;
  final ValueChanged<String?> onSelected;
  final Set<MuscleFocus> inferredTargets;

  void _toggleMuscle(Set<MuscleFocus> current, MuscleFocus toggled) {
    if (toggled == MuscleFocus.full || toggled == MuscleFocus.cardio) {
      if (current.length == 1 && current.contains(toggled)) {
        onSelected(null);
      } else {
        onSelected(toggled.name);
      }
      return;
    }

    final next = {...current}
      ..remove(MuscleFocus.full)
      ..remove(MuscleFocus.cardio)
      ..remove(MuscleFocus.none);

    if (next.contains(toggled)) {
      next.remove(toggled);
    } else {
      next.add(toggled);
    }
    onSelected(serializeMuscleFocuses(next));
  }

  @override
  Widget build(BuildContext context) {
    final palette = MetaGymTheme.paletteOf(context);
    final explicitTargets = parseMuscleFocusSet(selectedKey);
    final previewTargets = explicitTargets.isNotEmpty
        ? explicitTargets
        : inferredTargets;
    final viewLabel = previewTargets.isEmpty
        ? 'Mặc định (Toàn thân)'
        : '${summarizeMuscleFocuses(previewTargets)} · ${isPosteriorMuscleView(previewTargets) ? 'Mặt sau' : 'Mặt trước'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MuscleAnatomyTile(
              focuses: previewTargets,
              width: 54,
              height: 64,
              selected: previewTargets.isNotEmpty,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biểu tượng card tập',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    viewLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: previewTargets.isNotEmpty
                          ? palette.primaryText
                          : palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (explicitTargets.isNotEmpty)
              TextButton(
                onPressed: () => onSelected(null),
                child: Text(
                  'Mặc định',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final focus in selectableMuscleFocuses)
              _MuscleChoiceChip(
                label: muscleFocusLabel(focus),
                svgAsset: resolveMuscleSvgAsset({focus}),
                selected: explicitTargets.contains(focus),
                inferred:
                    explicitTargets.isEmpty && inferredTargets.contains(focus),
                onTap: () => _toggleMuscle(explicitTargets, focus),
              ),
          ],
        ),
      ],
    );
  }
}

class _MuscleChoiceChip extends StatelessWidget {
  const _MuscleChoiceChip({
    required this.label,
    required this.svgAsset,
    required this.selected,
    required this.inferred,
    required this.onTap,
  });

  final String label;
  final String svgAsset;
  final bool selected;
  final bool inferred;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = MetaGymTheme.isLightPalette(context);
    final palette = MetaGymTheme.paletteOf(context);
    final active = selected || inferred;
    return Material(
      color: Colors.transparent,
      child: MetaGymTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? palette.chipActiveBg
                : inferred
                ? MetaGymTheme.brandOrange.withValues(
                    alpha: isLight ? 0.08 : 0.10,
                  )
                : palette.surfaceRaised,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? MetaGymTheme.brandOrange
                  : active
                  ? MetaGymTheme.brandOrange.withValues(alpha: 0.45)
                  : palette.borderSolid,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MetaGymSvgIcon(
                svgAsset,
                width: 15,
                height: 22,
                fit: BoxFit.contain,
                adaptForLightMode: false,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? palette.chipActiveText
                        : active
                        ? (isLight ? palette.primaryText : const Color(0xFFFFB099))
                        : palette.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


