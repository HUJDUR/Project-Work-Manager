import 'generated_report.dart';

/// One row of the Recent Reports list: a `GeneratedReport` with its author
/// resolved and its stored `Parameters` JSON read back into a line the office
/// can recognise. The PDF is not stored, so the download button re-runs it.
class RecentReport {
  const RecentReport({
    required this.id,
    required this.type,
    required this.summary,
    required this.generatedAt,
    required this.generatedByName,
  });

  final int id;
  final ReportType type;

  /// What it was run for — the period, worker and project, or the date range.
  final String summary;

  /// Null when no activity log entry could be found for the run.
  final DateTime? generatedAt;
  final String generatedByName;

  String get title => type.label;
}
