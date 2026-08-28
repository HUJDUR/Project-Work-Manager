import 'package:json_annotation/json_annotation.dart';

part 'activity_log.g.dart';

@JsonSerializable()
class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.userId,
    required this.activityLogTypeId,
    required this.date,
  });

  final int id;
  final int userId;
  final int activityLogTypeId;
  final DateTime date;

  factory ActivityLog.fromJson(Map<String, dynamic> json) => _$ActivityLogFromJson(json);

  Map<String, dynamic> toJson() => _$ActivityLogToJson(this);
}
