import 'package:json_annotation/json_annotation.dart';

part 'monthly_hour_report_detail.g.dart';

@JsonSerializable()
class MonthlyHourReportDetail {
  const MonthlyHourReportDetail({
    required this.id,
    required this.monthlyHourReportId,
    required this.userId,
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
  });

  final int id;
  final int monthlyHourReportId;
  final int userId;
  /// Fractional: a shift is rarely a whole number of hours.
  final double totalHours;

  /// The first eight hours of each of this worker's days in the month.
  final double regularHours;

  /// Everything past eight hours on a day.
  final double overtimeHours;

  factory MonthlyHourReportDetail.fromJson(Map<String, dynamic> json) =>
      _$MonthlyHourReportDetailFromJson(json);

  Map<String, dynamic> toJson() => _$MonthlyHourReportDetailToJson(this);
}
