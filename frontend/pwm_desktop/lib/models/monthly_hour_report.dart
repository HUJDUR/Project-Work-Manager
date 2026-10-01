import 'package:json_annotation/json_annotation.dart';

part 'monthly_hour_report.g.dart';

/// One month of booked work, summed by the server as the hours come in.
@JsonSerializable()
class MonthlyHourReport {
  const MonthlyHourReport({
    required this.id,
    required this.year,
    required this.month,
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.workerCount,
  });

  final int id;
  final int year;
  final int month;
  /// Fractional: a shift is rarely a whole number of hours.
  final double totalHours;
  final double regularHours;
  final double overtimeHours;
  final int workerCount;

  factory MonthlyHourReport.fromJson(Map<String, dynamic> json) =>
      _$MonthlyHourReportFromJson(json);

  Map<String, dynamic> toJson() => _$MonthlyHourReportToJson(this);
}
