import 'package:json_annotation/json_annotation.dart';
import '../utils/sarajevo_time.dart';

part 'activity_log.g.dart';

@JsonSerializable(converters: [ApiDateTimeConverter()])
class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.userId,
    required this.activityLogTypeId,
    required this.date,
    this.generatedReportId,
  });

  final int id;
  final int userId;
  final int activityLogTypeId;
  final DateTime date;

  /// Set only on a "Generated report" entry — this table is what records who
  /// ran a report and when.
  final int? generatedReportId;

  factory ActivityLog.fromJson(Map<String, dynamic> json) => _$ActivityLogFromJson(json);

  Map<String, dynamic> toJson() => _$ActivityLogToJson(this);
}
