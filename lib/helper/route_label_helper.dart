import 'package:arham_corporation/providers/profile_provider.dart';

class RouteLabelHelper {
  static bool useBeatLabel(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            element.variable == 'beatTourLabel' && element.value == 'N') ??
        false;
  }

  static String singular(ProfileProvider profile) {
    return useBeatLabel(profile) ? 'Beat' : 'Tour';
  }

  static String plural(ProfileProvider profile) {
    return useBeatLabel(profile) ? 'Beats' : 'Tours';
  }

  static String masterTitle(ProfileProvider profile) {
    return '${singular(profile)} Master';
  }

  static String plannerTitle(ProfileProvider profile) {
    return '${singular(profile)} Planner';
  }

  static String emptyState(ProfileProvider profile) {
    return 'No ${plural(profile).toLowerCase()} found';
  }

  static String addTitle(ProfileProvider profile) {
    return 'Add ${singular(profile)}';
  }

  static String editTitle(ProfileProvider profile) {
    return 'Edit ${singular(profile)}';
  }

  static String fieldLabel(ProfileProvider profile) {
    return '${singular(profile)} name';
  }
}
