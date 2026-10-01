// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generated_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GeneratedReport _$GeneratedReportFromJson(Map<String, dynamic> json) =>
    GeneratedReport(
      id: (json['id'] as num).toInt(),
      reportTypeId: (json['reportTypeId'] as num).toInt(),
      parameters: json['parameters'] as String,
      status: json['status'] as String,
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$GeneratedReportToJson(GeneratedReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reportTypeId': instance.reportTypeId,
      'parameters': instance.parameters,
      'status': instance.status,
      'errorMessage': instance.errorMessage,
    };
