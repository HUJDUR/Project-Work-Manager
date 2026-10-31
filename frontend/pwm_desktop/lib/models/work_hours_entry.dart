import '../utils/sarajevo_time.dart';

enum WorkHoursStatus { completed, inProgress }

/// The longest note a block of work may carry - `WorkBookingRules.NoteMaxLength`
/// on the API.
const int workNoteMaxLength = 200;

/// One booked block of work, already joined to the worker and project it
/// belongs to and split into regular and overtime hours - by the API. The ids and the two
/// timestamps ride along so the details form can prefill and write back.
class WorkHoursEntry {
  const WorkHoursEntry({
    required this.id,
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
    this.note,
  });

  /// One row of `GET /WorkLogDetail/Hours`.
  factory WorkHoursEntry.fromJson(Map<String, dynamic> json) {
    final startedAt = SarajevoTime.fromApi(json['startedAt'] as String);
    final finishedAt = json['finishedAt'] as String?;

    return WorkHoursEntry(
      id: json['id'] as int,
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
      note: json['note'] as String?,
    );
  }

  final int id;

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

  /// What the worker wrote when clocking in, if anything.
  final String? note;

  double get totalHours => regularHours + overtimeHours;

  bool get isOvertime => overtimeHours > 0;
}

/// One page of `GET /WorkLogDetail/Hours`, with the totals of every row the
/// filters match - what the summary cards show.
class WorkHoursPage {
  const WorkHoursPage({
    required this.items,
    required this.totalCount,
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.workerCount,
  });

  factory WorkHoursPage.fromJson(Map<String, dynamic> json) => WorkHoursPage(
        items: [
          for (final row in json['items'] as List)
            WorkHoursEntry.fromJson(row as Map<String, dynamic>),
        ],
        totalCount: json['totalCount'] as int? ?? 0,
        totalHours: (json['totalHours'] as num).toDouble(),
        regularHours: (json['regularHours'] as num).toDouble(),
        overtimeHours: (json['overtimeHours'] as num).toDouble(),
        workerCount: json['workerCount'] as int,
      );

  final List<WorkHoursEntry> items;
  final int totalCount;
  final double totalHours;
  final double regularHours;
  final double overtimeHours;
  final int workerCount;
}
