import 'package:arham_corporation/providers/profile_provider.dart';

class RouteLabelHelper {
  static bool useBeatLabel(ProfileProvider profile) {
    return profile.data?.profileSettings.any((element) =>
            element.variable == 'beatTourLabel' && element.value == 'N') ??
        false;
  }

  static String singularMaster(ProfileProvider profile) {
    return useBeatLabel(profile) ? 'Beat' : 'Route';
  }

  static String pluralMaster(ProfileProvider profile) {
    return useBeatLabel(profile) ? 'Beats' : 'Routes';
  }

  static String singularPlanner(ProfileProvider profile) {
    return useBeatLabel(profile) ? 'Beat' : 'Tour';
  }

  static String pluralPlanner(ProfileProvider profile) {
    return useBeatLabel(profile) ? 'Beats' : 'Tours';
  }

  // static String masterTitle(ProfileProvider profile) {
  //   return '${singular(profile)} Master';
  // }
  //
  // static String plannerTitle(ProfileProvider profile) {
  //   return '${singular(profile)} Planner';
  // }

  static String masterTitle(ProfileProvider profile) {
    return useBeatLabel(profile) ? 'Beat Master' : 'Route Master';
  }

  static String plannerTitle(ProfileProvider profile) {
    return useBeatLabel(profile) ? 'Beat Planner' : 'Tour Planner';
  }

  static String emptyState(ProfileProvider profile) {
    return 'No ${pluralMaster(profile).toLowerCase()} found';
  }

  static String addTitle(ProfileProvider profile) {
    return 'Add ${singularMaster(profile)}';
  }

  static String editTitle(ProfileProvider profile) {
    return 'Edit ${singularMaster(profile)}';
  }

  static String fieldLabel(ProfileProvider profile) {
    return '${singularMaster(profile)} name';
  }
}
