// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecommendationResult _$RecommendationResultFromJson(
  Map<String, dynamic> json,
) => RecommendationResult(
  hasEstimate: json['hasEstimate'] as bool,
  message: json['message'] as String?,
  explanation: json['explanation'] as String?,
  sampleSize: (json['sampleSize'] as num).toInt(),
  accuracyPercent: (json['accuracyPercent'] as num).toDouble(),
  totalHours: (json['totalHours'] as num).toDouble(),
  estimatedWorkers: (json['estimatedWorkers'] as num).toInt(),
  estimatedDurationDays: (json['estimatedDurationDays'] as num).toInt(),
  workTypes: (json['workTypes'] as List<dynamic>)
      .map((e) => RecommendationWorkType.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$RecommendationResultToJson(
  RecommendationResult instance,
) => <String, dynamic>{
  'hasEstimate': instance.hasEstimate,
  'message': instance.message,
  'explanation': instance.explanation,
  'sampleSize': instance.sampleSize,
  'accuracyPercent': instance.accuracyPercent,
  'totalHours': instance.totalHours,
  'estimatedWorkers': instance.estimatedWorkers,
  'estimatedDurationDays': instance.estimatedDurationDays,
  'workTypes': instance.workTypes,
};
