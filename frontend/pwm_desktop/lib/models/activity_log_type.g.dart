// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_log_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityLogType _$ActivityLogTypeFromJson(Map<String, dynamic> json) =>
    ActivityLogType(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$ActivityLogTypeToJson(ActivityLogType instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};
