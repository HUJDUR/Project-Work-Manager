// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkLog _$WorkLogFromJson(Map<String, dynamic> json) => WorkLog(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  clockedIn: const ApiDateTimeConverter().fromJson(json['clockedIn'] as String),
  hours: (json['hours'] as num).toDouble(),
  clockedOut: _$JsonConverterFromJson<String, DateTime>(
    json['clockedOut'],
    const ApiDateTimeConverter().fromJson,
  ),
);

Map<String, dynamic> _$WorkLogToJson(WorkLog instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'clockedIn': const ApiDateTimeConverter().toJson(instance.clockedIn),
  'hours': instance.hours,
  'clockedOut': _$JsonConverterToJson<String, DateTime>(
    instance.clockedOut,
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
