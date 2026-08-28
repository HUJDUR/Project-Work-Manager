import 'package:json_annotation/json_annotation.dart';

part 'monthly_hour_report_detail.g.dart';

@JsonSerializable()
class MonthlyHourReportDetail {
  const MonthlyHourReportDetail({
    required this.id,
    required this.monthlyHourReportId,
    required this.userId,
    required this.totalHours,
  });

  final int id;
  final int monthlyHourReportId;
  final int userId;
  final int totalHours;

  factory MonthlyHourReportDetail.fromJson(Map<String, dynamic> json) =>
      _$MonthlyHourReportDetailFromJson(json);

  Map<String, dynamic> toJson() => _$MonthlyHourReportDetailToJson(this);
}
