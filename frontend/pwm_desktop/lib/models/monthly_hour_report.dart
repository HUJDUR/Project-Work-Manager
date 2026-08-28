import 'package:json_annotation/json_annotation.dart';

part 'monthly_hour_report.g.dart';

@JsonSerializable()
class MonthlyHourReport {
  const MonthlyHourReport({
    required this.id,
    required this.year,
    required this.month,
    required this.totalHours,
  });

  final int id;
  final int year;
  final int month;
  final int totalHours;

  factory MonthlyHourReport.fromJson(Map<String, dynamic> json) =>
      _$MonthlyHourReportFromJson(json);

  Map<String, dynamic> toJson() => _$MonthlyHourReportToJson(this);
}
