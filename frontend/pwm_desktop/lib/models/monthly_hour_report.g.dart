// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_hour_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MonthlyHourReport _$MonthlyHourReportFromJson(Map<String, dynamic> json) =>
    MonthlyHourReport(
      id: (json['id'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      month: (json['month'] as num).toInt(),
      totalHours: (json['totalHours'] as num).toDouble(),
      regularHours: (json['regularHours'] as num).toDouble(),
      overtimeHours: (json['overtimeHours'] as num).toDouble(),
      workerCount: (json['workerCount'] as num).toInt(),
    );

Map<String, dynamic> _$MonthlyHourReportToJson(MonthlyHourReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'year': instance.year,
      'month': instance.month,
      'totalHours': instance.totalHours,
      'regularHours': instance.regularHours,
      'overtimeHours': instance.overtimeHours,
      'workerCount': instance.workerCount,
    };
