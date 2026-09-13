/// What the dashboard shows: one worker's own hours, today and this week.
/// Built by `DashboardProvider` from that worker's blocks of work — the API has
/// no aggregate endpoint, so the sums happen client-side.
class WorkerSummary {
  const WorkerSummary({
    required this.todayHours,
    required this.todayProjects,
    required this.weekHours,
    required this.weekProjects,
    required this.weekStart,
  });

  final double todayHours;

  /// Distinct projects booked against today.
  final int todayProjects;

  final double weekHours;
  final int weekProjects;

  /// The Monday the week is counted from.
  final DateTime weekStart;
}
