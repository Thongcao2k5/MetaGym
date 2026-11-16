import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart';

export 'package:meta_gym_app/core/widgets/muscle_anatomy_tile.dart'
    show
        MuscleAnatomyTile,
        MuscleFocus,
        muscleFocusFromKey,
        muscleFocusKey,
        muscleFocusLabel,
        parseMuscleFocusSet,
        resolveMuscleFocus,
        resolveMuscleFocusSet,
        serializeMuscleFocuses;

/// Alias preserving Coach booking call sites while sharing core [MuscleFocus].
typedef CoachMuscleFocus = MuscleFocus;

/// Resolves [CoachMuscleFocus] from a Coach curriculum day title and optional exercises.
MuscleFocus resolveCoachMuscleFocus(
  String? title, {
  List<String> exerciseNames = const [],
}) => resolveMuscleFocus(title, exerciseNames: exerciseNames);

/// Resolves all target muscles from a Coach curriculum day title and optional exercises.
Set<MuscleFocus> resolveCoachMuscleFocusSet(
  String? title, {
  List<String> exerciseNames = const [],
}) => resolveMuscleFocusSet(title, exerciseNames: exerciseNames);

/// Compact dark-studio anatomical thumbnail used on Coach-linked booking cards.
class CoachMuscleAnatomyTile extends StatelessWidget {
  const CoachMuscleAnatomyTile({
    this.focus = MuscleFocus.none,
    this.focuses,
    this.isUpcoming = true,
    super.key,
  });

  final MuscleFocus focus;
  final Set<MuscleFocus>? focuses;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) =>
      MuscleAnatomyTile(focus: focus, focuses: focuses, isUpcoming: isUpcoming);
}
