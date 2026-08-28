enum WorkHoursStatus { completed, inProgress }

/// One booked block of work, already joined to the worker and project it
/// belongs to and split into regular and overtime hours.
class WorkHoursEntry {
  const WorkHoursEntry({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.workerName,
    required this.workerInitials,
    required this.projectName,
    required this.operationName,
    required this.date,
    required this.regularHours,
    required this.overtimeHours,
    required this.status,
  });

  final int id;
  final int userId;
  final int projectId;
  final String workerName;
  final String workerInitials;
  final String projectName;
  final String operationName;
  final DateTime date;
  final double regularHours;
  final double overtimeHours;
  final WorkHoursStatus status;

  double get totalHours => regularHours + overtimeHours;

  bool get isOvertime => overtimeHours > 0;
}
