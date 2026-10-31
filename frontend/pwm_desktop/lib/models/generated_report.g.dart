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
      generatedByName: json['generatedByName'] as String?,
      generatedAt: _$JsonConverterFromJson<String, DateTime>(
        json['generatedAt'],
        const ApiDateTimeConverter().fromJson,
      ),
    );

Map<String, dynamic> _$GeneratedReportToJson(GeneratedReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'reportTypeId': instance.reportTypeId,
      'parameters': instance.parameters,
      'status': instance.status,
      'errorMessage': instance.errorMessage,
      'generatedByName': instance.generatedByName,
      'generatedAt': _$JsonConverterToJson<String, DateTime>(
        instance.generatedAt,
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
