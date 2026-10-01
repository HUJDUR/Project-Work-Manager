// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProjectCategory _$ProjectCategoryFromJson(Map<String, dynamic> json) =>
    ProjectCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$ProjectCategoryToJson(ProjectCategory instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};
