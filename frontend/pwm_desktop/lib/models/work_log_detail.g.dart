// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_log_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkLogDetail _$WorkLogDetailFromJson(Map<String, dynamic> json) =>
    WorkLogDetail(
      id: (json['id'] as num).toInt(),
      workLogId: (json['workLogId'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      operationTypeId: (json['operationTypeId'] as num).toInt(),
      projectId: (json['projectId'] as num).toInt(),
      startedAt: const ApiDateTimeConverter().fromJson(
        json['startedAt'] as String,
      ),
      hours: (json['hours'] as num).toDouble(),
      finishedAt: _$JsonConverterFromJson<String, DateTime>(
        json['finishedAt'],
        const ApiDateTimeConverter().fromJson,
      ),
    );

Map<String, dynamic> _$WorkLogDetailToJson(WorkLogDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workLogId': instance.workLogId,
      'userId': instance.userId,
      'operationTypeId': instance.operationTypeId,
      'projectId': instance.projectId,
      'startedAt': const ApiDateTimeConverter().toJson(instance.startedAt),
      'hours': instance.hours,
      'finishedAt': _$JsonConverterToJson<String, DateTime>(
        instance.finishedAt,
        const ApiDateTimeConverter().toJson,
      ),
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
