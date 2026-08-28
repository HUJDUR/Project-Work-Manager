import 'package:json_annotation/json_annotation.dart';

part 'activity_log_type.g.dart';

@JsonSerializable()
class ActivityLogType {
  const ActivityLogType({required this.id, required this.name});

  final int id;
  final String name;

  factory ActivityLogType.fromJson(Map<String, dynamic> json) =>
      _$ActivityLogTypeFromJson(json);

  Map<String, dynamic> toJson() => _$ActivityLogTypeToJson(this);
}
