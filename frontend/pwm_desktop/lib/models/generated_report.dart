import 'package:json_annotation/json_annotation.dart';

part 'generated_report.g.dart';

/// A report that was produced once. The PDF itself is not stored — downloading
/// it again re-runs [parameters], so it can never disagree with the work logs.
enum ReportType {
  monthlyWorkHours(1, 'Monthly Work Hours'),
  transportLoads(2, 'Transport & Loads');

  const ReportType(this.value, this.label);

  final int value;
  final String label;

  static ReportType fromValue(int? value) => ReportType.values
      .firstWhere((type) => type.value == value, orElse: () => monthlyWorkHours);
}

@JsonSerializable()
class GeneratedReport {
  const GeneratedReport({
    required this.id,
    required this.type,
    required this.parameters,
    required this.generatedAt,
    required this.generatedById,
  });

  final int id;

  /// The stored int; read it through [reportType].
  final int type;

  /// The request that produced it, as JSON.
  final String parameters;

  final DateTime generatedAt;
  final int generatedById;

  @JsonKey(includeFromJson: false, includeToJson: false)
  ReportType get reportType => ReportType.fromValue(type);

  factory GeneratedReport.fromJson(Map<String, dynamic> json) =>
      _$GeneratedReportFromJson(json);

  Map<String, dynamic> toJson() => _$GeneratedReportToJson(this);
}
