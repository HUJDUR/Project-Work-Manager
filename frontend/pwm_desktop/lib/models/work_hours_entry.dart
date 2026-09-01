enum WorkHoursStatus { completed, inProgress }

/// One booked block of work, already joined to the worker and project it
/// belongs to and split into regular and overtime hours. The ids and the two
/// timestamps ride along so the details form can prefill and write back.
class WorkHoursEntry {
  const WorkHoursEntry({
    required this.id,
    required this.workLogId,
    required this.userId,
    required this.projectId,
    required this.operationTypeId,
    required this.workerName,
    required this.workerInitials,
    required this.projectName,
    required this.operationName,
    required this.date,
    required this.startedAt,
    required this.regularHours,
    required this.overtimeHours,
    required this.status,
    this.finishedAt,
  });

  final int id;

  /// The shift this block was booked against.
  final int workLogId;

  final int userId;
  final int projectId;
  final int operationTypeId;
  final String workerName;
  final String workerInitials;
  final String projectName;
  final String operationName;

  /// The day the block belongs to; [startedAt] carries the time of day too.
  final DateTime date;

  final DateTime startedAt;

  /// Null while the block is still open.
  final DateTime? finishedAt;

  final double regularHours;
  final double overtimeHours;
  final WorkHoursStatus status;

  double get totalHours => regularHours + overtimeHours;

  bool get isOvertime => overtimeHours > 0;
}
