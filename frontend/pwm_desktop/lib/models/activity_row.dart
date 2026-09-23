/// One row of the activities table: an `ActivityLog` with the user and
/// activity type it only carries ids for resolved to names.
class ActivityRow {
  const ActivityRow({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userInitials,
    required this.activityLogTypeId,
    required this.activityTypeName,
    required this.date,
  });

  final int id;

  final int userId;
  final String userName;
  final String userInitials;

  final int activityLogTypeId;

  /// "Log In", "Generated report - Monthly Work Hours", and the rest of the
  /// seeded `ActivityLogTypes` — already the full, human-readable description.
  final String activityTypeName;

  /// As the API sent it — unspecified-but-actually-UTC. Run it through
  /// `apiTimeToLocal` before showing it.
  final DateTime date;
}
