/// The project status life cycle, mirrored from the API's own
/// `pwm.Services.Business.ProjectStatusRules` the same way `AppRoles`
/// already mirrors the API's role/operation split. The server re-checks
/// every jump independently on `PATCH /Project/{id}/Status` - this copy only
/// decides which action buttons the overview screen offers, so a stale
/// button click still comes back as a refused request rather than a wrong one.
abstract final class ProjectStatusRules {
  static const String potential = 'Potential';
  static const String inProduction = 'In production';
  static const String onHold = 'On hold';
  static const String delivered = 'Delivered';
  static const String rejected = 'Rejected';

  /// Delivered, Rejected and On hold all lock every field but Notes - the
  /// difference is only that On hold can still move on from here.
  static const Set<String> editLocked = {delivered, rejected, onHold};

  static bool isEditLocked(String status) => editLocked.contains(status);

  /// The statuses [current] may move to next. On hold is the one stop that
  /// is not one-way: it resumes to whichever side of the shop floor it was
  /// paused from, told apart by whether production had already started.
  static Set<String> allowedNext(String current, {required bool hasStartedProduction}) {
    switch (current) {
      case potential:
        return {inProduction, onHold, rejected};
      case inProduction:
        return {onHold, delivered, rejected};
      case onHold:
        return {hasStartedProduction ? inProduction : potential};
      default:
        return {};
    }
  }
}
