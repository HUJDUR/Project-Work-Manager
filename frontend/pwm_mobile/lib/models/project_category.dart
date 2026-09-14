import 'package:json_annotation/json_annotation.dart';

part 'project_category.g.dart';

@JsonSerializable()
class ProjectCategory {
  const ProjectCategory({required this.id, required this.name});

  final int id;
  final String name;

  factory ProjectCategory.fromJson(Map<String, dynamic> json) =>
      _$ProjectCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$ProjectCategoryToJson(this);
}
