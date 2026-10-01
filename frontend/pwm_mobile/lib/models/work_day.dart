import '../utils/sarajevo_time.dart';

/// One day's work, which is the row the My Hours list is built from - as
/// `GET /WorkLogDetail/MyDays` hands it over, its blocks already named.
///
/// A day rather than a shift: a worker can clock in more than once, and the
/// mockup's list counts days, so the blocks are grouped by the date they were
/// started on rather than by the `WorkLog` they hang off.
class WorkDay {
  const WorkDay({
    required this.date,
    required this.hours,
    required this.projectCount,
    required this.hasOpenBlock,
    required this.entries,
  });

  factory WorkDay.fromJson(Map<String, dynamic> json) => WorkDay(
        // A plain "2026-09-29" - the Sarajevo day itself, not an instant.
        date: DateTime.parse(json['date'] as String),
        hours: (json['hours'] as num).toDouble(),
        projectCount: json['projectCount'] as int,
        hasOpenBlock: json['inProgress'] as bool,
        entries: [
          for (final block in json['blocks'] as List)
            WorkEntry.fromJson(block as Map<String, dynamic>),
        ],
      );

  /// Midnight of the day these blocks were started on.
  final DateTime date;

  final double hours;

  /// The same project booked twice in a day counts once.
  final int projectCount;

  /// A block with no finish time is work still in progress - the shift has been
  /// clocked into but not out of.
  final bool hasOpenBlock;

  /// Every block booked that day, **in the order it was worked**. A day reads
  /// as the shift ran - 07:00 before 12:00 - where the days themselves are
  /// listed newest first, because the one a worker wants is the one just ended.
  final List<WorkEntry> entries;
}

/// One block of work on a day, with its project and operation named.
class WorkEntry {
  const WorkEntry({
    required this.projectName,
    required this.projectCode,
    required this.operationName,
    required this.startedAt,
    required this.hours,
    this.finishedAt,
    this.note,
  });

  factory WorkEntry.fromJson(Map<String, dynamic> json) {
    final finishedAt = json['finishedAt'] as String?;

    return WorkEntry(
      projectName: json['projectName'] as String,
      projectCode: json['projectCode'] as String,
      operationName: json['operationName'] as String,
      startedAt: SarajevoTime.fromApi(json['startedAt'] as String),
      finishedAt: finishedAt == null ? null : SarajevoTime.fromApi(finishedAt),
      hours: (json['hours'] as num).toDouble(),
      note: json['note'] as String?,
    );
  }

  final String projectName;
  final String projectCode;
  final String operationName;
  final DateTime startedAt;
  final double hours;
  final DateTime? finishedAt;

  /// What the worker added when clocking in, if anything.
  final String? note;

  bool get isOpen => finishedAt == null;

  /// "26-003 - Hall roof structure", the way the desktop writes a project.
  String get projectLabel =>
      projectCode.isEmpty ? projectName : '$projectCode - $projectName';
}

/// One worked day's figures, for the trend lines over the whole period.
class WorkDayTotal {
  const WorkDayTotal({required this.date, required this.hours, required this.projectCount});

  factory WorkDayTotal.fromJson(Map<String, dynamic> json) => WorkDayTotal(
        date: DateTime.parse(json['date'] as String),
        hours: (json['hours'] as num).toDouble(),
        projectCount: json['projectCount'] as int,
      );

  final DateTime date;
  final double hours;
  final int projectCount;
}

/// One page of `GET /WorkLogDetail/MyDays`, with the whole period's totals.
class WorkDaysPage {
  const WorkDaysPage({
    required this.days,
    required this.totalCount,
    required this.totalHours,
    required this.projectCount,
    required this.trend,
  });

  factory WorkDaysPage.fromJson(Map<String, dynamic> json) => WorkDaysPage(
        days: [
          for (final day in json['items'] as List) WorkDay.fromJson(day as Map<String, dynamic>),
        ],
        totalCount: json['totalCount'] as int? ?? 0,
        totalHours: (json['totalHours'] as num).toDouble(),
        projectCount: json['projectCount'] as int,
        trend: [
          for (final day in json['trend'] as List)
            WorkDayTotal.fromJson(day as Map<String, dynamic>),
        ],
      );

  final List<WorkDay> days;

  /// Days worked in the whole period, across every page.
  final int totalCount;

  final double totalHours;
  final int projectCount;

  /// Every worked day of the period, oldest first.
  final List<WorkDayTotal> trend;
}
