/// What the signed-in worker has put into one project — the detail screen's
/// "Your work on this project" card.
///
/// Built only when a project is opened: the list never shows it, and totalling
/// it for every row would mean reading the worker's whole history to draw a
/// page of names.
class ProjectWork {
  const ProjectWork({
    required this.hours,
    required this.days,
    this.lastWorked,
  });

  final double hours;

  /// Distinct calendar days with a booking on this project.
  final int days;

  /// The most recent booking's date, or null when there is none.
  final DateTime? lastWorked;

  bool get isEmpty => days == 0;

  static const none = ProjectWork(hours: 0, days: 0);
}
