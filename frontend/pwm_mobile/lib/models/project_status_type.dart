import 'package:json_annotation/json_annotation.dart';

part 'project_status_type.g.dart';

@JsonSerializable()
class ProjectStatusType {
  const ProjectStatusType({required this.id, required this.name});

  final int id;
  final String name;

  factory ProjectStatusType.fromJson(Map<String, dynamic> json) =>
      _$ProjectStatusTypeFromJson(json);

  Map<String, dynamic> toJson() => _$ProjectStatusTypeToJson(this);
}
