import 'package:json_annotation/json_annotation.dart';

part 'work_log_detail.g.dart';

@JsonSerializable()
class WorkLogDetail {
  const WorkLogDetail({
    required this.id,
    required this.workLogId,
    required this.userId,
    required this.operationTypeId,
    required this.projectId,
    required this.startedAt,
    required this.hours,
    this.finishedAt,
  });

  final int id;
  final int workLogId;

  /// Whose block of work this is — always the owner of the shift it hangs off.
  final int userId;
  final int operationTypeId;
  final int projectId;
  final DateTime startedAt;
  final double hours;
  final DateTime? finishedAt;

  factory WorkLogDetail.fromJson(Map<String, dynamic> json) =>
      _$WorkLogDetailFromJson(json);

  Map<String, dynamic> toJson() => _$WorkLogDetailToJson(this);
}
