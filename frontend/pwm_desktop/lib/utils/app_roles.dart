import '../models/generated_report.dart';

/// The seeded `UserTypes.Type` values and what each one may reach.
///
/// Mirrored on the API by `pwm.Model.Access.Roles` and the `[Authorization]`
/// attributes over it — hiding a screen here only tidies the window, the
/// endpoints behind it refuse the call either way. Changing one means changing
/// the other.
abstract final class AppRoles {
  static const String admin = 'Admin';
  static const String workPreparation = 'Work preparation';
  static const String finances = 'Finances';
  static const String projectManager = 'Project manager';
  static const String productionWorker = 'Production worker';

  /// Navigation entries a role may not open, by the label in `MasterScreen`.
  /// An admin reaches everything, so it has no entry.
  static const Map<String, Set<String>> _blocked = {
    workPreparation: {'Work Hours', 'Workers', 'Reports', 'Administration'},
    finances: {'Workers', 'Recommendations', 'Administration'},
    projectManager: {'Workers', 'Administration'},
  };

  /// The shop floor books its hours from the mobile app; no desktop screen is
  /// theirs, so they are turned away at sign-in rather than shown an empty shell.
  static bool usesDesktop(String role) => role != productionWorker;

  static bool canOpen(String role, String destination) =>
      !(_blocked[role]?.contains(destination) ?? false);

  /// A project manager runs transports only — the monthly hours report is not theirs.
  static bool canRunReport(String role, ReportType report) =>
      role != projectManager || report == ReportType.transportLoads;

  /// The reports a role may pick from, in the order the screen offers them.
  static List<ReportType> reportsFor(String role) =>
      ReportType.values.where((report) => canRunReport(role, report)).toList();
}
