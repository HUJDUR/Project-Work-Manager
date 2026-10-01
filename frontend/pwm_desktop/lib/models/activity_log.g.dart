// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityLog _$ActivityLogFromJson(Map<String, dynamic> json) => ActivityLog(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  activityLogTypeId: (json['activityLogTypeId'] as num).toInt(),
  date: const ApiDateTimeConverter().fromJson(json['date'] as String),
  generatedReportId: (json['generatedReportId'] as num?)?.toInt(),
);

Map<String, dynamic> _$ActivityLogToJson(ActivityLog instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'activityLogTypeId': instance.activityLogTypeId,
      'date': const ApiDateTimeConverter().toJson(instance.date),
      'generatedReportId': instance.generatedReportId,
    };
