// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation_work_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecommendationWorkType _$RecommendationWorkTypeFromJson(
  Map<String, dynamic> json,
) => RecommendationWorkType(
  operationTypeId: (json['operationTypeId'] as num).toInt(),
  operationTypeName: json['operationTypeName'] as String,
  estimatedHours: (json['estimatedHours'] as num).toDouble(),
  sharePercent: (json['sharePercent'] as num).toDouble(),
);

Map<String, dynamic> _$RecommendationWorkTypeToJson(
  RecommendationWorkType instance,
) => <String, dynamic>{
  'operationTypeId': instance.operationTypeId,
  'operationTypeName': instance.operationTypeName,
  'estimatedHours': instance.estimatedHours,
  'sharePercent': instance.sharePercent,
};
