import 'package:flutter/material.dart';
import 'package:meta_gym_app/core/theme/meta_gym_icons.dart';

/// Maps legacy Material [Icons] constants used in older feature screens and
/// shared controls to their corresponding custom SVG assets in [MetaGymIcons].
String? resolveMetaGymSvgAsset(IconData icon) {
  // === Navigation & Common Actions ===
  if (icon == Icons.arrow_back_rounded ||
      icon == Icons.arrow_back_ios_new_rounded) {
    return MetaGymIcons.commonBack;
  }
  if (icon == Icons.arrow_forward_rounded ||
      icon == Icons.chevron_right_rounded ||
      icon == Icons.chevron_right ||
      icon == Icons.north_east_rounded ||
      icon == Icons.open_in_new_rounded) {
    return MetaGymIcons.commonChevronRight;
  }
  if (icon == Icons.chevron_left_rounded) {
    return MetaGymIcons.commonChevronLeft;
  }
  if (icon == Icons.keyboard_arrow_up_rounded) {
    return MetaGymIcons.commonChevronUp;
  }
  if (icon == Icons.keyboard_arrow_down_rounded) {
    return MetaGymIcons.commonChevronDown;
  }
  if (icon == Icons.refresh_rounded ||
      icon == Icons.sync_rounded ||
      icon == Icons.replay_rounded ||
      icon == Icons.restart_alt_rounded) {
    return MetaGymIcons.commonRefresh;
  }
  if (icon == Icons.add_rounded || icon == Icons.add_circle_outline_rounded) {
    return MetaGymIcons.commonAdd;
  }
  if (icon == Icons.close_rounded ||
      icon == Icons.close ||
      icon == Icons.clear_rounded) {
    return MetaGymIcons.commonClose;
  }
  if (icon == Icons.search_rounded) {
    return MetaGymIcons.commonSearch;
  }
  if (icon == Icons.search_off_rounded) {
    return MetaGymIcons.stateEmptySearch;
  }
  if (icon == Icons.edit_outlined ||
      icon == Icons.edit_rounded ||
      icon == Icons.edit_note_rounded ||
      icon == Icons.rate_review_outlined) {
    return MetaGymIcons.commonEdit;
  }
  if (icon == Icons.delete_outline_rounded || icon == Icons.delete_outline) {
    return MetaGymIcons.commonDelete;
  }
  if (icon == Icons.copy_rounded) {
    return MetaGymIcons.commonCopy;
  }
  if (icon == Icons.tune_rounded) {
    return MetaGymIcons.commonFilter;
  }
  if (icon == Icons.more_vert_rounded) {
    return MetaGymIcons.commonMore;
  }
  if (icon == Icons.zoom_out_map_rounded) {
    return MetaGymIcons.commonExpandCollapse;
  }
  if (icon == Icons.info_outline_rounded || icon == Icons.science_rounded) {
    return MetaGymIcons.commonInfo;
  }
  if (icon == Icons.flip_rounded) {
    return MetaGymIcons.mediaRotate;
  }
  if (icon == Icons.block_rounded) {
    return MetaGymIcons.commBlock;
  }

  // === States ===
  if (icon == Icons.error_outline_rounded) {
    return MetaGymIcons.stateError;
  }
  if (icon == Icons.warning_amber_rounded) {
    return MetaGymIcons.stateWarning;
  }
  if (icon == Icons.check_rounded ||
      icon == Icons.check_circle_outline_rounded ||
      icon == Icons.check_circle_rounded ||
      icon == Icons.check_circle_outline ||
      icon == Icons.done_rounded ||
      icon == Icons.done_all_rounded ||
      icon == Icons.radio_button_checked_rounded) {
    return MetaGymIcons.stateSuccess;
  }
  if (icon == Icons.broken_image_outlined) {
    return MetaGymIcons.stateBrokenImage;
  }
  if (icon == Icons.cloud_off_rounded || icon == Icons.link_off_rounded) {
    return MetaGymIcons.stateOffline;
  }
  if (icon == Icons.hourglass_top_rounded) {
    return MetaGymIcons.stateLoading;
  }
  if (icon == Icons.local_fire_department_rounded ||
      icon == Icons.bolt_rounded) {
    return MetaGymIcons.streakFlame;
  }
  if (icon == Icons.qr_code_scanner_rounded) {
    return MetaGymIcons.qrScanFrame;
  }

  // === Auth, Security & Settings ===
  if (icon == Icons.lock_outline_rounded ||
      icon == Icons.lock_rounded ||
      icon == Icons.lock_clock_rounded ||
      icon == Icons.lock_clock_outlined) {
    return MetaGymIcons.settingPrivacyLock;
  }
  if (icon == Icons.visibility_outlined) {
    return MetaGymIcons.authShowPassword;
  }
  if (icon == Icons.visibility_off_outlined) {
    return MetaGymIcons.authHidePassword;
  }
  if (icon == Icons.face_rounded) {
    return MetaGymIcons.authFaceId;
  }
  if (icon == Icons.fingerprint_rounded) {
    return MetaGymIcons.authFingerprint;
  }
  if (icon == Icons.verified_outlined || icon == Icons.verified_rounded) {
    return MetaGymIcons.authVerified;
  }
  if (icon == Icons.verified_user_outlined ||
      icon == Icons.shield_outlined ||
      icon == Icons.security_rounded) {
    return MetaGymIcons.settingSecurityShield;
  }
  if (icon == Icons.logout_rounded) {
    return MetaGymIcons.settingLogout;
  }
  if (icon == Icons.notifications_none_rounded ||
      icon == Icons.notifications_active_outlined) {
    return MetaGymIcons.settingNotificationsBell;
  }
  if (icon == Icons.alternate_email_rounded ||
      icon == Icons.mark_email_read_outlined) {
    return MetaGymIcons.commEmail;
  }
  if (icon == Icons.admin_panel_settings_outlined) {
    return MetaGymIcons.adminBadge;
  }
  if (icon == Icons.accessibility_new_rounded) {
    return MetaGymIcons.settingAccessibility;
  }
  if (icon == Icons.wb_sunny_outlined ||
      icon == Icons.light_mode_outlined ||
      icon == Icons.nightlight_outlined) {
    return MetaGymIcons.settingThemeAppearance;
  }
  if (icon == Icons.location_on_outlined || icon == Icons.place_outlined) {
    return MetaGymIcons.locationPin;
  }
  if (icon == Icons.schedule_rounded ||
      icon == Icons.history_toggle_off_rounded ||
      icon == Icons.timer_off_outlined) {
    return MetaGymIcons.timeClock;
  }

  // === Workout, Training & Catalog ===
  if (icon == Icons.fitness_center_rounded ||
      icon == Icons.fitness_center_outlined ||
      icon == Icons.fitness_center) {
    return MetaGymIcons.equipDumbbell;
  }
  if (icon == Icons.sports_gymnastics_rounded) {
    return MetaGymIcons.equipBodyweight;
  }
  if (icon == Icons.history_rounded) {
    return MetaGymIcons.workoutHistory;
  }
  if (icon == Icons.calendar_today_rounded ||
      icon == Icons.calendar_today_outlined ||
      icon == Icons.calendar_month_rounded ||
      icon == Icons.calendar_month_outlined ||
      icon == Icons.event_available_rounded ||
      icon == Icons.event_available_outlined ||
      icon == Icons.event_outlined ||
      icon == Icons.today_rounded ||
      icon == Icons.edit_calendar_rounded) {
    return MetaGymIcons.workoutPlanCalendar;
  }
  if (icon == Icons.calendar_view_week_rounded) {
    return MetaGymIcons.actionCoachWorkweek;
  }
  if (icon == Icons.event_repeat_rounded) {
    return MetaGymIcons.actionCoachSessions;
  }
  if (icon == Icons.event_busy_rounded || icon == Icons.event_busy_outlined) {
    return MetaGymIcons.actionCoachBlockSlot;
  }
  if (icon == Icons.play_arrow_rounded ||
      icon == Icons.play_circle_outline_rounded ||
      icon == Icons.ondemand_video_rounded) {
    return MetaGymIcons.exerciseVideoPlay;
  }
  if (icon == Icons.pause_rounded || icon == Icons.pause_circle_outline) {
    return MetaGymIcons.workoutPause;
  }
  if (icon == Icons.menu_book_outlined ||
      icon == Icons.menu_book_rounded ||
      icon == Icons.assignment_outlined ||
      icon == Icons.format_list_numbered_rounded) {
    return MetaGymIcons.actionCurriculum;
  }
  if (icon == Icons.description_outlined ||
      icon == Icons.notes_rounded ||
      icon == Icons.archive_outlined ||
      icon == Icons.layers_outlined) {
    return MetaGymIcons.mediaDocument;
  }
  if (icon == Icons.track_changes_rounded) {
    return MetaGymIcons.settingTrainingGoal;
  }
  if (icon == Icons.spa_outlined) {
    return MetaGymIcons.restDayRecovery;
  }

  // === Nutrition ===
  if (icon == Icons.restaurant_menu_rounded ||
      icon == Icons.restaurant_menu_outlined ||
      icon == Icons.restaurant_outlined ||
      icon == Icons.restaurant_rounded ||
      icon == Icons.restaurant) {
    return MetaGymIcons.foodMeal;
  }
  if (icon == Icons.no_meals_outlined) {
    return MetaGymIcons.emptyNutrition;
  }
  if (icon == Icons.eco_outlined) {
    return MetaGymIcons.actionNutrition;
  }
  if (icon == Icons.wb_twilight_rounded) {
    return MetaGymIcons.mealBreakfast;
  }
  if (icon == Icons.wb_sunny_rounded) {
    return MetaGymIcons.mealLunch;
  }
  if (icon == Icons.nights_stay_rounded) {
    return MetaGymIcons.mealDinner;
  }
  if (icon == Icons.local_cafe_rounded) {
    return MetaGymIcons.mealSnack;
  }

  // === Progress & Media ===
  if (icon == Icons.monitor_weight ||
      icon == Icons.scale ||
      icon == Icons.scale_rounded) {
    return MetaGymIcons.bodyWeightScale;
  }
  if (icon == Icons.query_stats) {
    return MetaGymIcons.statsChartLine;
  }
  if (icon == Icons.monitor_heart_outlined) {
    return MetaGymIcons.statsHeartRate;
  }
  if (icon == Icons.photo_camera_outlined ||
      icon == Icons.photo_camera ||
      icon == Icons.add_a_photo_outlined ||
      icon == Icons.cameraswitch_outlined) {
    return MetaGymIcons.commonCamera;
  }
  if (icon == Icons.photo_library_outlined ||
      icon == Icons.image_outlined ||
      icon == Icons.photo_outlined ||
      icon == Icons.image_rounded ||
      icon == Icons.add_photo_alternate_outlined) {
    return MetaGymIcons.mediaGallery;
  }

  // === Communication, Calls, Community & Coaching ===
  if (icon == Icons.chat_bubble_outline_rounded || icon == Icons.comment) {
    return MetaGymIcons.commChat;
  }
  if (icon == Icons.auto_awesome_rounded) {
    return MetaGymIcons.navAiEmblem;
  }
  if (icon == Icons.person_outline_rounded || icon == Icons.person_rounded) {
    return MetaGymIcons.settingPersonalInfo;
  }
  if (icon == Icons.groups_outlined ||
      icon == Icons.group_outlined ||
      icon == Icons.people_alt_outlined ||
      icon == Icons.people_outline_rounded) {
    return MetaGymIcons.socialGroup;
  }
  if (icon == Icons.call_outlined || icon == Icons.call_rounded) {
    return MetaGymIcons.callAudioBadge;
  }
  if (icon == Icons.call_end_rounded) {
    return MetaGymIcons.workoutStop;
  }
  if (icon == Icons.videocam_outlined || icon == Icons.videocam_rounded) {
    return MetaGymIcons.callVideoBadge;
  }
  if (icon == Icons.videocam_off_rounded ||
      icon == Icons.videocam_off_outlined ||
      icon == Icons.mic_off_rounded) {
    return MetaGymIcons.commMute;
  }
  if (icon == Icons.mic_rounded) {
    return MetaGymIcons.commMic;
  }
  if (icon == Icons.volume_up_rounded || icon == Icons.volume_down_rounded) {
    return MetaGymIcons.commSpeaker;
  }
  if (icon == Icons.star_rounded) {
    return MetaGymIcons.socialStarRating;
  }
  if (icon == Icons.bookmark_rounded || icon == Icons.bookmark_border_rounded) {
    return MetaGymIcons.socialBookmark;
  }
  if (icon == Icons.emoji_events_outlined) {
    return MetaGymIcons.rewardTrophy;
  }
  if (icon == Icons.ac_unit_rounded) {
    return MetaGymIcons.coachingFreeze;
  }
  if (icon == Icons.gavel_rounded) {
    return MetaGymIcons.coachingTermination;
  }

  // === Membership & Payment ===
  if (icon == Icons.workspace_premium_rounded) {
    return MetaGymIcons.premiumCrown;
  }
  if (icon == Icons.credit_card_rounded) {
    return MetaGymIcons.premiumPaymentCard;
  }
  if (icon == Icons.local_offer_outlined ||
      icon == Icons.confirmation_number_outlined) {
    return MetaGymIcons.paymentCouponVoucher;
  }
  if (icon == Icons.receipt_long_rounded) {
    return MetaGymIcons.paymentReceiptInvoice;
  }

  return null;
}
