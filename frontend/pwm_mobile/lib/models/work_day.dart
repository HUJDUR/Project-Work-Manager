import 'work_log_detail.dart';

/// One day's work, which is the row the My Hours list is built from.
///
/// A day rather than a shift: a worker can clock in more than once, and the
/// mockup's list counts days, so the blocks are grouped by the date they were
/// started on rather than by the `WorkLog` they hang off.
class WorkDay {
  WorkDay({required this.date, required this.blocks});

  /// Midnight of the day these blocks were started on.
  final DateTime date;

  /// Every block booked that day, **in the order it was worked**. A day reads
  /// as the shift ran — 07:00 before 12:00 — where the days themselves are
  /// listed newest first, because the one a worker wants is the one just ended.
  final List<WorkLogDetail> blocks;

  double get hours => blocks.fold<double>(0, (sum, block) => sum + block.hours);

  /// The same project booked twice in a day counts once.
  Set<int> get projectIds => blocks.map((block) => block.projectId).toSet();

  int get projectCount => projectIds.length;

  /// A block with no finish time is work still in progress — the shift has been
  /// clocked into but not out of, which is what the mobile app writes.
  bool get hasOpenBlock => blocks.any((block) => block.finishedAt == null);
}

/// One block of work with the names its ids stand for resolved, built only when
/// a day is opened. The list screen never needs these, so nothing fetches them
/// until then.
class WorkEntry {
  const WorkEntry({
    required this.projectName,
    required this.projectCode,
    required this.operationName,
    required this.startedAt,
    required this.hours,
    this.finishedAt,
  });

  final String projectName;
  final String projectCode;
  final String operationName;
  final DateTime startedAt;
  final double hours;
  final DateTime? finishedAt;

  bool get isOpen => finishedAt == null;

  /// "26-003 - Hall roof structure", the way the desktop writes a project.
  String get projectLabel =>
      projectCode.isEmpty ? projectName : '$projectCode - $projectName';
}
