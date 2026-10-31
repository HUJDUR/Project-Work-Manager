import 'package:json_annotation/json_annotation.dart';
import '../utils/sarajevo_time.dart';

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

/// Mirrors `pwm.Model.Enums.ReportStatus` - a row's place in the queue-and-build
/// pipeline `ReportService`/`pwm.Worker` push it through. Unknown values fall
/// back to `completed` rather than throwing, since that is the reading that
/// asks nothing further of a row this client does not yet recognise.
enum ReportRunStatus {
  pending,
  processing,
  completed,
  failed;

  static ReportRunStatus fromName(String? value) => ReportRunStatus.values.firstWhere(
        (status) => status.name.toLowerCase() == (value ?? '').toLowerCase(),
        orElse: () => completed,
      );
}

/// One run of a report. `pwm.Worker` - a separate process, off RabbitMQ - is
/// what actually renders the PDF and stores it; this row is what the API hands
/// back meanwhile, and what the Recent Reports list reads for its status badge.
@JsonSerializable(converters: [ApiDateTimeConverter()])
class GeneratedReport {
  const GeneratedReport({
    required this.id,
    required this.reportTypeId,
    required this.parameters,
    required this.status,
    this.errorMessage,
    this.generatedByName,
    this.generatedAt,
  });

  final int id;

  /// The `ReportTypes` row; read it through [reportType].
  final int reportTypeId;

  /// The request that produced it, as JSON.
  final String parameters;

  final String status;

  /// Set only when [status] is "Failed".
  final String? errorMessage;

  /// Who ran it and when - null for a run the API has no record of.
  final String? generatedByName;
  final DateTime? generatedAt;

  @JsonKey(includeFromJson: false, includeToJson: false)
  ReportType get reportType => ReportType.fromValue(reportTypeId);

  @JsonKey(includeFromJson: false, includeToJson: false)
  ReportRunStatus get runStatus => ReportRunStatus.fromName(status);

  factory GeneratedReport.fromJson(Map<String, dynamic> json) =>
      _$GeneratedReportFromJson(json);

  Map<String, dynamic> toJson() => _$GeneratedReportToJson(this);
}
