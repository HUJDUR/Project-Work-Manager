import '../utils/sarajevo_time.dart';

enum WorkHoursStatus { completed, inProgress }

/// One booked block of work, already joined to the worker and project it
/// belongs to and split into regular and overtime hours - by the API. The ids and the two
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

  /// One row of `GET /WorkLogDetail/Hours`.
  factory WorkHoursEntry.fromJson(Map<String, dynamic> json) {
    final startedAt = SarajevoTime.fromApi(json['startedAt'] as String);
    final finishedAt = json['finishedAt'] as String?;

    return WorkHoursEntry(
      id: json['id'] as int,
      workLogId: json['workLogId'] as int,
      userId: json['userId'] as int,
      projectId: json['projectId'] as int,
      operationTypeId: json['operationTypeId'] as int,
      workerName: json['workerName'] as String,
      workerInitials: json['workerInitials'] as String,
      projectName: json['projectName'] as String,
      operationName: json['operationName'] as String,
      date: startedAt,
      startedAt: startedAt,
      finishedAt: finishedAt == null ? null : SarajevoTime.fromApi(finishedAt),
      regularHours: (json['regularHours'] as num).toDouble(),
      overtimeHours: (json['overtimeHours'] as num).toDouble(),
      status: json['inProgress'] as bool ? WorkHoursStatus.inProgress : WorkHoursStatus.completed,
    );
  }

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
