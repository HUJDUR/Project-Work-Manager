import 'package:json_annotation/json_annotation.dart';

part 'generated_report.g.dart';

/// Mirrors the `ReportTypes` rows, whose Ids the API branches on. The two are
/// fixed: each is a different PDF with its own parameters and its own code path.
enum ReportType {
  monthlyWorkHours(1, 'Monthly Work Hours'),
  transportLoads(2, 'Transport & Loads');

  const ReportType(this.value, this.label);

  final int value;
  final String label;

  static ReportType fromValue(int? value) => ReportType.values
      .firstWhere((type) => type.value == value, orElse: () => monthlyWorkHours);
}

/// A report that was produced once. The PDF itself is not stored — downloading
/// it again re-runs [parameters], so it can never disagree with the work logs.
/// Who ran it and when is the `ActivityLog` entry pointing back here, not a column.
@JsonSerializable()
class GeneratedReport {
  const GeneratedReport({
    required this.id,
    required this.reportTypeId,
    required this.parameters,
  });

  final int id;

  /// The `ReportTypes` row; read it through [reportType].
  final int reportTypeId;

  /// The request that produced it, as JSON.
  final String parameters;

  @JsonKey(includeFromJson: false, includeToJson: false)
  ReportType get reportType => ReportType.fromValue(reportTypeId);

  factory GeneratedReport.fromJson(Map<String, dynamic> json) =>
      _$GeneratedReportFromJson(json);

  Map<String, dynamic> toJson() => _$GeneratedReportToJson(this);
}
