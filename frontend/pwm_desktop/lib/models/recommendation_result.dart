import 'package:json_annotation/json_annotation.dart';

import 'recommendation_work_type.dart';

part 'recommendation_result.g.dart';

/// Mirrors `pwm.Model.Responses.RecommendationResponse` - the answer from
/// `POST /Recommendation/Estimate`.
@JsonSerializable()
class RecommendationResult {
  const RecommendationResult({
    required this.hasEstimate,
    this.message,
    required this.sampleSize,
    required this.accuracyPercent,
    required this.totalHours,
    required this.estimatedWorkers,
    required this.estimatedDurationDays,
    required this.workTypes,
  });

  /// False when the category has too little delivered history - see [message]
  /// for why. No other field is meaningful when this is false.
  final bool hasEstimate;

  final String? message;

  final int sampleSize;
  final double accuracyPercent;
  final double totalHours;
  final int estimatedWorkers;
  final int estimatedDurationDays;
  final List<RecommendationWorkType> workTypes;

  factory RecommendationResult.fromJson(Map<String, dynamic> json) =>
      _$RecommendationResultFromJson(json);

  Map<String, dynamic> toJson() => _$RecommendationResultToJson(this);
}
